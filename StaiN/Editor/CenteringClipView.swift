import AppKit

/// Mantiene el lienzo centrado cuando es más pequeño que la ventana.
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentFrame = documentView?.frame else { return rect }
        if rect.width > documentFrame.width {
            rect.origin.x = documentFrame.midX - rect.width / 2
        }
        if rect.height > documentFrame.height {
            rect.origin.y = documentFrame.midY - rect.height / 2
        }
        return rect
    }
}
