import AppKit

// Ponto de entrada. `.accessory` = sem ícone no Dock e sem menu de app
// (o Info.plist também define LSUIElement = true; isto cobre o `swift run` sem bundle).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
