import AppKit
import StainKit
import SwiftUI

/// Muestra de color que distingue clic izquierdo, derecho y doble clic (SwiftUI no lo hace en macOS).
struct SwatchView: NSViewRepresentable {
    let color: PaintColor
    var accessibilityLabel: String
    var onPrimaryClick: () -> Void
    var onSecondaryClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    func makeNSView(context: Context) -> SwatchNSView { SwatchNSView() }

    func updateNSView(_ view: SwatchNSView, context: Context) {
        if view.color != color {
            view.color = color
            view.needsDisplay = true
        }
        view.onPrimaryClick = onPrimaryClick
        view.onSecondaryClick = onSecondaryClick
        view.onDoubleClick = onDoubleClick
        view.setAccessibilityLabel(accessibilityLabel)
        view.setAccessibilityValue(color.hex)
    }
}

final class SwatchNSView: NSView {
    var color: PaintColor = .black
    var onPrimaryClick: (() -> Void)?
    var onSecondaryClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?

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
        if !color.isOpaque {
            Checkerboard.smallColor.setFill()
            rect.fill()
        }
        color.nsColor.setFill()
        rect.fill(using: .sourceOver)
        NSColor.separatorColor.setStroke()
        NSBezierPath(rect: rect).stroke()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let onDoubleClick {
            onDoubleClick()
        } else {
            onPrimaryClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        (onSecondaryClick ?? onPrimaryClick)?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPrimaryClick?()
        return true
    }
}
