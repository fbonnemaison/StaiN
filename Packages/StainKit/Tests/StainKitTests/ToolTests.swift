import CoreGraphics
import Testing

@testable import StainKit

private func event(
    _ x: Double, _ y: Double, _ button: PointerButton = .primary, _ modifiers: PointerModifiers = []
) -> PointerEvent {
    PointerEvent(location: CGPoint(x: x + 0.5, y: y + 0.5), button: button, modifiers: modifiers)
}

/// Ejecuta un trazo completo y devuelve el parche de deshacer.
@discardableResult
private func stroke<T: Tool>(_ tool: T, on canvas: inout Canvas, _ points: [PointerEvent]) -> UndoPatch? {
    var session = ToolSession(tool: tool)
    session.pointerDown(points[0], canvas: &canvas)
    for point in points.dropFirst() { session.pointerDragged(point, canvas: &canvas) }
    return session.pointerUp(points.last ?? points[0], canvas: &canvas)
}

private func count(_ color: PaintColor, in bitmap: Bitmap) -> Int {
    var total = 0
    for y in 0..<bitmap.height { for x in 0..<bitmap.width where bitmap[x, y] == color { total += 1 } }
    return total
}

@Suite struct BrushMaskTests {
    @Test(arguments: [1, 2, 3, 8])
    func squareCoversWholeBox(size: Int) {
        #expect(BrushMask(shape: .square, size: size).offsets.count == size * size)
    }

    @Test func roundIsSmallerThanSquareButNotEmpty() {
        let round = BrushMask(shape: .round, size: 7).offsets.count
        #expect(round > 25 && round < 49)
        #expect(BrushMask(shape: .round, size: 1).offsets.count == 1)
    }

    @Test func slashesAreDiagonals() {
        let forward = BrushMask(shape: .forwardSlash, size: 3).offsets.map { [$0.dx, $0.dy] }
        #expect(forward == [[-1, 1], [0, 0], [1, -1]])
        let back = BrushMask(shape: .backSlash, size: 3).offsets.map { [$0.dx, $0.dy] }
        #expect(back == [[-1, -1], [0, 0], [1, 1]])
    }
}

@Suite struct BrushToolTests {
    @Test func squareBrushStampIsCentered() {
        var canvas = Canvas(width: 10, height: 10)
        stroke(BrushTool(shape: .square, size: 3), on: &canvas, [event(5, 5)])
        #expect(count(.black, in: canvas.bitmap) == 9)
        #expect(canvas.bitmap[4, 4] == .black && canvas.bitmap[6, 6] == .black)
        #expect(canvas.bitmap[7, 7] == .white)
    }

    @Test func fastStrokeHasNoGaps() {
        var canvas = Canvas(width: 40, height: 10)
        stroke(BrushTool(shape: .square, size: 2), on: &canvas, [event(0, 5), event(39, 5)])
        #expect((0..<40).allSatisfy { canvas.bitmap[$0, 5] == .black })
    }

    @Test func stampNearEdgeIsClipped() throws {
        var canvas = Canvas(width: 4, height: 4)
        let patch = stroke(BrushTool(shape: .square, size: 5), on: &canvas, [event(0, 0)])
        #expect(try #require(patch).region == PixelRect(x: 0, y: 0, width: 3, height: 3))
    }

    @Test func rightButtonUsesSecondaryColor() {
        var canvas = Canvas(width: 5, height: 5, background: .black)
        stroke(BrushTool(size: 1), on: &canvas, [event(2, 2, .secondary)])
        #expect(canvas.bitmap[2, 2] == .white)
    }
}

@Suite struct BrushPressureTests {
    @Test func pressureShrinksBrush() {
        var canvas = Canvas(width: 20, height: 20)
        var light = event(10, 10)
        light.pressure = 0.25
        stroke(BrushTool(shape: .square, size: 8, usesPressure: true), on: &canvas, [light])
        #expect(count(.black, in: canvas.bitmap) == 4, "8 × 0,25 = 2 → 2 × 2 píxeles")
    }

    @Test func pressureIgnoredWhenDisabled() {
        var canvas = Canvas(width: 20, height: 20)
        var light = event(10, 10)
        light.pressure = 0.25
        stroke(BrushTool(shape: .square, size: 4), on: &canvas, [light])
        #expect(count(.black, in: canvas.bitmap) == 16)
    }
}

@Suite struct EraserToolTests {
    @Test func erasesWithSecondaryColorForEitherButton() {
        var canvas = Canvas(width: 10, height: 10, background: .black)
        canvas.secondaryColor = PaintColor(red: 0, green: 255, blue: 0)
        stroke(EraserTool(size: 2), on: &canvas, [event(2, 2)])
        stroke(EraserTool(size: 2), on: &canvas, [event(7, 7, .secondary)])
        #expect(canvas.bitmap[2, 2] == canvas.secondaryColor)
        #expect(canvas.bitmap[7, 7] == canvas.secondaryColor)
        #expect(canvas.primaryColor == .black, "Los colores no deben cambiar")
    }

    @Test func canEraseToTransparent() {
        var canvas = Canvas(width: 10, height: 10, background: .black)
        stroke(EraserTool(size: 4, erasesToTransparent: true), on: &canvas, [event(5, 5)])
        #expect(canvas.bitmap[5, 5] == .clear)
        #expect(count(.clear, in: canvas.bitmap) == 16)
    }
}

@Suite struct FillToolTests {
    @Test func fillsWithButtonColorAndIsUndoable() throws {
        var canvas = Canvas(width: 6, height: 6)
        canvas.primaryColor = PaintColor(red: 255, green: 0, blue: 0)
        let patch = try #require(stroke(FillTool(), on: &canvas, [event(0, 0)]))
        #expect(count(canvas.primaryColor, in: canvas.bitmap) == 36)
        canvas.apply(patch, .undo)
        #expect(canvas.bitmap == Bitmap(width: 6, height: 6))
    }

    @Test func toleranceIsPassedThrough() {
        var canvas = Canvas(width: 2, height: 1)
        canvas.setPixel(x: 1, y: 0, to: PaintColor(red: 250, green: 250, blue: 250))
        stroke(FillTool(tolerance: 10), on: &canvas, [event(0, 0)])
        #expect(canvas.bitmap[1, 0] == .black)
    }
}

@Suite struct EyedropperToolTests {
    let red = PaintColor(red: 255, green: 0, blue: 0)
    let blue = PaintColor(red: 0, green: 0, blue: 255)

    @Test func picksIntoPrimaryOrSecondary() {
        var canvas = Canvas(width: 4, height: 1)
        canvas.setPixel(x: 1, y: 0, to: red)
        canvas.setPixel(x: 2, y: 0, to: blue)
        let patch = stroke(EyedropperTool(), on: &canvas, [event(1, 0)])
        stroke(EyedropperTool(), on: &canvas, [event(2, 0, .secondary)])
        #expect(canvas.primaryColor == red)
        #expect(canvas.secondaryColor == blue)
        #expect(patch == nil, "Tomar un color no modifica la imagen")
    }

    @Test func outsideImageKeepsColor() {
        var canvas = Canvas(width: 2, height: 2)
        stroke(EyedropperTool(), on: &canvas, [event(10, 10)])
        #expect(canvas.primaryColor == .black)
    }
}

@Suite struct LineToolTests {
    @Test func previewIsReplacedWhileDragging() {
        var canvas = Canvas(width: 20, height: 20)
        stroke(LineTool(), on: &canvas, [event(0, 0), event(19, 0), event(0, 19)])
        // Solo queda la línea final (vertical), no la previa horizontal.
        #expect((0..<20).allSatisfy { canvas.bitmap[0, $0] == .black })
        #expect(canvas.bitmap[19, 0] == .white)
        #expect(count(.black, in: canvas.bitmap) == 20)
    }

    @Test func widthUsesRoundMask() {
        var canvas = Canvas(width: 20, height: 9)
        stroke(LineTool(width: 3), on: &canvas, [event(2, 4), event(17, 4)])
        #expect(canvas.bitmap[10, 3] == .black && canvas.bitmap[10, 4] == .black && canvas.bitmap[10, 5] == .black)
        #expect(canvas.bitmap[10, 2] == .white && canvas.bitmap[10, 6] == .white)
    }

    @Test func cancelLeavesImageUntouched() {
        var canvas = Canvas(width: 10, height: 10)
        var session = ToolSession(tool: LineTool())
        session.pointerDown(event(0, 0), canvas: &canvas)
        session.pointerDragged(event(9, 9), canvas: &canvas)
        session.cancel(canvas: &canvas)
        #expect(canvas.bitmap == Bitmap(width: 10, height: 10))
    }

    @Test(arguments: [
        ((10, 2), (10, 0)),  // casi horizontal → horizontal
        ((2, 10), (0, 10)),  // casi vertical → vertical
        ((9, 7), (9, 9)),  // diagonal ↘
        ((-6, 8), (-8, 8)),  // diagonal ↙
    ])
    func shiftSnapsTo45Degrees(input: (Int, Int), expected: (Int, Int)) {
        let end = LineTool.endpoint(from: (0, 0), to: (input.0, input.1), constrained: true)
        #expect(end.x == expected.0 && end.y == expected.1)
    }

    @Test func shiftDragDrawsStraightLine() {
        var canvas = Canvas(width: 20, height: 20)
        stroke(LineTool(), on: &canvas, [event(0, 5), event(15, 7, .primary, .shift)])
        #expect((0...15).allSatisfy { canvas.bitmap[$0, 5] == .black })
        #expect(canvas.bitmap[15, 7] == .white)
    }
}
