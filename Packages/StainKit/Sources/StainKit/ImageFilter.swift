import CoreGraphics
import CoreImage
import Foundation

/// Filtros de imagen. Los de color usan Core Image; pixelar y umbral se calculan aquí para que sean exactos.
public enum ImageFilter: Sendable, Hashable {
    case grayscale
    /// Intensidad 0–1.
    case sepia(intensity: Double)
    case invert
    /// Brillo −1…1, contraste 0…4 (1 = igual), saturación 0…2 (1 = igual).
    case colorControls(brightness: Double, contrast: Double, saturation: Double)
    /// Radio en píxeles.
    case blur(radius: Double)
    /// Intensidad 0…2.
    case sharpen(amount: Double)
    /// Lado del bloque en píxeles.
    case pixelate(blockSize: Int)
    /// Niveles por canal (2…30).
    case posterize(levels: Int)
    /// Luminancia 0…1 a partir de la cual el píxel es blanco.
    case threshold(level: Double)

    private static let context = CIContext(options: [
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
        .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
    ])

    public func apply(to bitmap: Bitmap) -> Bitmap {
        switch self {
        case .invert: return bitmap.inverted()
        case .pixelate(let size): return bitmap.pixelated(blockSize: size)
        case .threshold(let level): return bitmap.thresholded(level: level)
        default: return applyCoreImage(to: bitmap) ?? bitmap
        }
    }

    private func applyCoreImage(to bitmap: Bitmap) -> Bitmap? {
        guard let cgImage = bitmap.makeCGImage() else { return nil }
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent
        let output: CIImage?
        switch self {
        case .grayscale:
            output = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        case .sepia(let intensity):
            output = input.applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: intensity])
        case .colorControls(let brightness, let contrast, let saturation):
            output = input.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputBrightnessKey: brightness, kCIInputContrastKey: contrast,
                    kCIInputSaturationKey: saturation,
                ])
        case .blur(let radius):
            // Se extienden los bordes para que no entre transparencia desde fuera.
            output = input.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
                .cropped(to: extent)
        case .sharpen(let amount):
            output = input.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: amount])
        case .posterize(let levels):
            output = input.applyingFilter("CIColorPosterize", parameters: ["inputLevels": max(2, levels)])
        case .invert, .pixelate, .threshold:
            output = nil
        }
        guard let output, let result = Self.context.createCGImage(output, from: extent) else { return nil }
        return Bitmap(cgImage: result)
    }
}

extension Bitmap {
    /// Cada bloque de `blockSize` × `blockSize` toma el color medio del bloque.
    public func pixelated(blockSize: Int) -> Bitmap {
        let block = max(1, blockSize)
        guard block > 1 else { return self }
        var result = self
        let w = width, h = height
        result.storage.withUnsafeMutableBufferPointer { px in
            for by in stride(from: 0, to: h, by: block) {
                for bx in stride(from: 0, to: w, by: block) {
                    let maxX = min(bx + block, w), maxY = min(by + block, h)
                    var sum = [0, 0, 0, 0]
                    for y in by..<maxY {
                        for x in bx..<maxX {
                            let i = (y * w + x) * 4
                            for c in 0..<4 { sum[c] += Int(px[i + c]) }
                        }
                    }
                    let count = (maxX - bx) * (maxY - by)
                    let average = sum.map { UInt8(($0 + count / 2) / count) }
                    for y in by..<maxY {
                        for x in bx..<maxX {
                            let i = (y * w + x) * 4
                            for c in 0..<4 { px[i + c] = average[c] }
                        }
                    }
                }
            }
        }
        return result
    }

    /// Blanco o negro según la luminancia; conserva la transparencia.
    public func thresholded(level: Double) -> Bitmap {
        var result = self
        let cut = min(max(level, 0), 1) * 255
        result.storage.withUnsafeMutableBufferPointer { px in
            for i in stride(from: 0, to: px.count, by: 4) {
                let a = px[i + 3]
                guard a > 0 else { continue }
                let scale = 255 / Double(a)
                let luminance =
                    (0.299 * Double(px[i]) + 0.587 * Double(px[i + 1]) + 0.114 * Double(px[i + 2])) * scale
                let value: UInt8 = luminance >= cut ? a : 0
                px[i] = value
                px[i + 1] = value
                px[i + 2] = value
            }
        }
        return result
    }
}
