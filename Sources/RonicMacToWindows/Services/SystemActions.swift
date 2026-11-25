import AppKit
import Darwin

/// System actions triggered by shortcuts (always on the main thread, outside the callback).
enum SystemActions {
    // Private APIs loaded on demand, with a public fallback in case they disappear.
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
            // Native macOS lock shortcut: ⌃⌘Q
            postShortcut(Key.q, flags: [.maskControl, .maskCommand])
        }
    }

    /// Win+D — toggles "Show Desktop" (same as the Mission Control gesture/F11).
    static func showDesktop() {
        if let send = coreDockSend {
            send("com.apple.showdesktop.awake" as CFString, nil)
        } else {
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                app.hide()
            }
        }
    }

    /// Print Screen (F13) — opens the Screenshot toolbar, like ⇧⌘5.
    static func openScreenshotTool() {
        if !openApp(at: "/System/Applications/Utilities/Screenshot.app") {
            postShortcut(Key.five, flags: [.maskCommand, .maskShift])
        }
    }

    /// Screenshot straight to the clipboard, like on Windows: fires the native shortcut
    /// ⌃⇧⌘3 (full screen) or ⌃⇧⌘4 (snip; Space switches to "window").
    /// macOS itself takes the capture, so the app never needs Screen Recording permission.
    static func screenshotToClipboard(fullScreen: Bool) {
        postShortcut(fullScreen ? Key.three : Key.four, flags: [.maskControl, .maskCommand, .maskShift])
    }

    /// Ctrl+Shift+Esc — Activity Monitor, the Mac's "Task Manager".
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

    /// Posts a shortcut tagged as synthetic so our own tap lets it through.
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
