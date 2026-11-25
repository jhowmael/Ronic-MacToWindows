import AppKit

/// Wires the pieces together: preferences, frontmost app, permission, event tap, Alt+Tab and menu.
/// Everything here runs on the main thread; the event tap only receives an updated snapshot.
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
            // No permission at launch: almost always an app update. The toggle in
            // Settings › Accessibility is still on, but it belongs to the previous binary, and
            // toggling it doesn't help. Remove the entry (orphaned or disabled) and ask again:
            // the user only has to switch it on. With no entry, the reset does nothing.
            AccessibilityPermission.resetEntry()
            AccessibilityPermission.requestPrompt()
        }
        refreshPermissionAndEngine()
    }

    func shutdown() {
        switcher.cancel()
        engine.stop()
    }

    // MARK: - Permission

    /// Creates the tap as soon as permission exists. Until then, checks every 2 s
    /// (a light timer that stops itself once permission is granted).
    func refreshPermissionAndEngine() {
        if AccessibilityPermission.isTrusted, !engine.isRunning, engine.start() {
            engine.setActive(settings.isEnabled)
        }

        if engine.isRunning {
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

    /// "I enabled it and it still says not authorized": removes the old entry, asks again and opens Settings.
    func resetPermission() {
        AccessibilityPermission.resetEntry()
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSystemSettings()
        refreshPermissionAndEngine()
    }

    /// Relaunches the app (last resort when macOS only allows the tap in a fresh process).
    func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Menu actions

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

    // MARK: - State for the event tap

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

    // MARK: - Actions coming from the keyboard

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
