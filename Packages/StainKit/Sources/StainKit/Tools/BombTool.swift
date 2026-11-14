/// "Bomba" de Paintbrush: borra toda la imagen con el color secundario (o el primario con el botón derecho).
/// La app pide confirmación antes de usarla; se puede deshacer.
public struct BombTool: Tool {
    public init() {}

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let color = canvas.color(for: event.button == .primary ? .secondary : .primary)
        canvas.fill(canvas.bitmap.bounds, with: color)
    }
}
