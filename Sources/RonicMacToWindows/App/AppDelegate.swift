import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Só uma instância: duas teriam dois event taps disputando as mesmas teclas.
        if let id = Bundle.main.bundleIdentifier {
            let me = NSRunningApplication.current
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { $0 != me }
            if !others.isEmpty {
                NSApp.terminate(nil)
                return
            }
        }

        // Intencionalmente NÃO há SMAppService / Login Items: o app só roda quando aberto à mão.
        let controller = AppController()
        self.controller = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }
}
