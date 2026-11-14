import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Lectura y escritura de archivos de imagen con ImageIO.
public enum ImageCodec {
    /// Formatos que StaiN sabe abrir y guardar.
    public static let supportedTypes: [UTType] = [.png, .jpeg, .bmp, .gif, .tiff, .heic]

    public enum Error: Swift.Error, Equatable {
        case unreadableImage
        case unsupportedType(String)
        case encodingFailed
    }

    /// Decodifica la primera imagen del archivo, aplicando la orientación EXIF (fotos del iPhone).
    public static func decode(_ data: Data) throws -> Bitmap {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw Error.unreadableImage }

        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let image: CGImage?
        if orientation == 1 {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        } else {
            // La miniatura a tamaño completo con transformación devuelve la imagen ya girada.
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        guard let image, let bitmap = Bitmap(cgImage: image) else { throw Error.unreadableImage }
        return bitmap
    }

    /// Codifica el bitmap en el formato pedido.
    ///
    /// JPEG y BMP no guardan bien la transparencia, así que se componen sobre blanco, como hace Paint.
    /// - Parameter quality: calidad de 0 a 1 para formatos con pérdida (JPEG, HEIC).
    public static func encode(_ bitmap: Bitmap, as type: UTType, quality: Double = 0.9) throws -> Data {
        guard let format = supportedTypes.first(where: { type.conforms(to: $0) }) else {
            throw Error.unsupportedType(type.identifier)
        }
        let flatten = format == .jpeg || format == .bmp
        guard let image = (flatten ? bitmap.flattened(onto: .white) : bitmap).makeCGImage() else {
            throw Error.encodingFailed
        }
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data as CFMutableData, format.identifier as CFString, 1, nil)
        else { throw Error.unsupportedType(format.identifier) }

        var properties: [CFString: Any] = [:]
        if format == .jpeg || format == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Error.encodingFailed }
        return data as Data
    }
}
