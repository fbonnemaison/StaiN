import Testing

@testable import StainKit

@Suite struct TransformTests {
    let r = PaintColor(red: 255, green: 0, blue: 0)
    let g = PaintColor(red: 0, green: 255, blue: 0)
    let b = PaintColor(red: 0, green: 0, blue: 255)

    /// 3 × 2:  r g b
    ///         w w k
    func sample() -> Bitmap {
        var bitmap = Bitmap(width: 3, height: 2)
        bitmap[0, 0] = r
        bitmap[1, 0] = g
        bitmap[2, 0] = b
        bitmap[2, 1] = .black
        return bitmap
    }

    @Test func flipHorizontal() {
        let f = sample().flippedHorizontally()
        #expect(f[0, 0] == b && f[2, 0] == r && f[0, 1] == .black)
    }

    @Test func flipVertical() {
        let f = sample().flippedVertically()
        #expect(f[0, 1] == r && f[2, 0] == .black)
    }

    @Test func rotateClockwise() {
        let rot = sample().rotated(quarterTurns: 1)
        #expect(rot.width == 2 && rot.height == 3)
        // La fila de arriba (r g b) pasa a ser la columna derecha, de arriba abajo.
        #expect(rot[1, 0] == r && rot[1, 1] == g && rot[1, 2] == b)
        #expect(rot[0, 2] == .black)
    }

    @Test func rotateCounterClockwise() {
        let rot = sample().rotated(quarterTurns: -1)
        #expect(rot.width == 2 && rot.height == 3)
        #expect(rot[0, 2] == r && rot[0, 0] == b && rot[1, 0] == .black)
    }

    @Test func fourQuarterTurnsAreIdentity() {
        let s = sample()
        #expect(
            s.rotated(quarterTurns: 1).rotated(quarterTurns: 1).rotated(quarterTurns: 1).rotated(quarterTurns: 1) == s)
        #expect(s.rotated(quarterTurns: 2) == s.flippedHorizontally().flippedVertically())
    }

    @Test func invertKeepsAlpha() {
        var bitmap = Bitmap(width: 2, height: 1, fill: .clear)
        bitmap[0, 0] = r
        let inv = bitmap.inverted()
        #expect(inv[0, 0] == PaintColor(red: 0, green: 255, blue: 255))
        #expect(inv[1, 0] == .clear)
        #expect(inv.inverted() == bitmap)
    }

    @Test func nearestNeighborResizeKeepsColors() {
        let big = sample().resized(width: 6, height: 4, smooth: false)
        #expect(big.width == 6 && big.height == 4)
        #expect(big[0, 0] == r && big[1, 1] == r && big[2, 0] == g && big[5, 3] == .black)
        #expect(big.resized(width: 3, height: 2, smooth: false) == sample())
    }

    @Test func smoothResizeChangesSize() {
        let small = Bitmap(width: 100, height: 50, fill: r).resized(width: 10, height: 5, smooth: true)
        #expect(small.width == 10 && small.height == 5)
        #expect(small[5, 2] == r)
    }

    @Test func skewGrowsCanvasAndFillsBackground() {
        let source = Bitmap(width: 10, height: 10, fill: .black)
        let skewed = source.skewed(horizontalDegrees: 45, verticalDegrees: 0, background: .white)
        #expect(skewed.width == 20 && skewed.height == 10)
        #expect(skewed[0, 0] == .black, "Arriba la imagen empieza a la izquierda")
        #expect(skewed[19, 0] == .white)
        #expect(skewed[19, 9] == .black, "Abajo se ha desplazado a la derecha")
        #expect(skewed[0, 9] == .white)
    }

    @Test func zeroSkewIsIdentity() {
        #expect(sample().skewed(horizontalDegrees: 0, verticalDegrees: 0, background: .white) == sample())
    }

    @Test(arguments: [
        (CanvasAnchor.topLeft, 0, 0), (.center, 1, 1), (.bottomRight, 2, 2), (.top, 1, 0), (.left, 0, 1),
    ])
    func canvasSizeAnchors(anchor: CanvasAnchor, x: Int, y: Int) {
        let source = Bitmap(width: 1, height: 1, fill: .black)
        let bigger = source.resizedCanvas(width: 3, height: 3, anchor: anchor, fill: .white)
        #expect(bigger[x, y] == .black)
        var blacks = 0
        for py in 0..<3 { for px in 0..<3 where bigger[px, py] == .black { blacks += 1 } }
        #expect(blacks == 1)
    }

    @Test func shrinkingCanvasCrops() {
        let smaller = sample().resizedCanvas(width: 2, height: 1, anchor: .topRight, fill: .white)
        #expect(smaller[0, 0] == g && smaller[1, 0] == b)
    }
}
