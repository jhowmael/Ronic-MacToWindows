import os

/// Grupos de atalhos que podem ser ligados/desligados no menu.
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

    static let all: ShortcutGroups = [.editing, .textNavigation, .windows, .winKey]
}

/// Tudo o que o callback do event tap precisa saber, num único valor pequeno.
struct RemapSnapshot: Sendable {
    var enabled = true
    var frontmostExcluded = false
    var groups: ShortcutGroups = .all
}

/// Ponte entre a thread principal (que escreve quando algo muda) e a thread do event tap
/// (que lê a cada tecla). Um `os_unfair_lock` custa dezenas de nanossegundos: nada de I/O,
/// nada de dicionário, nada de alocação no caminho quente.
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
