import CoreGraphics
import Foundation

extension Bitmap {
    static let colorSpace: CGColorSpace = {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { preconditionFailure("sRGB is unavailable") }
        return space
    }()
    static let bitmapInfo: UInt32 =
        CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

    /// Crea un bitmap a partir de una imagen, convirtiéndola a sRGB RGBA8 premultiplicado.
    public init?(cgImage: CGImage) {
        guard cgImage.width > 0, cgImage.height > 0 else { return nil }
        self.init(width: cgImage.width, height: cgImage.height, fill: .clear)
        let width = width, height = height, bytesPerRow = bytesPerRow
        let drawn: Bool = storage.withUnsafeMutableBytes { raw in
            guard
                let context = CGContext(
                    data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow, space: Self.colorSpace, bitmapInfo: Self.bitmapInfo)
            else { return false }
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
    }

    /// Imagen inmutable con una copia de los píxeles actuales.
    public func makeCGImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(storage) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: Self.colorSpace, bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo), provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// Copia sin transparencia: compone la imagen sobre un color de fondo (para JPEG y BMP).
    public func flattened(onto background: PaintColor = .white) -> Bitmap {
        guard let image = makeCGImage() else { return self }
        let width = width, height = height
        var result = Bitmap(width: width, height: height, fill: background)
        result.draw(antialiased: false) { context in
            // `draw` voltea el sistema de coordenadas; se deshace para que la imagen no salga invertida.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return result
    }

    /// Dibuja con Core Graphics directamente sobre los píxeles.
    ///
    /// - El sistema de coordenadas está volteado: el origen es la esquina superior izquierda y la Y crece hacia
    ///   abajo, igual que el subíndice `[x, y]`. El píxel `(x, y)` ocupa `CGRect(x: x, y: y, width: 1, height: 1)`.
    /// - `clip` limita lo que se puede pintar (útil para que el *dirty rect* sea exacto).
    /// - Con `antialiased == false` los bordes salen duros, como el lápiz clásico de Paint.
    public mutating func draw<Result>(
        clippedTo clip: PixelRect? = nil, antialiased: Bool = true, _ body: (CGContext) throws -> Result
    ) rethrows -> Result {
        let width = width, height = height, bytesPerRow = bytesPerRow
        return try storage.withUnsafeMutableBytes { raw in
            guard
                let context = CGContext(
                    data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow, space: Self.colorSpace, bitmapInfo: Self.bitmapInfo)
            else { preconditionFailure("Could not create a CGContext for the bitmap") }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setShouldAntialias(antialiased)
            context.setAllowsAntialiasing(antialiased)
            context.interpolationQuality = antialiased ? .high : .none
            if let clip {
                context.clip(to: CGRect(x: clip.x, y: clip.y, width: clip.width, height: clip.height))
            }
            return try body(context)
        }
    }
}
