/// Imagen raster en memoria.
///
/// Internamente guarda píxeles RGBA8 **premultiplicados** (sRGB), fila a fila y empezando por arriba,
/// que es el formato que Core Graphics usa para dibujar directamente sobre el buffer.
/// La API pública trabaja con `PaintColor` no premultiplicado.
///
/// Es un tipo valor con copy-on-write: copiar un `Bitmap` es barato hasta que se modifica.
public struct Bitmap: Hashable, Sendable {
    public static let bytesPerPixel = 4

    public let width: Int
    public let height: Int
    var storage: [UInt8]

    public init(width: Int, height: Int, fill: PaintColor = .white) {
        precondition(width > 0 && height > 0, "Bitmap size must be positive")
        self.width = width
        self.height = height
        let (r, g, b, a) = fill.premultiplied
        var bytes = [UInt8](repeating: 0, count: width * height * Self.bytesPerPixel)
        if fill != .clear {
            for index in stride(from: 0, to: bytes.count, by: Self.bytesPerPixel) {
                bytes[index] = r
                bytes[index + 1] = g
                bytes[index + 2] = b
                bytes[index + 3] = a
            }
        }
        self.storage = bytes
    }

    /// Bytes por fila (stride). No hay relleno entre filas.
    public var bytesPerRow: Int { width * Self.bytesPerPixel }
    public var bounds: PixelRect { PixelRect(x: 0, y: 0, width: width, height: height) }
    /// Tamaño del buffer en bytes (útil para limitar la memoria del historial).
    public var byteCount: Int { storage.count }

    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && x < width && y >= 0 && y < height
    }

    @inline(__always) func offset(x: Int, y: Int) -> Int {
        (y * width + x) * Self.bytesPerPixel
    }

    public subscript(x: Int, y: Int) -> PaintColor {
        get {
            precondition(contains(x: x, y: y), "Pixel (\(x), \(y)) out of bounds")
            let i = offset(x: x, y: y)
            return PaintColor(
                premultipliedRed: storage[i], green: storage[i + 1], blue: storage[i + 2], alpha: storage[i + 3])
        }
        set {
            precondition(contains(x: x, y: y), "Pixel (\(x), \(y)) out of bounds")
            let i = offset(x: x, y: y)
            let (r, g, b, a) = newValue.premultiplied
            storage[i] = r
            storage[i + 1] = g
            storage[i + 2] = b
            storage[i + 3] = a
        }
    }

    /// Rellena todo el bitmap con un color.
    public mutating func clear(to color: PaintColor) {
        self = Bitmap(width: width, height: height, fill: color)
    }

    /// Copia de una región. El rectángulo se recorta a los límites del bitmap; devuelve `nil` si queda vacío.
    public func cropped(to rect: PixelRect) -> Bitmap? {
        let rect = rect.intersection(bounds)
        guard !rect.isEmpty else { return nil }
        var result = Bitmap(width: rect.width, height: rect.height, fill: .clear)
        let rowBytes = rect.width * Self.bytesPerPixel
        for row in 0..<rect.height {
            let src = offset(x: rect.x, y: rect.y + row)
            let dst = row * rowBytes
            result.storage.replaceSubrange(dst..<dst + rowBytes, with: storage[src..<src + rowBytes])
        }
        return result
    }

    /// Sustituye píxeles (sin mezclar) por los de `other`, colocando su esquina superior izquierda en `(x, y)`.
    /// Lo que quede fuera de los límites se ignora. Devuelve la región modificada.
    @discardableResult
    public mutating func replace(with other: Bitmap, atX x: Int, y: Int) -> PixelRect {
        let target = PixelRect(x: x, y: y, width: other.width, height: other.height).intersection(bounds)
        guard !target.isEmpty else { return .zero }
        let rowBytes = target.width * Self.bytesPerPixel
        for row in 0..<target.height {
            let src = other.offset(x: target.x - x, y: target.y - y + row)
            let dst = offset(x: target.x, y: target.y + row)
            storage.replaceSubrange(dst..<dst + rowBytes, with: other.storage[src..<src + rowBytes])
        }
        return target
    }
}
