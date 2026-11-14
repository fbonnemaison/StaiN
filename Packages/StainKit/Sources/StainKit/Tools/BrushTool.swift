/// Pincel con forma y tamaño. Sin antialiasing, como el de Paint.
public struct BrushTool: Tool {
    public var mask: BrushMask
    private var lastPixel: (x: Int, y: Int)?
    private var color: PaintColor = .black

    public init(shape: BrushShape = .round, size: Int = 3) {
        mask = BrushMask(shape: shape, size: size)
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        color = canvas.color(for: event.button)
        let pixel = event.pixel
        canvas.stamp(mask, atX: pixel.x, y: pixel.y, color: color)
        lastPixel = pixel
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
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
