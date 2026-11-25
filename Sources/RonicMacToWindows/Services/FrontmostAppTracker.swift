import AppKit

/// Keeps the frontmost app and the most-recently-used (MRU) app order in memory.
/// Updated by NSWorkspace notifications (zero polling); the keyboard callback only reads
/// a Bool precomputed from here.
@MainActor
final class FrontmostAppTracker {
    private(set) var currentApp: NSRunningApplication?
    private var mru: [pid_t] = []
    private let selfPID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []

    var onChange: ((NSRunningApplication?) -> Void)?

    var currentBundleID: String? { currentApp?.bundleIdentifier }

    init() {
        let ws = NSWorkspace.shared
        if let front = ws.frontmostApplication, front.processIdentifier != selfPID {
            currentApp = front
            mru.append(front.processIdentifier)
        }
        for app in ws.runningApplications where app.activationPolicy == .regular && !mru.contains(app.processIdentifier) {
            mru.append(app.processIdentifier)
        }

        let nc = ws.notificationCenter
        observers.append(nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.didActivate(app) }
        })
        observers.append(nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.didTerminate(app) }
        })
    }

    private func didActivate(_ app: NSRunningApplication?) {
        // Ronic itself (menu, "Add app…" panel) doesn't count as the frontmost app.
        guard let app, app.processIdentifier != selfPID else { return }
        currentApp = app
        let pid = app.processIdentifier
        if let i = mru.firstIndex(of: pid) { mru.remove(at: i) }
        mru.insert(pid, at: 0)
        onChange?(app)
    }

    private func didTerminate(_ app: NSRunningApplication?) {
        guard let app else { return }
        mru.removeAll { $0 == app.processIdentifier }
        if currentApp?.processIdentifier == app.processIdentifier {
            currentApp = nil
            onChange?(nil)
        }
    }

    /// Apps shown in the Dock, most recent first. Only built when Alt+Tab fires.
    func switchableApps() -> [NSRunningApplication] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != selfPID
        }
        var rank: [pid_t: Int] = [:]
        rank.reserveCapacity(mru.count)
        for (i, pid) in mru.enumerated() { rank[pid] = i }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return apps.sorted { a, b in
            if a.processIdentifier == frontPID { return true }
            if b.processIdentifier == frontPID { return false }
            return (rank[a.processIdentifier] ?? Int.max) < (rank[b.processIdentifier] ?? Int.max)
        }
    }
}
