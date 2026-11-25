import AppKit

/// Floating Alt+Tab panel: icon grid with the selected app highlighted.
/// Never steals focus (nonactivatingPanel) and shows on every Space, including full screen.
final class SwitcherPanel: NSPanel {
    private let cell: CGFloat = 96
    private let iconSize: CGFloat = 64
    private let padding: CGFloat = 20
    private let labelHeight: CGFloat = 26

    private var cellFrames: [NSRect] = []
    private var names: [String] = []
    private let highlight = NSView()
    private let label = NSTextField(labelWithString: "")

    init(apps: [NSRunningApplication], screen: NSScreen) {
        let maxColumns = max(1, Int((screen.visibleFrame.width * 0.9 - 2 * padding) / cell))
        let columns = min(apps.count, maxColumns)
        let rows = (apps.count + columns - 1) / columns
        let width = CGFloat(columns) * cell + 2 * padding
        let height = CGFloat(rows) * cell + 2 * padding + labelHeight
        let origin = NSPoint(x: screen.frame.midX - width / 2, y: screen.frame.midY - height / 2)

        super.init(contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        background.layer?.masksToBounds = true
        contentView = background

        highlight.wantsLayer = true
        highlight.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        highlight.layer?.cornerRadius = 14
        background.addSubview(highlight)

        for (i, app) in apps.enumerated() {
            let col = CGFloat(i % columns)
            let row = CGFloat(i / columns)
            let frame = NSRect(x: padding + col * cell,
                               y: height - padding - (row + 1) * cell,
                               width: cell, height: cell)
            cellFrames.append(frame)
            names.append(app.localizedName ?? app.bundleIdentifier ?? "App")

            let inset = (cell - iconSize) / 2
            let imageView = NSImageView(frame: frame.insetBy(dx: inset, dy: inset))
            imageView.image = app.icon
            imageView.imageScaling = .scaleProportionallyUpOrDown
            if app.isHidden { imageView.alphaValue = 0.55 }
            background.addSubview(imageView)
        }

        label.frame = NSRect(x: padding, y: padding / 2, width: width - 2 * padding, height: labelHeight)
        label.alignment = .center
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        background.addSubview(label)
    }

    func select(_ index: Int) {
        guard cellFrames.indices.contains(index) else { return }
        highlight.frame = cellFrames[index].insetBy(dx: 4, dy: 4)
        label.stringValue = names[index]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
