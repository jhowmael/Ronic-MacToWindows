import CoreGraphics
import Foundation

/// Actions that don't belong inside the callback (UI, launching apps, locking the screen).
/// The callback only enqueues them on the main queue and returns immediately.
enum EngineAction {
    case switcherShow(reverse: Bool)
    case switcherStep(Int)
    case switcherCommit
    case switcherCancel
    case lockScreen
    case showDesktop
    case screenshot
    case screenshotToClipboard(fullScreen: Bool)
    case taskManager
}

/// Real-time keyboard interception through a `CGEventTap`.
///
/// * The tap runs on its own thread (QoS userInteractive) with its own CFRunLoop:
///   if the main thread is busy drawing the menu or the app switcher, typing is never delayed.
/// * The callback rewrites the event itself (keyCode + flags) and returns it. No new events,
///   no I/O, no logging, no UI work.
/// * The tap sits at the HID level (`.cghidEventTap`), ahead of the system-wide shortcuts.
///   That is how Ctrl+← becomes ⌥← before macOS reads it as "switch Space".
final class RemapEngine: @unchecked Sendable {
    /// Tags the events we post ourselves so the tap doesn't process them again.
    static let syntheticMarker: Int64 = 0x524F_4E49_4321 // "RONIC!"

    private let dispatch: (EngineAction) -> Void
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?

    // ---- State touched ONLY by the tap thread ----

    private struct Remap {
        let keyCode: UInt16
        let flags: CGEventFlags
        let char: UniChar?
    }

    /// Rewritten keyDown → the keyUp of the same physical key gets the same rewrite,
    /// even if the modifier was already released (prevents "stuck" keys in the app).
    private var remapped = [Remap?](repeating: nil, count: 256)
    /// Swallowed keyDown → swallow the matching keyUp too.
    private var swallowed = [Bool](repeating: false, count: 256)
    /// Alt+Tab in progress (Option still held).
    private var switcherActive = false
    /// Fixed table Ctrl+<key> → ⌘+<key>.
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

    // MARK: - Lifecycle (main thread)

    /// Creates the tap. Returns `false` while the app doesn't have Accessibility permission yet.
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

    /// Pausing = disabling the tap: the system stops sending events to the app (zero cost).
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

    // MARK: - Callback (tap thread)

    @inline(__always)
    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            return handleKeyDown(event)
        case .keyUp:
            return handleKeyUp(event)
        case .flagsChanged:
            // Releasing Option ends Alt+Tab, like on Windows.
            if switcherActive, event.flags.rawValue & Mask.option == 0 {
                switcherActive = false
                send(.switcherCommit)
            }
            return Unmanaged.passUnretained(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS disables the tap if it takes too long; turn it back on right away.
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

        let state = SharedState.shared.snapshot
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode) & 0xFF)
        let key = UInt16(code)
        let raw = event.flags.rawValue
        let ctrl = raw & Mask.control != 0
        let shift = raw & Mask.shift != 0
        let opt = raw & Mask.option != 0
        let cmd = raw & Mask.command != 0

        remapped[code] = nil
        swallowed[code] = false

        // ---- Alt+Tab in progress: the switcher consumes the keys ----
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
            // Option was released and we missed the flagsChanged: commit and carry on normally.
            switcherActive = false
            send(.switcherCommit)
        }

        guard state.enabled else { return pass }

        // ---- Windows & system (apply in every app) ----
        if state.groups.contains(.windows) {
            if opt && !cmd && !ctrl {
                if key == Key.tab {
                    switcherActive = true
                    swallowed[code] = true
                    send(.switcherShow(reverse: shift))
                    return nil
                }
                if key == Key.f4 && !shift {
                    // Alt+F4 → ⌘Q (quits the active app, which still asks "save changes?")
                    return rewrite(event, code, to: Key.q, mods: Mask.outCommand, fnPad: .clear, char: KeyChar.q)
                }
            }
            if key == Key.f13 && !cmd && !ctrl && !opt && !state.groups.contains(.screenshots) {
                // Screenshots → clipboard is off: PrtSc opens the capture toolbar (⇧⌘5).
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

        // ---- Screenshots straight to the clipboard (every app) ----
        // Uses the native macOS shortcuts ⌃⇧⌘3 / ⌃⇧⌘4 ("copy to clipboard"):
        // no extra Screen Recording permission is needed.
        if state.groups.contains(.screenshots) && !ctrl && !opt {
            if key == Key.f13 && !cmd {
                // PrtSc → area snip, like Win+Shift+S / the Windows 11 Snipping Tool
                swallowed[code] = true
                send(.screenshotToClipboard(fullScreen: shift))   // Shift+PrtSc = full screen
                return nil
            }
            if cmd && shift {
                switch key {
                case Key.s, Key.four:   // Win+Shift+S  and native ⇧⌘4
                    swallowed[code] = true
                    send(.screenshotToClipboard(fullScreen: false))
                    return nil
                case Key.three:         // native ⇧⌘3
                    swallowed[code] = true
                    send(.screenshotToClipboard(fullScreen: true))
                    return nil
                default:
                    break
                }
            }
        }

        // ---- Win key (= ⌘) ----
        if state.groups.contains(.winKey) && cmd && !ctrl && !opt && !shift {
            if key == Key.l { swallowed[code] = true; send(.lockScreen); return nil }
            if key == Key.d { swallowed[code] = true; send(.showDesktop); return nil }
        }

        // Terminals, VMs etc.: the original Control key is left untouched.
        if state.frontmostExcluded { return pass }

        // ---- Text navigation ----
        if state.groups.contains(.textNavigation) && !cmd && !opt {
            switch key {
            case Key.home:
                return ctrl
                    ? rewrite(event, code, to: Key.up, mods: Mask.outCommand, fnPad: .set, char: KeyChar.upArrow)
                    // ^A = moveToBeginningOfParagraph (Shift is kept → selects).
                    // Unlike ⌘←, it doesn't turn into browser "Back" outside text fields.
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

        // ---- Editing: Ctrl → ⌘ ----
        if state.groups.contains(.editing) && ctrl && !cmd && !opt {
            if key == Key.v && shift {
                // Ctrl+Shift+V → ⌥⇧⌘V (paste without formatting)
                return rewrite(event, code, to: key, mods: Mask.outCommand | Mask.outOption, fnPad: .keep)
            }
            if key == Key.y {
                // Ctrl+Y → ⇧⌘Z (redo)
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

    // MARK: - Rewriting

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

/// C function required by `CGEvent.tapCreate`. `refcon` is the engine itself (unretained:
/// it lives as long as the app does).
private func ronicEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<RemapEngine>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
}
