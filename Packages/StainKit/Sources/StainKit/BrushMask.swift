/// Forma de la punta de un pincel o borrador.
public enum BrushShape: String, CaseIterable, Sendable, Hashable {
    case round
    case square
    /// Trazo caligráfico inclinado como "/".
    case forwardSlash
    /// Trazo caligráfico inclinado como "\".
    case backSlash
}

/// Conjunto de píxeles que se pintan alrededor del punto central de un "sello" de pincel.
public struct BrushMask: Sendable, Hashable {
    /// Desplazamientos respecto al píxel central.
    public let offsets: [Offset]
    public let size: Int

    public struct Offset: Sendable, Hashable {
        public let dx: Int
        public let dy: Int
    }

    public init(shape: BrushShape, size: Int) {
        let size = max(1, size)
        self.size = size
        let half = size / 2
        var offsets: [Offset] = []
        switch shape {
        case .square:
            for j in 0..<size { for i in 0..<size { offsets.append(Offset(dx: i - half, dy: j - half)) } }
        case .round:
            let center = Double(size - 1) / 2
            let radiusSquared = (Double(size) / 2) * (Double(size) / 2)
            for j in 0..<size {
                for i in 0..<size {
                    let dx = Double(i) - center
                    let dy = Double(j) - center
                    if dx * dx + dy * dy <= radiusSquared + 0.25 { offsets.append(Offset(dx: i - half, dy: j - half)) }
                }
            }
        case .forwardSlash:
            for i in 0..<size { offsets.append(Offset(dx: i - half, dy: (size - 1 - i) - half)) }
        case .backSlash:
            for i in 0..<size { offsets.append(Offset(dx: i - half, dy: i - half)) }
        }
        self.offsets = offsets
    }

    /// Rectángulo que ocupa el sello centrado en `(x, y)`.
    func bounds(atX x: Int, y: Int) -> PixelRect {
        PixelRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
    }
}

extension Bitmap {
    /// Sustituye (sin mezclar) los píxeles del sello centrado en `(x, y)`. Devuelve la región afectada.
    @discardableResult
    mutating func stamp(_ mask: BrushMask, atX x: Int, y: Int, color: PaintColor) -> PixelRect {
        let area = mask.bounds(atX: x, y: y).intersection(bounds)
        guard !area.isEmpty else { return .zero }
        let (r, g, b, a) = color.premultiplied
        let width = width, height = height
        storage.withUnsafeMutableBufferPointer { pixels in
            for offset in mask.offsets {
                let px = x + offset.dx
                let py = y + offset.dy
                guard px >= 0, px < width, py >= 0, py < height else { continue }
                let i = (py * width + px) * 4
                pixels[i] = r
                pixels[i + 1] = g
                pixels[i + 2] = b
                pixels[i + 3] = a
            }
        }
        return area
    }
}
