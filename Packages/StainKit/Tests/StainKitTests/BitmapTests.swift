import CoreGraphics
import Testing

@testable import StainKit

@Suite struct BitmapTests {
    let red = PaintColor(red: 255, green: 0, blue: 0)

    @Test func newBitmapIsFilledWithColor() {
        let bitmap = Bitmap(width: 3, height: 2, fill: .black)
        #expect(bitmap.byteCount == 3 * 2 * 4)
        #expect(bitmap.bytesPerRow == 12)
        for y in 0..<2 { for x in 0..<3 { #expect(bitmap[x, y] == .black) } }
    }

    @Test func setAndGetPixel() {
        var bitmap = Bitmap(width: 4, height: 4)
        bitmap[2, 3] = red
        #expect(bitmap[2, 3] == red)
        #expect(bitmap[3, 2] == .white)
    }

    @Test(arguments: [(-1, 0), (0, -1), (4, 0), (0, 4)])
    func boundsCheck(x: Int, y: Int) {
        #expect(!Bitmap(width: 4, height: 4).contains(x: x, y: y))
    }

    @Test func storageIsPremultiplied() {
        var bitmap = Bitmap(width: 1, height: 1, fill: .clear)
        bitmap[0, 0] = PaintColor(red: 200, green: 100, blue: 0, alpha: 128)
        #expect(Array(bitmap.storage) == [100, 50, 0, 128])
    }

    @Test func translucentColorRoundTripsWithinOneStep() {
        var bitmap = Bitmap(width: 1, height: 1, fill: .clear)
        let color = PaintColor(red: 37, green: 180, blue: 251, alpha: 128)
        bitmap[0, 0] = color
        let read = bitmap[0, 0]
        #expect(read.alpha == 128)
        #expect(abs(Int(read.red) - 37) <= 1)
        #expect(abs(Int(read.green) - 180) <= 1)
        #expect(abs(Int(read.blue) - 251) <= 1)
    }

    @Test func fullyTransparentReadsAsClear() {
        var bitmap = Bitmap(width: 1, height: 1)
        bitmap[0, 0] = PaintColor(red: 10, green: 20, blue: 30, alpha: 0)
        #expect(bitmap[0, 0] == .clear)
    }

    @Test func clearReplacesAllPixels() {
        var bitmap = Bitmap(width: 2, height: 2)
        bitmap.clear(to: .clear)
        #expect(bitmap.storage.allSatisfy { $0 == 0 })
    }

    @Test func cropAndReplace() throws {
        var bitmap = Bitmap(width: 5, height: 5)
        bitmap[2, 2] = red
        let crop = try #require(bitmap.cropped(to: PixelRect(x: 1, y: 1, width: 3, height: 3)))
        #expect(crop.width == 3 && crop.height == 3)
        #expect(crop[1, 1] == red)

        var target = Bitmap(width: 5, height: 5, fill: .black)
        let changed = target.replace(with: crop, atX: 3, y: 3)  // se sale por abajo a la derecha
        #expect(changed == PixelRect(x: 3, y: 3, width: 2, height: 2))
        #expect(target[4, 4] == red)
        #expect(target[3, 3] == .white)
        #expect(target[2, 2] == .black)
    }

    @Test func cropOutsideBoundsIsNil() {
        #expect(Bitmap(width: 2, height: 2).cropped(to: PixelRect(x: 5, y: 5, width: 2, height: 2)) == nil)
    }

    @Test func sampledTakesEveryNthPixel() throws {
        var bitmap = Bitmap(width: 5, height: 5)
        bitmap[0, 0] = red
        bitmap[2, 2] = red
        bitmap[4, 4] = red
        let sample = try #require(bitmap.sampled(bitmap.bounds, step: 2))
        #expect(sample.width == 3 && sample.height == 3)
        #expect(sample[0, 0] == red && sample[1, 1] == red && sample[2, 2] == red && sample[1, 0] == .white)
        #expect(bitmap.sampled(bitmap.bounds, step: 1) == bitmap)
    }

    @Test func copyOnWriteKeepsCopiesIndependent() {
        var a = Bitmap(width: 2, height: 2)
        let b = a
        a[0, 0] = red
        #expect(b[0, 0] == .white)
    }
}

@Suite struct CoreGraphicsTests {
    @Test func cgImageRoundTrip() throws {
        var bitmap = Bitmap(width: 3, height: 2, fill: .clear)
        bitmap[0, 0] = PaintColor(red: 255, green: 0, blue: 0)
        bitmap[2, 1] = PaintColor(red: 0, green: 0, blue: 255)
        bitmap[1, 0] = PaintColor(red: 0, green: 255, blue: 0, alpha: 255)

        let image = try #require(bitmap.makeCGImage())
        #expect(image.width == 3 && image.height == 2)
        let back = try #require(Bitmap(cgImage: image))
        #expect(back == bitmap)
    }

    @Test func drawingUsesTopLeftOrigin() {
        var bitmap = Bitmap(width: 4, height: 4)
        bitmap.draw(antialiased: false) { context in
            context.setFillColor(PaintColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        #expect(bitmap[0, 0] == .black)
        #expect(bitmap[0, 3] == .white)
    }

    @Test func drawingRespectsClip() {
        var bitmap = Bitmap(width: 4, height: 4)
        bitmap.draw(clippedTo: PixelRect(x: 1, y: 1, width: 2, height: 2), antialiased: false) { context in
            context.setFillColor(PaintColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        #expect(bitmap[1, 1] == .black && bitmap[2, 2] == .black)
        #expect(bitmap[0, 0] == .white && bitmap[3, 3] == .white)
    }

    @Test func antialiasingOffProducesHardEdges() {
        var bitmap = Bitmap(width: 8, height: 8)
        bitmap.draw(antialiased: false) { context in
            context.setFillColor(PaintColor.black.cgColor)
            context.fillEllipse(in: CGRect(x: 0.3, y: 0.3, width: 7.4, height: 7.4))
        }
        for y in 0..<8 {
            for x in 0..<8 { #expect(bitmap[x, y] == .black || bitmap[x, y] == .white) }
        }
    }

    @Test func paintColorCGColorRoundTrip() throws {
        let color = PaintColor(red: 12, green: 200, blue: 99, alpha: 51)
        #expect(try #require(PaintColor(cgColor: color.cgColor)) == color)
    }
}

@Suite struct PaintColorHexTests {
    @Test func parsesAndFormats() {
        #expect(PaintColor(hex: "#FF8000") == PaintColor(red: 255, green: 128, blue: 0))
        #expect(PaintColor(hex: "00ff0080") == PaintColor(red: 0, green: 255, blue: 0, alpha: 128))
        #expect(PaintColor(red: 1, green: 2, blue: 3).hex == "#010203")
        #expect(PaintColor(red: 1, green: 2, blue: 3, alpha: 4).hex == "#01020304")
    }

    @Test(arguments: ["", "#12345", "zzzzzz", "#1234567"])
    func rejectsInvalid(text: String) {
        #expect(PaintColor(hex: text) == nil)
    }
}
