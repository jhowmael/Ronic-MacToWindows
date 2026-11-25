import Foundation

/// Preferences persisted in UserDefaults. Read at launch and written only when the user
/// changes something in the menu. Never touched by the keyboard callback.
final class Settings {
    /// Apps where the original Control key is preserved (terminals, VMs, remote desktop).
    static let defaultExcludedBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "com.microsoft.rdc.macos",        // Windows App / Remote Desktop
        "com.parallels.desktop.console",
        "com.vmware.fusion",
        "com.utmapp.UTM",
    ]

    private enum Keys {
        static let groups = "shortcutGroups"
        static let excluded = "excludedBundleIDs"
        static let knownGroups = "knownShortcutGroups"
    }

    private let defaults = UserDefaults.standard

    /// Remapping always starts enabled at launch (opening the app = wanting to use it).
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
            // Groups added in newer versions start enabled, even for users who already had saved
            // preferences (1.0/1.1 only knew the first 4 groups).
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
