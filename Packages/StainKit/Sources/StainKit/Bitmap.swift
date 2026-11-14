/// Imagen raster en memoria: píxeles RGBA8 no premultiplicados, fila a fila.
public struct Bitmap: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [PaintColor]

    public init(width: Int, height: Int, fill: PaintColor = .white) {
        precondition(width > 0 && height > 0, "Bitmap size must be positive")
        self.width = width
        self.height = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && x < width && y >= 0 && y < height
    }

    public subscript(x: Int, y: Int) -> PaintColor {
        get {
            precondition(contains(x: x, y: y), "Pixel (\(x), \(y)) out of bounds")
            return pixels[y * width + x]
        }
        set {
            precondition(contains(x: x, y: y), "Pixel (\(x), \(y)) out of bounds")
            pixels[y * width + x] = newValue
        }
    }

    /// Rellena todo el bitmap con un color.
    public mutating func clear(to color: PaintColor) {
        for index in pixels.indices { pixels[index] = color }
    }
}
