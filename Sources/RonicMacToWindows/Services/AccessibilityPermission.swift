import AppKit
import ApplicationServices

/// Accessibility permission (required for a CGEventTap that modifies events).
enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system alert that leads to Settings (only appears while not yet authorized).
    static func requestPrompt() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Removes the app's entry in Settings › Accessibility (`tccutil reset`, no admin needed).
    /// Needed after updating: the old toggle shows as on, but macOS tied it to the previous
    /// binary's signature and doesn't apply it to the new one.
    @discardableResult
    static func resetEntry() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", id]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// The system posts this notification when the list of authorized apps changes.
    /// It arrives slightly before the change takes effect, so the handler runs with a delay.
    static func observeChanges(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: handler)
        }
    }
}
