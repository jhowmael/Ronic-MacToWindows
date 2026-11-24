import AppKit
import UniformTypeIdentifiers

/// Ícone e menu na barra superior. O menu é reconstruído só quando é aberto
/// (menuNeedsUpdate); fora isso, nenhum trabalho de UI acontece.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private unowned let controller: AppController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshIcon()
    }

    func refreshIcon() {
        guard let button = statusItem.button else { return }
        if !controller.isEngineRunning {
            let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Ronic MacToWindows — sem permissão")
            image?.isTemplate = true
            button.image = image
            button.appearsDisabled = false
            button.toolTip = "Ronic MacToWindows — aguardando permissão de Acessibilidade"
        } else {
            button.image = StatusIcon.image
            button.appearsDisabled = !controller.isEnabled
            button.toolTip = controller.isEnabled ? "Ronic MacToWindows — ativo" : "Ronic MacToWindows — pausado"
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        controller.refreshPermissionAndEngine()
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()

        let status: String
        if !controller.isEngineRunning { status = "Aguardando permissão" }
        else if controller.isEnabled { status = "Remapeamento ativo" }
        else { status = "Pausado" }
        let header = NSMenuItem(title: "Ronic MacToWindows — \(status)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Ativar / Pausar
        let toggle = item(controller.isEnabled ? "Pausar remapeamento" : "Ativar remapeamento",
                          #selector(toggleEnabled), key: "p",
                          symbol: controller.isEnabled ? "pause.fill" : "play.fill")
        toggle.isEnabled = controller.isEngineRunning
        menu.addItem(toggle)
        menu.addItem(.separator())

        // Permissão de Acessibilidade
        if controller.isTrusted {
            let ok = NSMenuItem(title: "Acessibilidade: autorizada", action: nil, keyEquivalent: "")
            ok.image = symbol("checkmark.circle.fill")
            ok.isEnabled = false
            menu.addItem(ok)
            if !controller.isEngineRunning {
                menu.addItem(item("Tentar iniciar a captura de teclado", #selector(retryEngine), symbol: "arrow.clockwise"))
            }
        } else {
            let warn = NSMenuItem(title: "Acessibilidade: não autorizada", action: nil, keyEquivalent: "")
            warn.image = symbol("exclamationmark.triangle.fill")
            warn.isEnabled = false
            menu.addItem(warn)
            menu.addItem(item("Abrir Ajustes de Acessibilidade…", #selector(openAccessibility), symbol: "gearshape"))
        }
        menu.addItem(.separator())

        // Grupos de atalhos
        let groups = NSMenuItem(title: "Atalhos", action: nil, keyEquivalent: "")
        groups.image = symbol("keyboard")
        groups.submenu = buildGroupsMenu()
        menu.addItem(groups)

        // Layout de pontuação
        let layouts = NSMenuItem(title: "Layout do teclado (pontuação)", action: nil, keyEquivalent: "")
        layouts.image = symbol("character.cursor.ibeam")
        layouts.submenu = buildLayoutMenu()
        menu.addItem(layouts)

        // Apps ignorados
        let ignored = NSMenuItem(title: "Apps ignorados", action: nil, keyEquivalent: "")
        ignored.image = symbol("nosign")
        ignored.submenu = buildExclusionsMenu()
        menu.addItem(ignored)

        menu.addItem(.separator())
        menu.addItem(item("Sair do Ronic MacToWindows", #selector(quit), key: "q", symbol: "power"))
    }

    private func buildGroupsMenu() -> NSMenu {
        let sub = NSMenu()
        sub.autoenablesItems = false
        let entries: [(ShortcutGroups, String)] = [
            (.editing, "Edição — Ctrl+C/V/X/Z/Y/A/S/F/N/T/W/P/L → ⌘"),
            (.textNavigation, "Navegação de texto — Home/End, Ctrl+←/→, Ctrl+⌫"),
            (.windows, "Janelas — Alt+Tab, Alt+F4, Print Screen, Ctrl+Shift+Esc"),
            (.winKey, "Tecla Win (⌘) — Win+L bloquear, Win+D área de trabalho"),
        ]
        for (group, title) in entries {
            let it = item(title, #selector(toggleGroup(_:)))
            it.representedObject = Int(group.rawValue)
            it.state = controller.settings.groups.contains(group) ? .on : .off
            sub.addItem(it)
        }
        return sub
    }

    private func buildLayoutMenu() -> NSMenu {
        let sub = NSMenu()
        sub.autoenablesItems = false
        let active = KeyboardLayoutManager.currentWindowsLayout

        for layout in WindowsLayout.allCases {
            let it = item(layout.title, #selector(chooseLayout(_:)))
            it.representedObject = layout.rawValue
            it.state = layout == active ? .on : .off
            it.toolTip = layout.hint
            if #available(macOS 14.4, *) { it.subtitle = layout.hint }
            sub.addItem(it)
        }

        sub.addItem(.separator())
        let current = NSMenuItem(title: "Em uso: \(KeyboardLayoutManager.currentSourceName ?? "—")", action: nil, keyEquivalent: "")
        current.isEnabled = false
        sub.addItem(current)
        if active != nil, let previous = KeyboardLayoutManager.previousSourceName {
            sub.addItem(item("Voltar para “\(previous)”", #selector(restoreLayout), symbol: "arrow.uturn.backward"))
        }

        sub.addItem(.separator())
        let swap = item("Corrigir teclas ' e \\ trocadas (teclado de PC)", #selector(toggleSwapSectionKeys))
        swap.state = controller.settings.swapSectionKeys ? .on : .off
        swap.toolTip = "Use se a tecla à esquerda do 1 digitar \\ e a tecla à esquerda do Z digitar '"
        sub.addItem(swap)
        sub.addItem(item("Ajustes de Teclado do macOS…", #selector(openKeyboardSettings), symbol: "gearshape"))
        return sub
    }

    private func buildExclusionsMenu() -> NSMenu {
        let sub = NSMenu()
        sub.autoenablesItems = false
        let settings = controller.settings

        if let app = controller.tracker.currentApp, let id = app.bundleIdentifier {
            let name = app.localizedName ?? id
            let it: NSMenuItem
            if settings.isExcluded(id) {
                it = item("Voltar a remapear em “\(name)”", #selector(removeExclusion(_:)))
            } else {
                it = item("Ignorar “\(name)”", #selector(addExclusion(_:)))
            }
            it.representedObject = id
            it.image = icon(for: id)
            sub.addItem(it)
            sub.addItem(.separator())
        }

        let caption = NSMenuItem(title: "Ignorados (clique para remover)", action: nil, keyEquivalent: "")
        caption.isEnabled = false
        sub.addItem(caption)

        let entries = settings.excludedBundleIDs.map { (id: $0, name: displayName(for: $0) ?? $0) }
        for (id, name) in entries.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let it = item(name, #selector(removeExclusion(_:)))
            it.representedObject = id
            it.state = .on
            it.toolTip = id
            it.image = icon(for: id)
            sub.addItem(it)
        }

        sub.addItem(.separator())
        sub.addItem(item("Adicionar app…", #selector(addAppFromPanel), symbol: "plus"))
        sub.addItem(item("Restaurar padrões", #selector(resetExclusions), symbol: "arrow.counterclockwise"))
        return sub
    }

    // MARK: - Ações

    @objc private func toggleEnabled() { controller.setEnabled(!controller.isEnabled) }

    @objc private func retryEngine() { controller.refreshPermissionAndEngine() }

    @objc private func openAccessibility() {
        AccessibilityPermission.requestPrompt()
        AccessibilityPermission.openSystemSettings()
    }

    @objc private func toggleGroup(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? Int else { return }
        controller.toggleGroup(ShortcutGroups(rawValue: UInt8(raw)))
    }

    @objc private func chooseLayout(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let layout = WindowsLayout(rawValue: raw) else { return }
        controller.activateLayout(layout)
    }

    @objc private func restoreLayout() { KeyboardLayoutManager.restorePrevious() }

    @objc private func toggleSwapSectionKeys() { controller.toggleSwapSectionKeys() }

    @objc private func openKeyboardSettings() { KeyboardLayoutManager.openInputSourceSettings() }

    @objc private func addExclusion(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        controller.addExclusion(id)
    }

    @objc private func removeExclusion(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        controller.removeExclusion(id)
    }

    @objc private func resetExclusions() { controller.resetExclusions() }

    @objc private func addAppFromPanel() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Escolha os apps em que o Control original deve ser mantido"
        panel.prompt = "Ignorar"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier { controller.addExclusion(id) }
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Helpers

    private func item(_ title: String, _ action: Selector, key: String = "", symbol name: String? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        if let name { it.image = symbol(name) }
        return it
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private func displayName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}

/// Versão monocromática do logo para a barra de menus: "R" + barra de conversão + rastros.
/// Desenhada uma única vez, como imagem template (se adapta ao tema claro/escuro).
enum StatusIcon {
    static let image: NSImage = {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            // Rastros de movimento à esquerda (algo passando de lado).
            for (y, w, a) in [(5.0, 4.0, 0.55), (9.0, 6.0, 0.9), (13.0, 3.0, 0.4)] as [(CGFloat, CGFloat, CGFloat)] {
                NSColor.black.withAlphaComponent(a).setFill()
                NSBezierPath(roundedRect: NSRect(x: 0, y: y - 0.75, width: w, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()
            }

            // Letra R.
            let font = NSFont.systemFont(ofSize: 15, weight: .black)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let r = NSAttributedString(string: "R", attributes: attrs)
            let rSize = r.size()
            r.draw(at: NSPoint(x: 7, y: (rect.height - rSize.height) / 2))

            // Barra vertical de conversão.
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 7 + rSize.width + 1.5, y: 1.5, width: 1.6, height: rect.height - 3),
                         xRadius: 0.8, yRadius: 0.8).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Ronic MacToWindows"
        return image
    }()
}
