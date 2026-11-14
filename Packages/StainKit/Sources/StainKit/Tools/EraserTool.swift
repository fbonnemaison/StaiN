/// Borrador cuadrado. Pinta con el color secundario (como Paint) o deja el área transparente.
public struct EraserTool: Tool {
    private var brush: BrushTool
    public var erasesToTransparent: Bool

    public init(size: Int = 8, erasesToTransparent: Bool = false) {
        brush = BrushTool(shape: .square, size: size)
        self.erasesToTransparent = erasesToTransparent
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        // El borrador usa siempre el "color de fondo", pulses el botón que pulses.
        let saved = (canvas.primaryColor, canvas.secondaryColor)
        let eraseColor = erasesToTransparent ? PaintColor.clear : canvas.secondaryColor
        canvas.primaryColor = eraseColor
        canvas.secondaryColor = eraseColor
        brush.begin(event, on: &canvas)
        (canvas.primaryColor, canvas.secondaryColor) = saved
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        brush.drag(event, on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        brush.end(event, on: &canvas)
    }

    public mutating func cancel(on canvas: inout Canvas) {
        brush.cancel(on: &canvas)
    }
}
