import AppKit

/// Alt+Tab estilo Windows.
///
/// * Nada é carregado até o atalho ser acionado: a lista de apps e os ícones são montados
///   na hora e descartados ao soltar o Option.
/// * Um Alt+Tab rápido (aperta e solta) troca direto para o app anterior, sem nem desenhar
///   o painel. O painel só aparece se o Option ficar pressionado por mais de 120 ms.
@MainActor
final class AppSwitcher {
    private unowned let tracker: FrontmostAppTracker
    private var apps: [NSRunningApplication] = []
    private var index = 0
    private var panel: SwitcherPanel?
    private var pendingPresent: DispatchWorkItem?
    private(set) var isActive = false

    private static let presentDelay: TimeInterval = 0.12

    init(tracker: FrontmostAppTracker) {
        self.tracker = tracker
    }

    func begin(reverse: Bool) {
        teardown()
        apps = tracker.switchableApps()
        guard !apps.isEmpty else { return }
        isActive = true
        index = apps.count > 1 ? (reverse ? apps.count - 1 : 1) : 0

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.present() }
        }
        pendingPresent = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.presentDelay, execute: work)
    }

    func step(_ delta: Int) {
        guard isActive, !apps.isEmpty else { return }
        let n = apps.count
        index = ((index + delta) % n + n) % n
        if let panel {
            panel.select(index)
        } else {
            pendingPresent?.cancel()
            present()
        }
    }

    func commit() {
        guard isActive else { return }
        let target = apps.indices.contains(index) ? apps[index] : nil
        teardown()
        if let target { activate(target) }
    }

    func cancel() {
        teardown()
    }

    // MARK: - Privado

    private func present() {
        guard isActive, panel == nil, !apps.isEmpty else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let panel = SwitcherPanel(apps: apps, screen: screen)
        panel.select(index)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func teardown() {
        pendingPresent?.cancel()
        pendingPresent = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        apps = []
        isActive = false
    }

    private func activate(_ app: NSRunningApplication) {
        guard !app.isTerminated else { return }
        if app.isHidden { app.unhide() }
        app.activate(options: [.activateAllWindows])

        // Plano B: se o macOS recusar a ativação (ativação cooperativa do macOS 14+),
        // pede ao LaunchServices, como um clique no Dock (também restaura janelas minimizadas).
        let pid = app.processIdentifier
        let url = app.bundleURL
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier != pid, let url else { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }
}
