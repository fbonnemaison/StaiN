/// Cubo de pintura: rellena el área contigua de color parecido.
public struct FillTool: Tool {
    /// Diferencia máxima por canal (0–255) para considerar un color "igual".
    public var tolerance: UInt8

    public init(tolerance: UInt8 = 0) {
        self.tolerance = tolerance
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        canvas.floodFill(x: pixel.x, y: pixel.y, with: canvas.color(for: event.button), tolerance: tolerance)
    }
}
