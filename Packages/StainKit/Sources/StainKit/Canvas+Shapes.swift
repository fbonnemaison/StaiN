import CoreGraphics

/// Cómo se pinta una forma cerrada.
public enum ShapeFillMode: String, CaseIterable, Sendable, Hashable {
    /// Solo el contorno, con el color del botón.
    case outline
    /// Contorno con el color del botón y relleno con el otro color.
    case outlineAndFill
    /// Solo relleno, con el color del botón.
    case fill
}

/// Estilo de trazo y relleno de una forma.
public struct ShapeStyle: Sendable, Hashable {
    public var fillMode: ShapeFillMode
    public var lineWidth: Int
    public var outlineColor: PaintColor
    public var fillColor: PaintColor

    public init(fillMode: ShapeFillMode = .outline, lineWidth: Int = 1, outlineColor: PaintColor, fillColor: PaintColor)
    {
        self.fillMode = fillMode
        self.lineWidth = max(1, lineWidth)
        self.outlineColor = outlineColor
        self.fillColor = fillColor
    }

    /// Estilo según el botón: el izquierdo contornea con el primario y rellena con el secundario; el derecho, al revés.
    public init(fillMode: ShapeFillMode, lineWidth: Int, button: PointerButton, canvas: Canvas) {
        self.init(
            fillMode: fillMode, lineWidth: lineWidth, outlineColor: canvas.color(for: button),
            fillColor: canvas.color(for: button == .primary ? .secondary : .primary))
    }
}

public enum ShapeKind: String, CaseIterable, Sendable, Hashable {
    case rectangle
    case roundedRectangle
    case ellipse
}

extension PixelRect {
    /// Rectángulo que abarca los dos píxeles (incluidos).
    public init(corner a: (x: Int, y: Int), _ b: (x: Int, y: Int)) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x) + 1, height: abs(a.y - b.y) + 1)
    }

    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }

    /// Rectángulo entero que cubre un `CGRect`.
    init(covering rect: CGRect) {
        let r = rect.integral
        self.init(x: Int(r.minX), y: Int(r.minY), width: Int(r.width), height: Int(r.height))
    }
}

extension Canvas {
    /// Dibuja un trazado sin antialiasing. Si `closed`, se aplica el modo de relleno.
    public mutating func drawPath(_ path: CGPath, closed: Bool, style: ShapeStyle) {
        guard !path.isEmpty else { return }
        let width = CGFloat(style.lineWidth)
        let area = PixelRect(covering: path.boundingBoxOfPath.insetBy(dx: -width - 1, dy: -width - 1))
        draw(in: area, antialiased: false) { context in
            if closed && style.fillMode != .outline {
                context.addPath(path)
                let color = style.fillMode == .fill ? style.outlineColor : style.fillColor
                context.setFillColor(color.cgColor)
                context.fillPath()
            }
            if !closed || style.fillMode != .fill {
                context.addPath(path)
                context.setStrokeColor(style.outlineColor.cgColor)
                context.setLineWidth(width)
                context.setLineJoin(.round)
                context.setLineCap(.round)
                context.strokePath()
            }
        }
    }

    /// Rectángulo, rectángulo redondeado o elipse que ocupa exactamente `rect` (el contorno queda dentro).
    public mutating func drawShape(_ kind: ShapeKind, in rect: PixelRect, style: ShapeStyle) {
        guard !rect.isEmpty else { return }
        var frame = rect.cgRect
        if style.fillMode != .fill {
            // El trazo va centrado en el borde: se mete media línea para no salirse del rectángulo.
            let inset = min(CGFloat(style.lineWidth) / 2, min(frame.width, frame.height) / 2 - 0.01)
            frame = frame.insetBy(dx: max(inset, 0), dy: max(inset, 0))
        }
        let path: CGPath
        switch kind {
        case .rectangle:
            path = CGPath(rect: frame, transform: nil)
        case .ellipse:
            path = CGPath(ellipseIn: frame, transform: nil)
        case .roundedRectangle:
            let radius = min(20, min(frame.width, frame.height) * 0.2)
            path = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        drawPath(path, closed: true, style: style)
    }

    /// Sustituye (sin mezclar) todos los píxeles de `rect` por un color.
    public mutating func fill(_ rect: PixelRect, with color: PaintColor) {
        let rect = rect.intersection(bitmap.bounds)
        guard !rect.isEmpty else { return }
        replaceRegion(rect, with: Bitmap(width: rect.width, height: rect.height, fill: color))
    }
}
