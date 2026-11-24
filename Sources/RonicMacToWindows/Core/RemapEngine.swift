import CoreGraphics
import Foundation

/// Ações que não cabem dentro do callback (UI, abrir apps, bloquear tela).
/// O callback só as enfileira na main queue e volta imediatamente.
enum EngineAction {
    case switcherShow(reverse: Bool)
    case switcherStep(Int)
    case switcherCommit
    case switcherCancel
    case lockScreen
    case showDesktop
    case screenshot
    case taskManager
}

/// Interceptação de teclado em tempo real via `CGEventTap`.
///
/// * O tap roda numa thread própria (QoS userInteractive) com seu próprio CFRunLoop:
///   se a thread principal estiver ocupada desenhando o menu ou o seletor de apps,
///   a digitação não sofre atraso.
/// * O callback reescreve o próprio evento (keyCode + flags) e o devolve. Sem criar eventos,
///   sem I/O, sem logs, sem tocar em UI.
/// * O tap fica no nível HID (`.cghidEventTap`), antes dos atalhos globais do sistema.
///   Assim Ctrl+← vira ⌥← antes de o macOS interpretá-lo como "mudar de Space".
final class RemapEngine: @unchecked Sendable {
    /// Marca os eventos que nós mesmos postamos, para o tap não reprocessá-los.
    static let syntheticMarker: Int64 = 0x524F_4E49_4321 // "RONIC!"

    private let dispatch: (EngineAction) -> Void
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?

    // ---- Estado acessado SOMENTE pela thread do tap ----

    private struct Remap {
        let keyCode: UInt16
        let flags: CGEventFlags
        let char: UniChar?
    }

    /// keyDown reescrito → o keyUp da mesma tecla física recebe a mesma reescrita,
    /// mesmo que o modificador já tenha sido solto (evita tecla "presa" no app).
    private var remapped = [Remap?](repeating: nil, count: 256)
    /// keyDown engolido → engole o keyUp correspondente.
    private var swallowed = [Bool](repeating: false, count: 256)
    /// Alt+Tab em andamento (Option ainda pressionado).
    private var switcherActive = false
    /// Tabela fixa Ctrl+<tecla> → ⌘+<tecla>.
    private let ctrlToCommand: [Bool] = {
        var t = [Bool](repeating: false, count: 256)
        for k in [Key.c, Key.v, Key.x, Key.z, Key.a, Key.s, Key.f, Key.n, Key.t, Key.w, Key.p, Key.l,
                  Key.o, Key.r, Key.b, Key.i, Key.u, Key.k, Key.equal, Key.minus, Key.zero] {
            t[Int(k)] = true
        }
        return t
    }()

    init(dispatch: @escaping (EngineAction) -> Void) {
        self.dispatch = dispatch
    }

    var isRunning: Bool { tap != nil }

    // MARK: - Ciclo de vida (thread principal)

    /// Cria o tap. Retorna `false` se o app ainda não tem permissão de Acessibilidade.
    func start() -> Bool {
        if tap != nil { return true }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: ronicEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0) else {
            CFMachPortInvalidate(port)
            return false
        }

        tap = port
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [unowned self] in
            let rl = CFRunLoopGetCurrent()
            self.runLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "RonicMacToWindows.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        self.thread = thread
        return true
    }

    /// Pausar = desligar o tap: o sistema deixa de enviar eventos para o app (custo zero).
    func setActive(_ active: Bool) {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: active)
    }

    func stop() {
        guard let port = tap else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        CFMachPortInvalidate(port)
        if let runLoop { CFRunLoopStop(runLoop) }
        tap = nil
        runLoop = nil
        thread = nil
    }

    // MARK: - Callback (thread do tap)

    @inline(__always)
    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        case .flagsChanged:
            // Soltar o Option encerra o Alt+Tab, como no Windows.
            if switcherActive, event.flags.rawValue & Mask.option == 0 {
                switcherActive = false
                send(.switcherCommit)
            }
            return Unmanaged.passUnretained(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // O macOS desliga o tap se ele demorar demais; religamos na hora.
            if switcherActive {
                switcherActive = false
                send(.switcherCancel)
            }
            if let tap, SharedState.shared.snapshot.enabled {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    @inline(__always)
    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker { return pass }

        let code = Int(event.getIntegerValueField(.keyboardEventKeycode) & 0xFF)
        let key = UInt16(code)
        let raw = event.flags.rawValue
        let ctrl = raw & Mask.control != 0
        let shift = raw & Mask.shift != 0
        let opt = raw & Mask.option != 0
        let cmd = raw & Mask.command != 0

        remapped[code] = nil
        swallowed[code] = false

        // ---- Alt+Tab em andamento: o seletor consome as teclas ----
        if switcherActive {
            if opt {
                swallowed[code] = true
                switch key {
                case Key.tab: send(.switcherStep(shift ? -1 : 1))
                case Key.left, Key.up: send(.switcherStep(-1))
                case Key.right, Key.down: send(.switcherStep(1))
                case Key.escape: switcherActive = false; send(.switcherCancel)
                case Key.returnKey: switcherActive = false; send(.switcherCommit)
                default: break
                }
                return nil
            }
            // Option já foi solto e perdemos o flagsChanged: confirma e segue normalmente.
            switcherActive = false
            send(.switcherCommit)
        }

        let state = SharedState.shared.snapshot
        guard state.enabled else { return pass }

        // ---- Janelas e sistema (valem em todos os apps) ----
        if state.groups.contains(.windows) {
            if opt && !cmd && !ctrl {
                if key == Key.tab {
                    switcherActive = true
                    swallowed[code] = true
                    send(.switcherShow(reverse: shift))
                    return nil
                }
                if key == Key.f4 && !shift {
                    // Alt+F4 → ⌘Q (encerra o app ativo respeitando "salvar alterações?")
                    return rewrite(event, code, to: Key.q, mods: Mask.outCommand, fnPad: .clear, char: KeyChar.q)
                }
            }
            if key == Key.f13 && !cmd && !ctrl && !opt {
                swallowed[code] = true
                send(.screenshot)
                return nil
            }
            if key == Key.escape && ctrl && shift && !cmd && !opt {
                swallowed[code] = true
                send(.taskManager)
                return nil
            }
        }

        // ---- Tecla Win (= ⌘) ----
        if state.groups.contains(.winKey) && cmd && !ctrl && !opt && !shift {
            if key == Key.l { swallowed[code] = true; send(.lockScreen); return nil }
            if key == Key.d { swallowed[code] = true; send(.showDesktop); return nil }
        }

        // Terminais, VMs etc.: o Control original segue intacto.
        if state.frontmostExcluded { return pass }

        // ---- Navegação de texto ----
        if state.groups.contains(.textNavigation) && !cmd && !opt {
            switch key {
            case Key.home:
                return ctrl
                    ? rewrite(event, code, to: Key.up, mods: Mask.outCommand, fnPad: .set, char: KeyChar.upArrow)
                    // ^A = moveToBeginningOfParagraph (Shift preservado → seleciona).
                    // Diferente de ⌘←, não vira "Voltar" no navegador fora de campos de texto.
                    : rewrite(event, code, to: Key.a, mods: Mask.outControl, fnPad: .clear, char: KeyChar.ctrlA)
            case Key.end:
                return ctrl
                    ? rewrite(event, code, to: Key.down, mods: Mask.outCommand, fnPad: .set, char: KeyChar.downArrow)
                    : rewrite(event, code, to: Key.e, mods: Mask.outControl, fnPad: .clear, char: KeyChar.ctrlE)
            case Key.left, Key.right, Key.backspace, Key.forwardDelete:
                if ctrl { return rewrite(event, code, to: key, mods: Mask.outOption, fnPad: .keep) }
            default:
                break
            }
        }

        // ---- Edição: Ctrl → ⌘ ----
        if state.groups.contains(.editing) && ctrl && !cmd && !opt {
            if key == Key.v && shift {
                // Ctrl+Shift+V → ⌥⇧⌘V (colar sem formatação)
                return rewrite(event, code, to: key, mods: Mask.outCommand | Mask.outOption, fnPad: .keep)
            }
            if key == Key.y {
                // Ctrl+Y → ⇧⌘Z (refazer)
                return rewrite(event, code, to: Key.z, mods: Mask.outCommand, addShift: true, fnPad: .keep, char: KeyChar.z)
            }
            if ctrlToCommand[code] {
                return rewrite(event, code, to: key, mods: Mask.outCommand, fnPad: .keep)
            }
        }

        return pass
    }

    @inline(__always)
    private func handleKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode) & 0xFF)
        if swallowed[code] {
            swallowed[code] = false
            return nil
        }
        if let r = remapped[code] {
            remapped[code] = nil
            apply(r, to: event, originalCode: code)
        }
        return Unmanaged.passUnretained(event)
    }

    // MARK: - Reescrita

    private enum FnPad { case keep, set, clear }

    @inline(__always)
    private func rewrite(_ event: CGEvent, _ code: Int, to newCode: UInt16, mods: UInt64,
                         addShift: Bool = false, fnPad: FnPad, char: UniChar? = nil) -> Unmanaged<CGEvent> {
        var raw = event.flags.rawValue & ~(Mask.anyControl | Mask.anyCommand | Mask.anyOption)
        switch fnPad {
        case .keep: break
        case .set: raw |= Mask.fnPad
        case .clear: raw &= ~Mask.fnPad
        }
        raw |= mods
        if addShift { raw |= Mask.outShift }

        let r = Remap(keyCode: newCode, flags: CGEventFlags(rawValue: raw), char: char)
        remapped[code] = r
        apply(r, to: event, originalCode: code)
        return Unmanaged.passUnretained(event)
    }

    @inline(__always)
    private func apply(_ r: Remap, to event: CGEvent, originalCode: Int) {
        if Int(r.keyCode) != originalCode {
            event.setIntegerValueField(.keyboardEventKeycode, value: Int64(r.keyCode))
        }
        event.flags = r.flags
        if var c = r.char {
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c)
        }
    }

    @inline(__always)
    private func send(_ action: EngineAction) {
        let dispatch = self.dispatch
        DispatchQueue.main.async { dispatch(action) }
    }
}

/// Função C exigida pelo `CGEvent.tapCreate`. `refcon` é o próprio engine (não retido:
/// ele vive enquanto o app vive).
private func ronicEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<RemapEngine>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
}
