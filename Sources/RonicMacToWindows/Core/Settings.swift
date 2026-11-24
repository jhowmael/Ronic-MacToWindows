import Foundation

/// Preferências persistidas em UserDefaults. Lidas na inicialização e gravadas só quando
/// o usuário muda algo no menu. Nunca acessadas pelo callback do teclado.
final class Settings {
    /// Apps em que o Control original é preservado (terminais, VMs, área de trabalho remota).
    static let defaultExcludedBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "com.microsoft.rdc.macos",        // Windows App / Área de Trabalho Remota
        "com.parallels.desktop.console",
        "com.vmware.fusion",
        "com.utmapp.UTM",
    ]

    private enum Keys {
        static let groups = "shortcutGroups"
        static let excluded = "excludedBundleIDs"
        static let swapSectionKeys = "swapSectionKeys"
    }

    /// Desfaz a troca física das teclas ' " e \ | em teclados de PC.
    var swapSectionKeys: Bool {
        didSet { defaults.set(swapSectionKeys, forKey: Keys.swapSectionKeys) }
    }

    private let defaults = UserDefaults.standard

    /// Ao abrir o app, o remapeamento começa sempre ativo (abrir o app = querer usá-lo).
    var isEnabled = true

    var groups: ShortcutGroups {
        didSet { defaults.set(Int(groups.rawValue), forKey: Keys.groups) }
    }

    private(set) var excludedBundleIDs: [String]
    private var excludedSet: Set<String>

    init() {
        if let stored = defaults.object(forKey: Keys.groups) as? Int {
            groups = ShortcutGroups(rawValue: UInt8(truncatingIfNeeded: stored))
        } else {
            groups = .all
        }
        swapSectionKeys = defaults.bool(forKey: Keys.swapSectionKeys)
        let excluded = defaults.stringArray(forKey: Keys.excluded) ?? Self.defaultExcludedBundleIDs
        excludedBundleIDs = excluded
        excludedSet = Set(excluded)
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedSet.contains(bundleID)
    }

    func addExclusion(_ bundleID: String) {
        guard !excludedSet.contains(bundleID) else { return }
        excludedBundleIDs.append(bundleID)
        excludedSet.insert(bundleID)
        persistExclusions()
    }

    func removeExclusion(_ bundleID: String) {
        guard excludedSet.remove(bundleID) != nil else { return }
        excludedBundleIDs.removeAll { $0 == bundleID }
        persistExclusions()
    }

    func resetExclusions() {
        excludedBundleIDs = Self.defaultExcludedBundleIDs
        excludedSet = Set(excludedBundleIDs)
        persistExclusions()
    }

    private func persistExclusions() {
        defaults.set(excludedBundleIDs, forKey: Keys.excluded)
    }
}
