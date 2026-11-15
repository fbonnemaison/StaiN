import AppKit
import StainKit
import SwiftUI

/// Muestra de color que distingue clic izquierdo, derecho y doble clic (SwiftUI no lo hace en macOS).
///
/// - `color == nil` dibuja una casilla vacía (borde discontinuo con "+").
/// - Si hay `menuItems`, el clic derecho abre ese menú en vez de llamar a `onSecondaryClick`.
struct SwatchView: NSViewRepresentable {
    struct MenuItem {
        let title: String
        let action: () -> Void
    }

    let color: PaintColor?
    var accessibilityLabel: String
    var cornerRadius: CGFloat = 3
    var onPrimaryClick: () -> Void
    var onSecondaryClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var menuItems: [MenuItem] = []

    func makeNSView(context: Context) -> SwatchNSView { SwatchNSView() }

    func updateNSView(_ view: SwatchNSView, context: Context) {
        if view.color != color || view.cornerRadius != cornerRadius {
            view.color = color
            view.cornerRadius = cornerRadius
            view.needsDisplay = true
        }
        view.onPrimaryClick = onPrimaryClick
        view.onSecondaryClick = onSecondaryClick
        view.onDoubleClick = onDoubleClick
        view.menuItems = menuItems
        view.setAccessibilityLabel(accessibilityLabel)
        view.setAccessibilityValue(color?.hex ?? String(localized: "Vacío"))
    }
}

final class SwatchNSView: NSView {
    var color: PaintColor?
    var cornerRadius: CGFloat = 3
    var onPrimaryClick: (() -> Void)?
    var onSecondaryClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var menuItems: [SwatchView.MenuItem] = []
    /// Mantiene vivos los destinos de las acciones del menú mientras está abierto.
    private var menuTargets: [MenuTarget] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let shape = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        guard let color else {
            // Casilla vacía: borde discontinuo y un "+" pequeño.
            shape.lineWidth = 1
            shape.setLineDash([2, 2], count: 2, phase: 0)
            NSColor.secondaryLabelColor.setStroke()
            shape.stroke()
            let plus = NSBezierPath()
            let c = NSPoint(x: bounds.midX, y: bounds.midY)
            let arm = min(bounds.width, bounds.height) * 0.2
            plus.move(to: NSPoint(x: c.x - arm, y: c.y))
            plus.line(to: NSPoint(x: c.x + arm, y: c.y))
            plus.move(to: NSPoint(x: c.x, y: c.y - arm))
            plus.line(to: NSPoint(x: c.x, y: c.y + arm))
            plus.lineWidth = 1
            plus.stroke()
            return
        }
        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        if !color.isOpaque {
            Checkerboard.smallColor.setFill()
            rect.fill()
        }
        color.nsColor.setFill()
        rect.fill(using: .sourceOver)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.separatorColor.setStroke()
        shape.lineWidth = 1
        shape.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let onDoubleClick {
            onDoubleClick()
        } else {
            onPrimaryClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard !menuItems.isEmpty else {
            (onSecondaryClick ?? onPrimaryClick)?()
            return
        }
        let menu = NSMenu()
        menuTargets = menuItems.map { MenuTarget(action: $0.action) }
        for (item, target) in zip(menuItems, menuTargets) {
            let menuItem = NSMenuItem(title: item.title, action: #selector(MenuTarget.performAction), keyEquivalent: "")
            menuItem.target = target
            menu.addItem(menuItem)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func accessibilityPerformPress() -> Bool {
        onPrimaryClick?()
        return true
    }
}

private final class MenuTarget: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction() { action() }
}
