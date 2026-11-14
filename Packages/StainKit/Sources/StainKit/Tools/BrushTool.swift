/// Pincel con forma y tamaño. Sin antialiasing, como el de Paint.
public struct BrushTool: Tool {
    public var mask: BrushMask
    public let shape: BrushShape
    public let size: Int
    /// Con tableta, la presión reduce el tamaño (presión 1 = tamaño completo).
    public var usesPressure: Bool
    private var lastPixel: (x: Int, y: Int)?
    private var color: PaintColor = .black

    public init(shape: BrushShape = .round, size: Int = 3, usesPressure: Bool = false) {
        self.shape = shape
        self.size = size
        self.usesPressure = usesPressure
        mask = BrushMask(shape: shape, size: size)
    }

    /// Ajusta la punta a la presión del evento.
    private mutating func applyPressure(_ event: PointerEvent) {
        guard usesPressure else { return }
        let pressed = max(1, Int((Double(size) * min(max(event.pressure, 0), 1)).rounded()))
        if pressed != mask.size { mask = BrushMask(shape: shape, size: pressed) }
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        applyPressure(event)
        color = canvas.color(for: event.button)
        let pixel = event.pixel
        canvas.stamp(mask, atX: pixel.x, y: pixel.y, color: color)
        lastPixel = pixel
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        applyPressure(event)
        let pixel = event.pixel
        let from = lastPixel ?? pixel
        canvas.stampLine(mask, fromX: from.x, y: from.y, toX: pixel.x, y: pixel.y, color: color)
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
