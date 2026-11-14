import CoreGraphics
import Foundation

/// Flecha para anotar capturas: línea con punta rellena. Con Shift, ángulos de 45°.
public struct ArrowTool: Tool {
    public var lineWidth: Int
    public var antialiased: Bool
    private var start: (x: Int, y: Int)?
    private var color: PaintColor = .black

    public init(lineWidth: Int = 4, antialiased: Bool = true) {
        self.lineWidth = max(1, lineWidth)
        self.antialiased = antialiased
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        color = canvas.color(for: event.button)
        start = event.pixel
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        guard let start else { return }
        let end = LineTool.endpoint(from: start, to: event.pixel, constrained: event.modifiers.contains(.shift))
        canvas.revertToEditStart()
        canvas.drawArrow(
            from: CGPoint(x: Double(start.x) + 0.5, y: Double(start.y) + 0.5),
            to: CGPoint(x: Double(end.x) + 0.5, y: Double(end.y) + 0.5), lineWidth: lineWidth, color: color,
            antialiased: antialiased)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        start = nil
    }
}

/// Resaltador: trazo ancho y semitransparente que se multiplica con lo de debajo.
/// Todo el trazo se pinta de una vez, así que no se oscurece donde se cruza consigo mismo.
public struct HighlighterTool: Tool {
    public var size: Int
    public var antialiased: Bool
    private var points: [CGPoint] = []
    private var color: PaintColor = .black

    public init(size: Int = 16, antialiased: Bool = true) {
        self.size = max(1, size)
        self.antialiased = antialiased
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        var base = canvas.color(for: event.button)
        base.alpha = 110
        color = base
        points = [Self.center(event)]
        render(on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let point = Self.center(event)
        guard point != points.last else { return }
        points.append(point)
        render(on: &canvas)
    }

    private static func center(_ event: PointerEvent) -> CGPoint {
        CGPoint(x: Double(event.pixel.x) + 0.5, y: Double(event.pixel.y) + 0.5)
    }

    private func render(on canvas: inout Canvas) {
        guard let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        if points.count == 1 { path.addLine(to: first) }
        let width = CGFloat(size)
        let area = PixelRect(covering: path.boundingBoxOfPath.insetBy(dx: -width, dy: -width))
        canvas.revertToEditStart()
        canvas.draw(in: area, antialiased: antialiased) { context in
            context.setBlendMode(.multiply)
            context.addPath(path)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
        }
    }
}

/// Oculta datos en una captura: pixela, desenfoca o tapa con un bloque la zona arrastrada.
public struct RedactTool: Tool {
    public enum Mode: String, CaseIterable, Sendable {
        case pixelate
        case blur
        case block
    }

    public var mode: Mode
    private var anchor: (x: Int, y: Int)?
    private var rect: PixelRect = .zero
    private var color: PaintColor = .black

    public init(mode: Mode = .pixelate) {
        self.mode = mode
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        color = canvas.color(for: event.button)
        anchor = event.pixel
        rect = PixelRect(corner: event.pixel, event.pixel)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        guard let anchor else { return }
        rect = PixelRect(corner: anchor, event.pixel).intersection(canvas.bitmap.bounds)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        anchor = nil
        guard rect.width > 1, rect.height > 1, let region = canvas.bitmap.cropped(to: rect) else { return }
        let processed: Bitmap
        switch mode {
        case .block:
            processed = Bitmap(width: rect.width, height: rect.height, fill: color)
        case .pixelate:
            processed = region.pixelated(blockSize: max(6, min(rect.width, rect.height) / 6))
        case .blur:
            // Pixelar antes de desenfocar evita que el texto se pueda leer a través del desenfoque.
            processed = ImageFilter.blur(radius: max(6, Double(min(rect.width, rect.height)) / 8))
                .apply(to: region.pixelated(blockSize: 4))
        }
        canvas.composite(processed, mask: nil, atX: rect.x, y: rect.y)
    }

    public var overlay: ToolOverlay? {
        guard anchor != nil, !rect.isEmpty else { return nil }
        let r = rect.cgRect
        return ToolOverlay(outline: [
            CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
            CGPoint(x: r.minX, y: r.maxY),
        ])
    }
}

/// Marcador numerado (1, 2, 3…) para explicar pasos en una captura.
public struct StepMarkerTool: Tool {
    public var number: Int
    public var radius: Int
    public var antialiased: Bool

    public init(number: Int, radius: Int = 14, antialiased: Bool = true) {
        self.number = number
        self.radius = max(4, radius)
        self.antialiased = antialiased
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let color = canvas.color(for: event.button)
        let center = CGPoint(x: Double(event.pixel.x) + 0.5, y: Double(event.pixel.y) + 0.5)
        let r = CGFloat(radius)
        let circle = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
        canvas.draw(in: PixelRect(covering: circle.insetBy(dx: -1, dy: -1)), antialiased: antialiased) { context in
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: circle)
        }
        // Número blanco sobre colores oscuros y negro sobre claros.
        let luminance = 0.299 * Double(color.red) + 0.587 * Double(color.green) + 0.114 * Double(color.blue)
        let style = TextStyle(
            fontName: "Helvetica", size: Double(radius) * 1.2, bold: true,
            color: luminance > 150 ? .black : .white, antialiased: antialiased)
        canvas.drawCenteredText("\(number)", style: style, center: center)
    }
}

extension Canvas {
    /// Línea con punta de flecha triangular en `end`.
    public mutating func drawArrow(
        from start: CGPoint, to end: CGPoint, lineWidth: Int, color: PaintColor, antialiased: Bool = true
    ) {
        let width = CGFloat(max(1, lineWidth))
        let dx = end.x - start.x, dy = end.y - start.y
        let length = hypot(dx, dy)
        let headLength = min(max(width * 3, 10), max(length, 1))
        let headHalfWidth = headLength * 0.55
        let ux = length > 0 ? dx / length : 1, uy = length > 0 ? dy / length : 0
        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
        let left = CGPoint(x: base.x - uy * headHalfWidth, y: base.y + ux * headHalfWidth)
        let right = CGPoint(x: base.x + uy * headHalfWidth, y: base.y - ux * headHalfWidth)

        let head = CGMutablePath()
        head.addLines(between: [end, left, right])
        head.closeSubpath()
        let shaft = CGMutablePath()
        shaft.move(to: start)
        shaft.addLine(to: CGPoint(x: base.x + ux * 1, y: base.y + uy * 1))

        let bounds = head.boundingBoxOfPath.union(shaft.boundingBoxOfPath).insetBy(dx: -width - 2, dy: -width - 2)
        draw(in: PixelRect(covering: bounds), antialiased: antialiased) { context in
            context.setStrokeColor(color.cgColor)
            context.setFillColor(color.cgColor)
            context.setLineWidth(width)
            context.setLineCap(.round)
            if length > headLength {
                context.addPath(shaft)
                context.strokePath()
            }
            context.addPath(head)
            context.fillPath()
        }
    }
}
