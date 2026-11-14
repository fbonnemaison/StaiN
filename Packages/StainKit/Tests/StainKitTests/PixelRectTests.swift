import Testing

@testable import StainKit

@Suite struct PixelRectTests {
    @Test func intersection() {
        let a = PixelRect(x: 0, y: 0, width: 10, height: 10)
        #expect(
            a.intersection(PixelRect(x: 5, y: 5, width: 10, height: 10)) == PixelRect(x: 5, y: 5, width: 5, height: 5))
        #expect(a.intersection(PixelRect(x: 20, y: 0, width: 5, height: 5)).isEmpty)
    }

    @Test func unionIgnoresEmpty() {
        let a = PixelRect(x: 1, y: 2, width: 3, height: 4)
        #expect(PixelRect.zero.union(a) == a)
        #expect(a.union(.zero) == a)
        #expect(a.union(PixelRect(x: 10, y: 0, width: 1, height: 1)) == PixelRect(x: 1, y: 0, width: 10, height: 6))
    }

    @Test func negativeSizeBecomesEmpty() {
        #expect(PixelRect(x: 0, y: 0, width: -3, height: 2).isEmpty)
    }
}
