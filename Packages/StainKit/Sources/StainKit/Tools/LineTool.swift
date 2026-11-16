import Foundation

/// Línea recta con grosor. Con Shift, el ángulo se ajusta a múltiplos de 45°.
///
/// Se dibuja con un clic en el inicio y otro en el final (entre los dos, la vista previa sigue
/// al ratón), o arrastrando de un extremo al otro. Escape la descarta.
/// Mientras se crea se ven sus puntos de control (los extremos); al terminar desaparecen.
public struct LineTool: Tool {
    public var mask: BrushMask
    private var start: (x: Int, y: Int)?
    /// Extremo final actual (sigue al ratón hasta fijarse).
    private var current: (x: Int, y: Int)?
    private var color: PaintColor = .black
    /// Tras el primer clic sin arrastrar: espera el clic del final.
    private var waitingForEnd = false

    public init(width: Int = 1) {
        mask = BrushMask(shape: .round, size: width)
    }

    public var isAwaitingInput: Bool { waitingForEnd }
    public func accepts(_ event: PointerEvent) -> Bool { waitingForEnd }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        if waitingForEnd {
            // Segundo clic: fija el final.
            waitingForEnd = false
            drag(event, on: &canvas)
            return
        }
        color = canvas.color(for: event.button)
        let pixel = event.pixel
        start = pixel
        current = pixel
        canvas.stamp(mask, atX: pixel.x, y: pixel.y, color: color)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        guard let start else { return }
        let end = Self.endpoint(from: start, to: event.pixel, constrained: event.modifiers.contains(.shift))
        current = end
        canvas.revertToEditStart()
        canvas.stampLine(mask, fromX: start.x, y: start.y, toX: end.x, y: end.y, color: color)
    }

    public mutating func hover(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        guard let start else { return }
        if !waitingForEnd, event.pixel == start, isFirstClick {
            // Clic sin arrastrar: la línea sigue abierta hasta el clic del final.
            waitingForEnd = true
            isFirstClick = false
            return
        }
        drag(event, on: &canvas)
        self.start = nil
        current = nil
    }

    /// Puntos de control mientras se crea la línea; al terminar no hay ninguno.
    public var overlay: ToolOverlay? {
        guard let start else { return nil }
        let points = [start, current ?? start].map { CGPoint(x: Double($0.x) + 0.5, y: Double($0.y) + 0.5) }
        return ToolOverlay(outline: points, isClosed: false, handles: points)
    }

    private var isFirstClick = true

    /// Confirmar sin segundo clic (cambio de herramienta, Intro) no deja nada dibujado.
    public mutating func commit(on canvas: inout Canvas) {
        if waitingForEnd { canvas.revertToEditStart() }
        waitingForEnd = false
        start = nil
        current = nil
    }

    public mutating func cancel(on canvas: inout Canvas) {
        waitingForEnd = false
        start = nil
        current = nil
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
