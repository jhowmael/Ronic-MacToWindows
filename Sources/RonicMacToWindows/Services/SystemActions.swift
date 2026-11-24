import AppKit
import Darwin

/// Ações de sistema disparadas pelos atalhos (sempre na thread principal, fora do callback).
enum SystemActions {
    // APIs privadas carregadas sob demanda, com plano B público caso desapareçam.
    private typealias CoreDockSendNotificationFn = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void
    private typealias LockScreenFn = @convention(c) () -> Int32

    private static let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

    private static let coreDockSend: CoreDockSendNotificationFn? = {
        guard let sym = dlsym(rtldDefault, "CoreDockSendNotification") else { return nil }
        return unsafeBitCast(sym, to: CoreDockSendNotificationFn.self)
    }()

    private static let lockScreenImmediate: LockScreenFn? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
              let sym = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(sym, to: LockScreenFn.self)
    }()

    /// Win+L
    static func lockScreen() {
        if let lock = lockScreenImmediate {
            _ = lock()
        } else {
            // Atalho nativo do macOS para bloquear: ⌃⌘Q
            postShortcut(Key.q, flags: [.maskControl, .maskCommand])
        }
    }

    /// Win+D — alterna "Mostrar Mesa" (mesmo efeito do gesto/F11 do Mission Control).
    static func showDesktop() {
        if let send = coreDockSend {
            send("com.apple.showdesktop.awake" as CFString, nil)
        } else {
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                app.hide()
            }
        }
    }

    /// Print Screen (F13) — abre a barra do Screenshot, como ⇧⌘5.
    static func openScreenshotTool() {
        if !openApp(at: "/System/Applications/Utilities/Screenshot.app") {
            postShortcut(Key.five, flags: [.maskCommand, .maskShift])
        }
    }

    /// Print direto para a área de transferência, como no Windows: dispara o atalho nativo
    /// ⌃⇧⌘3 (tela inteira) ou ⌃⇧⌘4 (recorte; Espaço alterna para "janela").
    /// A captura é feita pelo próprio macOS, sem pedir permissão de Gravação de Tela ao app.
    static func screenshotToClipboard(fullScreen: Bool) {
        postShortcut(fullScreen ? Key.three : Key.four, flags: [.maskControl, .maskCommand, .maskShift])
    }

    /// Ctrl+Shift+Esc — Monitor de Atividade, o "Gerenciador de Tarefas" do Mac.
    static func openTaskManager() {
        _ = openApp(at: "/System/Applications/Utilities/Activity Monitor.app")
    }

    @discardableResult
    private static func openApp(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config)
        return true
    }

    /// Posta um atalho marcado como sintético, para o nosso tap deixá-lo passar.
    static func postShortcut(_ key: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = RemapEngine.syntheticMarker
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
