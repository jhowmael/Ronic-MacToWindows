import os

/// Shortcut groups that can be switched on/off from the menu.
struct ShortcutGroups: OptionSet, Sendable {
    let rawValue: UInt8

    /// Ctrl+C/V/X/Z/Y/A/S/F/N/T/W/P/L… → ⌘
    static let editing = ShortcutGroups(rawValue: 1 << 0)
    /// Home/End, Ctrl+Home/End, Ctrl+←/→, Ctrl+Backspace/Delete
    static let textNavigation = ShortcutGroups(rawValue: 1 << 1)
    /// Alt+Tab, Alt+F4, Print Screen, Ctrl+Shift+Esc
    static let windows = ShortcutGroups(rawValue: 1 << 2)
    /// Win+L, Win+D (Win = ⌘)
    static let winKey = ShortcutGroups(rawValue: 1 << 3)

    /// PrtSc, Win+Shift+S, ⇧⌘3 and ⇧⌘4 → screenshot straight to the clipboard
    static let screenshots = ShortcutGroups(rawValue: 1 << 4)

    static let all: ShortcutGroups = [.editing, .textNavigation, .windows, .winKey, .screenshots]
}

/// Everything the event tap callback needs to know, in one small value.
struct RemapSnapshot: Sendable {
    var enabled = true
    var frontmostExcluded = false
    var groups: ShortcutGroups = .all
}

/// Bridge between the main thread (which writes when something changes) and the event tap
/// thread (which reads on every keystroke). An `os_unfair_lock` costs tens of nanoseconds:
/// no I/O, no dictionaries, no allocation on the hot path.
final class SharedState: @unchecked Sendable {
    static let shared = SharedState()

    private let lock = OSAllocatedUnfairLock(initialState: RemapSnapshot())

    var snapshot: RemapSnapshot {
        lock.withLock { $0 }
    }

    func update(_ body: (inout RemapSnapshot) -> Void) {
        lock.withLockUnchecked { body(&$0) }
    }
}
