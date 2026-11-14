import AppKit

/// Cursores de las herramientas: los de punta muestran su tamaño real con el zoom actual.
@MainActor
enum ToolCursors {
    private static var cache: [String: NSCursor] = [:]

    /// - Parameters:
    ///   - size: tamaño de la punta en píxeles de imagen (nil = herramienta sin punta).
    ///   - magnification: zoom actual.
    static func cursor(for tool: ToolKind, size: Int?, square: Bool, magnification: CGFloat) -> NSCursor {
        switch tool {
        case .zoom: return .zoomIn
        case .text: return .iBeam
        case .eyedropper: return symbolCursor("eyedropper", hotSpot: NSPoint(x: 1, y: 15))
        case .fill: return symbolCursor("drop.fill", hotSpot: NSPoint(x: 8, y: 15))
        default: break
        }
        guard let size else { return .crosshair }
        let diameter = CGFloat(size) * magnification
        // Muy pequeño en pantalla: la cruz se ve mejor que un círculo diminuto.
        guard diameter >= 6 else { return .crosshair }
        return outlineCursor(diameter: min(diameter, 256), square: square)
    }

    private static func outlineCursor(diameter: CGFloat, square: Bool) -> NSCursor {
        let key = "outline-\(Int(diameter.rounded()))-\(square)"
        if let cached = cache[key] { return cached }
        let side = diameter.rounded() + 4
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let rect = NSRect(x: 2, y: 2, width: side - 4, height: side - 4)
            let path = square ? NSBezierPath(rect: rect) : NSBezierPath(ovalIn: rect)
            // Contorno blanco y negro: se ve sobre cualquier color.
            path.lineWidth = 3
            NSColor.white.withAlphaComponent(0.9).setStroke()
            path.stroke()
            path.lineWidth = 1
            NSColor.black.setStroke()
            path.stroke()
            // Punto central para apuntar con precisión.
            NSColor.black.setFill()
            NSRect(x: side / 2 - 0.5, y: side / 2 - 0.5, width: 1, height: 1).fill()
            return true
        }
        let cursor = NSCursor(image: image, hotSpot: NSPoint(x: side / 2, y: side / 2))
        cache[key] = cursor
        return cursor
    }

    private static func symbolCursor(_ name: String, hotSpot: NSPoint) -> NSCursor {
        if let cached = cache[name] { return cached }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard
            let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
        else { return .crosshair }
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            // Halo blanco para que se vea sobre fondos oscuros.
            for dx in [-1.0, 1.0] {
                for dy in [-1.0, 1.0] {
                    symbol.tinted(.white).draw(in: rect.offsetBy(dx: dx, dy: dy).insetBy(dx: 1, dy: 1))
                }
            }
            symbol.tinted(.black).draw(in: rect.insetBy(dx: 1, dy: 1))
            return true
        }
        let cursor = NSCursor(image: image, hotSpot: hotSpot)
        cache[name] = cursor
        return cursor
    }
}

extension NSImage {
    fileprivate func tinted(_ color: NSColor) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            self.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}

extension EditorState {
    /// Tamaño de la punta de la herramienta activa, si tiene.
    var tipSize: (size: Int, square: Bool)? {
        switch tool {
        case .brush: (brushSize, brushShape == .square)
        case .eraser: (eraserSize, true)
        case .airbrush: (airbrushRadius * 2 + 1, false)
        case .highlighter: (highlighterSize, false)
        default: nil
        }
    }
}
