import AppKit

// Entry point. `.accessory` = no Dock icon and no app menu
// (Info.plist also sets LSUIElement = true; this covers `swift run` without a bundle).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
