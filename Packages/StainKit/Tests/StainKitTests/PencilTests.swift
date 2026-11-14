import CoreGraphics
import Testing

@testable import StainKit

@Suite struct PencilTests {
    @Test func lineIncludesBothEnds() {
        var canvas = Canvas(width: 10, height: 10)
        canvas.drawPixelLine(fromX: 1, y: 1, toX: 6, y: 4, color: .black)
        #expect(canvas.bitmap[1, 1] == .black)
        #expect(canvas.bitmap[6, 4] == .black)
        #expect(canvas.dirtyRect == PixelRect(x: 1, y: 1, width: 6, height: 4))
    }

    @Test func diagonalLineHasOnePixelPerStep() {
        var canvas = Canvas(width: 5, height: 5)
        canvas.drawPixelLine(fromX: 0, y: 0, toX: 4, y: 4, color: .black)
        let black = (0..<5).flatMap { y in (0..<5).map { x in canvas.bitmap[x, y] } }.filter { $0 == .black }
        #expect(black.count == 5)
    }

    @Test func lineIsClippedToImage() {
        var canvas = Canvas(width: 4, height: 4)
        canvas.drawPixelLine(fromX: -5, y: 1, toX: 10, y: 1, color: .black)
        #expect((0..<4).allSatisfy { canvas.bitmap[$0, 1] == .black })
    }

    @Test func secondaryButtonUsesSecondaryColor() {
        var canvas = Canvas(width: 4, height: 4, background: .black)
        var session = ToolSession(tool: PencilTool())
        session.pointerDown(PointerEvent(location: CGPoint(x: 1.5, y: 1.5), button: .secondary), canvas: &canvas)
        _ = session.pointerUp(PointerEvent(location: CGPoint(x: 1.5, y: 1.5), button: .secondary), canvas: &canvas)
        #expect(canvas.bitmap[1, 1] == .white)
    }

    @Test func fastDragLeavesNoGaps() throws {
        var canvas = Canvas(width: 20, height: 3)
        var session = ToolSession(tool: PencilTool())
        session.pointerDown(PointerEvent(location: CGPoint(x: 0, y: 1)), canvas: &canvas)
        session.pointerDragged(PointerEvent(location: CGPoint(x: 19, y: 1)), canvas: &canvas)
        let patch = session.pointerUp(PointerEvent(location: CGPoint(x: 19, y: 1)), canvas: &canvas)
        #expect((0..<20).allSatisfy { canvas.bitmap[$0, 1] == .black })
        #expect(try #require(patch).region == PixelRect(x: 0, y: 1, width: 20, height: 1))
    }
}
