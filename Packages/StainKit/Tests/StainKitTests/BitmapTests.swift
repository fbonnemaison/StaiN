import Testing

@testable import StainKit

@Suite struct BitmapTests {
    @Test func newBitmapIsFilledWithColor() {
        let bitmap = Bitmap(width: 3, height: 2, fill: .black)
        #expect(bitmap.pixels.count == 6)
        #expect(bitmap.pixels.allSatisfy { $0 == .black })
    }

    @Test func setAndGetPixel() {
        var bitmap = Bitmap(width: 4, height: 4)
        let red = PaintColor(red: 255, green: 0, blue: 0)
        bitmap[2, 3] = red
        #expect(bitmap[2, 3] == red)
        #expect(bitmap[3, 2] == .white)
    }

    @Test(arguments: [(-1, 0), (0, -1), (4, 0), (0, 4)])
    func boundsCheck(x: Int, y: Int) {
        #expect(!Bitmap(width: 4, height: 4).contains(x: x, y: y))
    }

    @Test func clearReplacesAllPixels() {
        var bitmap = Bitmap(width: 2, height: 2)
        bitmap.clear(to: .clear)
        #expect(bitmap.pixels.allSatisfy { $0 == .clear })
    }
}
