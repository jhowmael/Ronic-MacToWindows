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
        static let knownGroups = "knownShortcutGroups"
        static let accessibilityGranted = "accessibilityGrantedBefore"
    }

    /// Já tivemos permissão de Acessibilidade alguma vez? Se sim e agora não temos, quase sempre
    /// é a "chave órfã" de uma versão anterior do app (ver AppController.start).
    var accessibilityGrantedBefore: Bool {
        get { defaults.bool(forKey: Keys.accessibilityGranted) }
        set { defaults.set(newValue, forKey: Keys.accessibilityGranted) }
    }

    private let defaults = UserDefaults.standard

    /// Ao abrir o app, o remapeamento começa sempre ativo (abrir o app = querer usá-lo).
    var isEnabled = true

    var groups: ShortcutGroups {
        didSet {
            defaults.set(Int(groups.rawValue), forKey: Keys.groups)
            defaults.set(Int(ShortcutGroups.all.rawValue), forKey: Keys.knownGroups)
        }
    }

    private(set) var excludedBundleIDs: [String]
    private var excludedSet: Set<String>

    init() {
        if let stored = defaults.object(forKey: Keys.groups) as? Int {
            // Grupos criados em versões mais novas começam ligados, mesmo para quem já tinha
            // preferências salvas (a 1.0/1.1 só conheciam os 4 primeiros grupos).
            let known = ShortcutGroups(rawValue: UInt8(truncatingIfNeeded: defaults.object(forKey: Keys.knownGroups) as? Int ?? 0b1111))
            groups = ShortcutGroups(rawValue: UInt8(truncatingIfNeeded: stored)).union(ShortcutGroups.all.subtracting(known))
        } else {
            groups = .all
        }
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
