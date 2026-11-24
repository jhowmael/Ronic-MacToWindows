import AppKit

/// Liga as peças: preferências, app ativo, permissão, event tap, Alt+Tab e menu.
/// Tudo aqui roda na thread principal; o event tap só recebe um snapshot atualizado.
@MainActor
final class AppController {
    let settings = Settings()
    let tracker = FrontmostAppTracker()
    private lazy var switcher = AppSwitcher(tracker: tracker)
    private var engine: RemapEngine!
    private var statusMenu: StatusMenuController!
    private var permissionObserver: NSObjectProtocol?
    private var permissionTimer: Timer?

    var isEnabled: Bool { settings.isEnabled }
    var isEngineRunning: Bool { engine.isRunning }
    var isTrusted: Bool { AccessibilityPermission.isTrusted }

    func start() {
        engine = RemapEngine { [weak self] action in
            MainActor.assumeIsolated { self?.perform(action) }
        }
        statusMenu = StatusMenuController(controller: self)

        tracker.onChange = { [weak self] _ in self?.syncExclusion() }
        syncState()

        permissionObserver = AccessibilityPermission.observeChanges { [weak self] in
            MainActor.assumeIsolated { self?.refreshPermissionAndEngine() }
        }

        if !AccessibilityPermission.isTrusted {
            if settings.accessibilityGrantedBefore {
                // Já tivemos permissão e agora não temos: quase sempre é uma atualização do app.
                // A chave em Ajustes › Acessibilidade continua ligada, mas pertence ao binário
                // anterior, e ligar/desligar não resolve. Removemos a entrada órfã para o macOS
                // pedir de novo — o usuário só precisa ligar a chave.
                settings.accessibilityGrantedBefore = false
                AccessibilityPermission.resetEntry()
            }
            AccessibilityPermission.requestPrompt()
        }
        refreshPermissionAndEngine()
    }

    func shutdown() {
        switcher.cancel()
        engine.stop()
    }

    // MARK: - Permissão

    /// Cria o tap assim que a permissão existir. Enquanto não existir, confere a cada 2 s
    /// (timer leve que se desliga sozinho depois de autorizado).
    func refreshPermissionAndEngine() {
        if AccessibilityPermission.isTrusted, !engine.isRunning, engine.start() {
            engine.setActive(settings.isEnabled)
        }

        if engine.isRunning {
            settings.accessibilityGrantedBefore = true
            permissionTimer?.invalidate()
            permissionTimer = nil
        } else if permissionTimer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPermissionAndEngine() }
            }
            timer.tolerance = 1
            RunLoop.main.add(timer, forMode: .common)
            permissionTimer = timer
        }
        statusMenu.refreshIcon()
    }

    /// "Ativei e continua não autorizado": remove a entrada antiga, pede de novo e abre os Ajustes.
    func resetPermission() {
        AccessibilityPermission.resetEntry()
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSystemSettings()
        refreshPermissionAndEngine()
    }

    /// Reabre o app (último recurso quando o macOS só libera a captura num processo novo).
    func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Ações do menu

    func setEnabled(_ enabled: Bool) {
        settings.isEnabled = enabled
        if !enabled { switcher.cancel() }
        syncState()
        engine.setActive(enabled)
        statusMenu.refreshIcon()
    }

    func toggleGroup(_ group: ShortcutGroups) {
        settings.groups.formSymmetricDifference(group)
        syncState()
    }

    func addExclusion(_ bundleID: String) {
        settings.addExclusion(bundleID)
        syncExclusion()
    }

    func removeExclusion(_ bundleID: String) {
        settings.removeExclusion(bundleID)
        syncExclusion()
    }

    func resetExclusions() {
        settings.resetExclusions()
        syncExclusion()
    }

    // MARK: - Estado para o event tap

    private func syncState() {
        let enabled = settings.isEnabled
        let groups = settings.groups
        let excluded = settings.isExcluded(tracker.currentBundleID)
        SharedState.shared.update {
            $0.enabled = enabled
            $0.groups = groups
            $0.frontmostExcluded = excluded
        }
    }

    private func syncExclusion() {
        let excluded = settings.isExcluded(tracker.currentBundleID)
        SharedState.shared.update { $0.frontmostExcluded = excluded }
    }

    // MARK: - Ações vindas do teclado

    private func perform(_ action: EngineAction) {
        switch action {
        case .switcherShow(let reverse): switcher.begin(reverse: reverse)
        case .switcherStep(let delta): switcher.step(delta)
        case .switcherCommit: switcher.commit()
        case .switcherCancel: switcher.cancel()
        case .lockScreen: SystemActions.lockScreen()
        case .showDesktop: SystemActions.showDesktop()
        case .screenshot: SystemActions.openScreenshotTool()
        case .screenshotToClipboard(let fullScreen): SystemActions.screenshotToClipboard(fullScreen: fullScreen)
        case .taskManager: SystemActions.openTaskManager()
        }
    }
}
