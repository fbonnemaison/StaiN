import CoreGraphics
import Testing

@testable import StainKit

/// Herramienta mínima de prueba: pinta el píxel bajo el puntero en cada evento.
struct DotTool: Tool {
    var events: [String] = []

    mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        events.append("begin")
        paint(event, &canvas)
    }

    mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        events.append("drag")
        paint(event, &canvas)
    }

    mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        events.append("end")
    }

    mutating func cancel(on canvas: inout Canvas) {
        events.append("cancel")
    }

    private func paint(_ event: PointerEvent, _ canvas: inout Canvas) {
        let (x, y) = event.pixel
        canvas.setPixel(x: x, y: y, to: canvas.color(for: event.button))
    }
}

func at(_ x: Double, _ y: Double, _ button: PointerButton = .primary) -> PointerEvent {
    PointerEvent(location: CGPoint(x: x, y: y), button: button)
}

@Suite struct CanvasTests {
    @Test func dirtyRectAccumulatesAndResets() {
        var canvas = Canvas(width: 10, height: 10)
        canvas.setPixel(x: 1, y: 1, to: .black)
        canvas.setPixel(x: 4, y: 3, to: .black)
        #expect(canvas.takeDirtyRect() == PixelRect(x: 1, y: 1, width: 4, height: 3))
        #expect(canvas.takeDirtyRect().isEmpty)
    }

    @Test func drawMarksAndClipsRegion() {
        var canvas = Canvas(width: 10, height: 10)
        canvas.draw(in: PixelRect(x: 8, y: 8, width: 5, height: 5), antialiased: false) { context in
            context.setFillColor(PaintColor.black.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        #expect(canvas.dirtyRect == PixelRect(x: 8, y: 8, width: 2, height: 2))
        #expect(canvas.bitmap[7, 7] == .white)
        #expect(canvas.bitmap[9, 9] == .black)
    }

    @Test func outOfBoundsPixelIsIgnored() {
        var canvas = Canvas(width: 2, height: 2)
        canvas.setPixel(x: 5, y: 5, to: .black)
        #expect(canvas.dirtyRect.isEmpty)
    }

    @Test func buttonsMapToPrimaryAndSecondaryColors() {
        var canvas = Canvas(width: 2, height: 2)
        #expect(canvas.color(for: .primary) == .black)
        #expect(canvas.color(for: .secondary) == .white)
        canvas.swapColors()
        #expect(canvas.color(for: .primary) == .white)
    }
}

@Suite struct UndoTests {
    @Test func strokeIsOneUndoStep() {
        var canvas = Canvas(width: 10, height: 10)
        var history = UndoHistory()
        var session = ToolSession(tool: DotTool())

        session.pointerDown(at(1, 1), canvas: &canvas)
        session.pointerDragged(at(2, 1), canvas: &canvas)
        session.pointerDragged(at(3, 1), canvas: &canvas)
        session.pointerUp(at(3, 1), canvas: &canvas, history: &history)

        #expect(session.tool.events == ["begin", "drag", "drag", "end"])
        #expect(history.undoCount == 1)

        let painted = canvas.bitmap
        #expect(history.undo(on: &canvas) == PixelRect(x: 1, y: 1, width: 3, height: 1))
        #expect(canvas.bitmap == Bitmap(width: 10, height: 10))
        #expect(history.canRedo)

        history.redo(on: &canvas)
        #expect(canvas.bitmap == painted)
    }

    @Test func patchOnlyStoresChangedRegion() throws {
        var canvas = Canvas(width: 1000, height: 1000)
        canvas.beginEdit()
        canvas.setPixel(x: 10, y: 10, to: .black)
        let maybePatch = canvas.endEdit()
        let patch = try #require(maybePatch)
        #expect(patch.region == PixelRect(x: 10, y: 10, width: 1, height: 1))
        #expect(patch.byteCount == 8)
    }

    @Test func noChangeProducesNoPatch() {
        var canvas = Canvas(width: 4, height: 4)
        canvas.beginEdit()
        canvas.setPixel(x: 0, y: 0, to: .white)  // ya era blanco
        #expect(canvas.endEdit() == nil)
    }

    @Test func cancelRestoresImage() {
        var canvas = Canvas(width: 4, height: 4)
        var session = ToolSession(tool: DotTool())
        session.pointerDown(at(0, 0), canvas: &canvas)
        session.pointerDragged(at(3, 3), canvas: &canvas)
        session.cancel(canvas: &canvas)
        #expect(session.tool.events.last == "cancel")
        #expect(canvas.bitmap == Bitmap(width: 4, height: 4))
        #expect(!canvas.isEditing)
    }

    @Test func newEditClearsRedo() {
        var canvas = Canvas(width: 4, height: 4)
        var history = UndoHistory()
        var session = ToolSession(tool: DotTool())
        session.pointerDown(at(0, 0), canvas: &canvas)
        session.pointerUp(at(0, 0), canvas: &canvas, history: &history)
        history.undo(on: &canvas)
        session.pointerDown(at(1, 1), canvas: &canvas)
        session.pointerUp(at(1, 1), canvas: &canvas, history: &history)
        #expect(!history.canRedo)
        #expect(history.undoCount == 1)
    }

    @Test func historyDropsOldestBeyondStepLimit() {
        var canvas = Canvas(width: 10, height: 1)
        var history = UndoHistory(maxSteps: 3)
        var session = ToolSession(tool: DotTool())
        for x in 0..<5 {
            session.pointerDown(at(Double(x), 0), canvas: &canvas)
            session.pointerUp(at(Double(x), 0), canvas: &canvas, history: &history)
        }
        #expect(history.undoCount == 3)
        while history.canUndo { history.undo(on: &canvas) }
        // Los dos primeros puntos ya no se pueden deshacer.
        #expect(canvas.bitmap[0, 0] == .black && canvas.bitmap[1, 0] == .black)
        #expect(canvas.bitmap[2, 0] == .white)
    }

    @Test func historyRespectsMemoryLimit() {
        var canvas = Canvas(width: 10, height: 1)
        var history = UndoHistory(maxBytes: 20)  // cada paso de 1 píxel ocupa 8 bytes
        var session = ToolSession(tool: DotTool())
        for x in 0..<5 {
            session.pointerDown(at(Double(x), 0), canvas: &canvas)
            session.pointerUp(at(Double(x), 0), canvas: &canvas, history: &history)
        }
        #expect(history.undoCount == 2)
        #expect(history.byteCount <= 20)
    }

    @Test func floodFillIsUndoable() throws {
        var canvas = Canvas(width: 20, height: 20)
        var history = UndoHistory()
        canvas.beginEdit()
        canvas.floodFill(x: 0, y: 0, with: .black)
        let patch = canvas.endEdit()
        history.record(try #require(patch))
        history.undo(on: &canvas)
        #expect(canvas.bitmap == Bitmap(width: 20, height: 20))
    }
}
