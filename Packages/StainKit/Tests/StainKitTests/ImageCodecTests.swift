import Foundation
import Testing
import UniformTypeIdentifiers

@testable import StainKit

@Suite struct ImageCodecTests {
    /// Imagen de prueba con pocos colores (para que GIF, con su paleta de 256, sea exacto).
    func sample(transparent: Bool) -> Bitmap {
        var bitmap = Bitmap(width: 8, height: 6)
        for x in 0..<8 { bitmap[x, 0] = PaintColor(red: 255, green: 0, blue: 0) }
        for y in 0..<6 { bitmap[7, y] = PaintColor(red: 0, green: 0, blue: 255) }
        if transparent { bitmap[0, 5] = .clear }
        return bitmap
    }

    @Test(arguments: [UTType.png, .tiff, .bmp, .gif])
    func losslessRoundTrip(type: UTType) throws {
        let original = sample(transparent: false)
        let decoded = try ImageCodec.decode(try ImageCodec.encode(original, as: type))
        #expect(decoded == original)
    }

    @Test func pngKeepsTransparency() throws {
        let original = sample(transparent: true)
        let decoded = try ImageCodec.decode(try ImageCodec.encode(original, as: .png))
        #expect(decoded[0, 5] == .clear)
    }

    @Test(arguments: [UTType.jpeg, .bmp])
    func formatsWithoutAlphaAreFlattenedOntoWhite(type: UTType) throws {
        let decoded = try ImageCodec.decode(try ImageCodec.encode(sample(transparent: true), as: type))
        #expect(decoded[0, 5].alpha == 255)
        #expect(decoded[0, 5].red > 240 && decoded[0, 5].green > 240)
    }

    @Test(arguments: [UTType.jpeg, .heic])
    func lossyFormatsAreClose(type: UTType) throws {
        var original = Bitmap(width: 32, height: 32, fill: PaintColor(red: 200, green: 60, blue: 20))
        original[0, 0] = PaintColor(red: 200, green: 60, blue: 20)
        let decoded = try ImageCodec.decode(try ImageCodec.encode(original, as: type, quality: 1))
        let pixel = decoded[16, 16]
        #expect(abs(Int(pixel.red) - 200) < 8 && abs(Int(pixel.green) - 60) < 8 && abs(Int(pixel.blue) - 20) < 8)
    }

    @Test func jpegQualityAffectsSize() throws {
        var noisy = Bitmap(width: 64, height: 64)
        for y in 0..<64 {
            for x in 0..<64 {
                noisy[x, y] = PaintColor(
                    red: UInt8((x * 37) % 256), green: UInt8((y * 91) % 256), blue: UInt8((x * y) % 256))
            }
        }
        let small = try ImageCodec.encode(noisy, as: .jpeg, quality: 0.1)
        let large = try ImageCodec.encode(noisy, as: .jpeg, quality: 1)
        #expect(small.count < large.count)
    }

    @Test func unsupportedTypeThrows() {
        #expect(throws: ImageCodec.Error.unsupportedType(UTType.pdf.identifier)) {
            try ImageCodec.encode(Bitmap(width: 1, height: 1), as: .pdf)
        }
    }

    @Test func garbageDataThrows() {
        #expect(throws: ImageCodec.Error.unreadableImage) {
            try ImageCodec.decode(Data("no es una imagen".utf8))
        }
    }
}
