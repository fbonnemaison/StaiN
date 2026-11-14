import Testing

@testable import StainKit

@Suite struct FloodFillTests {
    let red = PaintColor(red: 255, green: 0, blue: 0)

    /// Bitmap 5×5 blanco con una pared vertical negra en x = 2.
    func walled() -> Bitmap {
        var bitmap = Bitmap(width: 5, height: 5)
        for y in 0..<5 { bitmap[2, y] = .black }
        return bitmap
    }

    @Test func fillsOnlyConnectedRegion() {
        var bitmap = walled()
        let changed = bitmap.floodFill(x: 0, y: 0, with: red)
        #expect(changed == PixelRect(x: 0, y: 0, width: 2, height: 5))
        for y in 0..<5 {
            #expect(bitmap[0, y] == red && bitmap[1, y] == red)
            #expect(bitmap[2, y] == .black)
            #expect(bitmap[3, y] == .white && bitmap[4, y] == .white)
        }
    }

    @Test func doesNotLeakThroughDiagonals() {
        var bitmap = Bitmap(width: 3, height: 3)
        bitmap[1, 0] = .black
        bitmap[0, 1] = .black
        bitmap.floodFill(x: 0, y: 0, with: red)
        #expect(bitmap[0, 0] == red)
        #expect(bitmap[1, 1] == .white)
    }

    @Test func fillsConcaveShape() {
        // Forma de U: el relleno tiene que bajar, girar y volver a subir.
        var bitmap = Bitmap(width: 5, height: 4)
        for y in 0..<3 { bitmap[1, y] = .black; bitmap[3, y] = .black }
        bitmap.floodFill(x: 0, y: 0, with: red)
        #expect(bitmap[4, 0] == red)
        #expect(bitmap[2, 0] == red)
        #expect(bitmap[2, 3] == red)
    }

    @Test func sameColorIsNoOp() {
        var bitmap = walled()
        let before = bitmap
        #expect(bitmap.floodFill(x: 0, y: 0, with: .white).isEmpty)
        #expect(bitmap == before)
    }

    @Test func outOfBoundsIsNoOp() {
        var bitmap = walled()
        #expect(bitmap.floodFill(x: -1, y: 0, with: red).isEmpty)
    }

    @Test func toleranceIncludesSimilarColors() {
        var bitmap = Bitmap(width: 3, height: 1)
        bitmap[1, 0] = PaintColor(red: 250, green: 250, blue: 250)
        bitmap[2, 0] = PaintColor(red: 200, green: 200, blue: 200)

        var exact = bitmap
        exact.floodFill(x: 0, y: 0, with: red)
        #expect(exact[1, 0] != red)

        var loose = bitmap
        loose.floodFill(x: 0, y: 0, with: red, tolerance: 10)
        #expect(loose[1, 0] == red)
        #expect(loose[2, 0] != red)
    }

    @Test func toleranceWithSimilarFillTerminates() {
        var bitmap = Bitmap(width: 50, height: 50)
        bitmap.floodFill(x: 25, y: 25, with: PaintColor(red: 254, green: 254, blue: 254), tolerance: 5)
        #expect(bitmap[0, 0] == PaintColor(red: 254, green: 254, blue: 254))
    }

    @Test func largeFillDoesNotOverflowStack() {
        var bitmap = Bitmap(width: 1000, height: 1000)
        let changed = bitmap.floodFill(x: 500, y: 500, with: red)
        #expect(changed == bitmap.bounds)
        #expect(bitmap[999, 999] == red)
    }
}
