/// Cuentagotas: toma el color bajo el puntero. Botón izquierdo → color primario, derecho → secundario.
/// No modifica la imagen, así que no genera pasos de deshacer.
public struct EyedropperTool: Tool {
    public init() {}

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        pick(event, &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        pick(event, &canvas)
    }

    private func pick(_ event: PointerEvent, _ canvas: inout Canvas) {
        let pixel = event.pixel
        guard let color = canvas.color(atX: pixel.x, y: pixel.y) else { return }
        if event.button == .primary {
            canvas.primaryColor = color
        } else {
            canvas.secondaryColor = color
        }
    }
}
