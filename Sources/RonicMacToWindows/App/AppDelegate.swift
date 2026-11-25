import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single instance: two would mean two event taps fighting over the same keys.
        if let id = Bundle.main.bundleIdentifier {
            let me = NSRunningApplication.current
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { $0 != me }
            if !others.isEmpty {
                NSApp.terminate(nil)
                return
            }
        }

        // Intentionally NO SMAppService / Login Items: the app only runs when opened by hand.
        let controller = AppController()
        self.controller = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }
}
