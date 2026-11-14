/// Lápiz: trazo de 1 píxel sin antialiasing. Botón izquierdo = color primario, derecho = secundario.
public struct PencilTool: Tool {
    private var lastPixel: (x: Int, y: Int)?
    private var color: PaintColor = .black

    public init() {}

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        color = canvas.color(for: event.button)
        let pixel = event.pixel
        canvas.setPixel(x: pixel.x, y: pixel.y, to: color)
        lastPixel = pixel
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        let from = lastPixel ?? pixel
        canvas.drawPixelLine(fromX: from.x, y: from.y, toX: pixel.x, y: pixel.y, color: color)
        lastPixel = pixel
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        lastPixel = nil
    }

    public mutating func cancel(on canvas: inout Canvas) {
        lastPixel = nil
    }
}
