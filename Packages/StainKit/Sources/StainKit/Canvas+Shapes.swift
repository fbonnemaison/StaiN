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
    // Formas de la galería de la herramienta Polígono: se dibujan arrastrando, como un rectángulo.
    case rightTriangle
    case isoscelesTriangle
    case diamond
    case pentagon
    case hexagon
    case arrowRight
    case arrowLeft
    case arrowUp
    case arrowDown

    /// Formas que ofrece la herramienta Polígono, en el orden de su galería.
    public static let polygonPresets: [ShapeKind] = [
        .rightTriangle, .isoscelesTriangle, .diamond, .pentagon, .hexagon,
        .arrowRight, .arrowLeft, .arrowUp, .arrowDown,
    ]

    /// Vértices en el cuadrado unidad (y hacia abajo), o `nil` para las formas curvas.
    public var unitVertices: [CGPoint]? {
        switch self {
        case .rectangle, .roundedRectangle, .ellipse: return nil
        case .rightTriangle: return [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
        case .isoscelesTriangle: return [CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 1)]
        case .diamond:
            return [CGPoint(x: 0.5, y: 0), CGPoint(x: 1, y: 0.5), CGPoint(x: 0.5, y: 1), CGPoint(x: 0, y: 0.5)]
        case .pentagon: return Self.regularPolygon(sides: 5, startAngle: -.pi / 2)
        case .hexagon: return Self.regularPolygon(sides: 6, startAngle: 0)
        case .arrowRight: return Self.arrow
        case .arrowLeft: return Self.arrow.map { CGPoint(x: 1 - $0.x, y: $0.y) }
        case .arrowUp: return Self.arrow.map { CGPoint(x: $0.y, y: 1 - $0.x) }
        case .arrowDown: return Self.arrow.map { CGPoint(x: $0.y, y: $0.x) }
        }
    }

    /// Flecha hacia la derecha: el cuerpo ocupa la mitad central y la punta el 45 % final.
    private static let arrow: [CGPoint] = [
        CGPoint(x: 0, y: 0.25), CGPoint(x: 0.55, y: 0.25), CGPoint(x: 0.55, y: 0), CGPoint(x: 1, y: 0.5),
        CGPoint(x: 0.55, y: 1), CGPoint(x: 0.55, y: 0.75), CGPoint(x: 0, y: 0.75),
    ]

    /// Polígono regular estirado para llenar el cuadrado unidad.
    private static func regularPolygon(sides: Int, startAngle: Double) -> [CGPoint] {
        let points = (0..<sides).map { index in
            let angle = startAngle + Double(index) * 2 * .pi / Double(sides)
            return CGPoint(x: cos(angle), y: sin(angle))
        }
        let minX = points.map(\.x).min() ?? 0, maxX = points.map(\.x).max() ?? 1
        let minY = points.map(\.y).min() ?? 0, maxY = points.map(\.y).max() ?? 1
        return points.map { CGPoint(x: ($0.x - minX) / (maxX - minX), y: ($0.y - minY) / (maxY - minY)) }
    }

    /// Trazado de la forma dentro de `frame`.
    public func path(in frame: CGRect) -> CGPath {
        switch self {
        case .rectangle:
            return CGPath(rect: frame, transform: nil)
        case .ellipse:
            return CGPath(ellipseIn: frame, transform: nil)
        case .roundedRectangle:
            let radius = min(20, min(frame.width, frame.height) * 0.2)
            return CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
        default:
            let path = CGMutablePath()
            let points = (unitVertices ?? []).map {
                CGPoint(x: frame.minX + $0.x * frame.width, y: frame.minY + $0.y * frame.height)
            }
            path.addLines(between: points)
            path.closeSubpath()
            return path
        }
    }
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

    /// Forma (rectángulo, elipse, triángulo, flecha…) que ocupa exactamente `rect` (el contorno queda dentro).
    public mutating func drawShape(_ kind: ShapeKind, in rect: PixelRect, style: ShapeStyle) {
        guard !rect.isEmpty else { return }
        var frame = rect.cgRect
        if style.fillMode != .fill {
            // El trazo va centrado en el borde: se mete media línea para no salirse del rectángulo.
            let inset = min(CGFloat(style.lineWidth) / 2, min(frame.width, frame.height) / 2 - 0.01)
            frame = frame.insetBy(dx: max(inset, 0), dy: max(inset, 0))
        }
        drawPath(kind.path(in: frame), closed: true, style: style)
    }

    /// Sustituye (sin mezclar) todos los píxeles de `rect` por un color.
    public mutating func fill(_ rect: PixelRect, with color: PaintColor) {
        let rect = rect.intersection(bitmap.bounds)
        guard !rect.isEmpty else { return }
        replaceRegion(rect, with: Bitmap(width: rect.width, height: rect.height, fill: color))
    }
}
