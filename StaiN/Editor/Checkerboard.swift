import AppKit

/// Patrón a cuadros para mostrar la transparencia (lienzo y muestras de color).
enum Checkerboard {
    static let color = NSColor(patternImage: makeImage(side: 8))
    static let smallColor = NSColor(patternImage: makeImage(side: 4))

    private static func makeImage(side: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: side * 2, height: side * 2), flipped: false) { _ in
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: side * 2, height: side * 2).fill()
            NSColor(white: 0.82, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: side, height: side).fill()
            NSRect(x: side, y: side, width: side, height: side).fill()
            return true
        }
    }
}
