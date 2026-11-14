import Foundation

/// Línea recta con grosor. Mientras se arrastra se muestra una vista previa.
/// Con Shift, el ángulo se ajusta a múltiplos de 45°.
public struct LineTool: Tool {
    public var mask: BrushMask
    private var start: (x: Int, y: Int)?
    private var color: PaintColor = .black

    public init(width: Int = 1) {
        mask = BrushMask(shape: .round, size: width)
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        color = canvas.color(for: event.button)
        let pixel = event.pixel
        start = pixel
        canvas.stamp(mask, atX: pixel.x, y: pixel.y, color: color)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        guard let start else { return }
        let end = Self.endpoint(from: start, to: event.pixel, constrained: event.modifiers.contains(.shift))
        canvas.revertToEditStart()
        canvas.stampLine(mask, fromX: start.x, y: start.y, toX: end.x, y: end.y, color: color)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        start = nil
    }

    public mutating func cancel(on canvas: inout Canvas) {
        start = nil
    }

    /// Punto final, ajustado a 0°, 45° o 90° si `constrained`.
    public static func endpoint(from start: (x: Int, y: Int), to end: (x: Int, y: Int), constrained: Bool) -> (
        x: Int, y: Int
    ) {
        guard constrained else { return end }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let tan22 = tan(Double.pi / 8)
        if Double(abs(dy)) <= Double(abs(dx)) * tan22 { return (end.x, start.y) }
        if Double(abs(dx)) <= Double(abs(dy)) * tan22 { return (start.x, end.y) }
        let length = max(abs(dx), abs(dy))
        return (start.x + (dx < 0 ? -length : length), start.y + (dy < 0 ? -length : length))
    }
}
