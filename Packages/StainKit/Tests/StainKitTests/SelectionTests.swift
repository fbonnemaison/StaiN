import CoreGraphics
import Testing

@testable import StainKit

private func at(_ x: Int, _ y: Int, _ modifiers: PointerModifiers = []) -> PointerEvent {
    PointerEvent(location: CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5), modifiers: modifiers)
}

@discardableResult
private func drag(_ c: inout ToolController, _ canvas: inout Canvas, _ points: [PointerEvent], make: () -> any Tool)
    -> [UndoPatch]
{
    var patches: [UndoPatch] = []
    if let p = c.pointerDown(points[0], canvas: &canvas, makeTool: make) { patches.append(p) }
    for p in points.dropFirst() { c.pointerDragged(p, canvas: &canvas) }
    if let p = c.pointerUp(points.last ?? points[0], canvas: &canvas) { patches.append(p) }
    return patches
}

private func rect() -> any Tool { SelectionTool(mode: .rectangle) }

/// Lienzo blanco 20×20 con un cuadrado rojo 4×4 en (2, 2).
private func canvasWithSquare() -> Canvas {
    var canvas = Canvas(width: 20, height: 20)
    canvas.fill(PixelRect(x: 2, y: 2, width: 4, height: 4), with: red)
    _ = canvas.takeDirtyRect()
    return canvas
}

private func selection(_ c: ToolController) -> SelectionTool? { c.tool as? SelectionTool }

@Suite struct SelectionTests {
    @Test func selectingDoesNotChangeImage() {
        var canvas = canvasWithSquare()
        let before = canvas.bitmap
        var c = ToolController()
        drag(&c, &canvas, [at(1, 1), at(6, 6)], make: rect)
        #expect(c.isPending)
        #expect(selection(c)?.bounds == PixelRect(x: 1, y: 1, width: 6, height: 6))
        #expect(c.overlay?.isMarchingAnts == true)
        #expect(canvas.bitmap == before)
        #expect(c.commit(canvas: &canvas) == nil, "Seleccionar sin mover no genera paso de deshacer")
    }

    @Test func clickWithoutDragSelectsNothing() {
        var canvas = canvasWithSquare()
        var c = ToolController()
        let patches = drag(&c, &canvas, [at(3, 3)], make: rect)
        #expect(patches.isEmpty)
        #expect(!c.isActive)
    }

    @Test func movingLeavesSecondaryColorHole() throws {
        var canvas = canvasWithSquare()
        canvas.secondaryColor = PaintColor(red: 0, green: 0, blue: 255)
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(5, 5)], make: rect)
        drag(&c, &canvas, [at(3, 3), at(13, 3)], make: rect)
        #expect(canvas.bitmap[12, 2] == red && canvas.bitmap[15, 5] == red)
        #expect(canvas.bitmap[2, 2] == canvas.secondaryColor, "El hueco se rellena con el secundario")
        let committed = c.commit(canvas: &canvas)
        let patch = try #require(committed)
        canvas.apply(patch, .undo)
        #expect(canvas.bitmap == canvasWithSquare().bitmap)
    }

    @Test func optionDragDuplicates() {
        var canvas = canvasWithSquare()
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(5, 5)], make: rect)
        drag(&c, &canvas, [at(3, 3, .option), at(13, 3, .option)], make: rect)
        #expect(canvas.bitmap[2, 2] == red, "El original se queda")
        #expect(canvas.bitmap[12, 2] == red)
    }

    @Test func optionDragAgainStampsCopies() {
        var canvas = canvasWithSquare()
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(5, 5)], make: rect)
        drag(&c, &canvas, [at(3, 3), at(9, 3)], make: rect)  // mover a x=8
        drag(&c, &canvas, [at(9, 3, .option), at(15, 3, .option)], make: rect)  // copia en x=14
        #expect(canvas.bitmap[8, 2] == red && canvas.bitmap[14, 2] == red)
        #expect(canvas.bitmap[2, 2] == .white)
    }

    @Test func clickOutsideCommits() {
        var canvas = canvasWithSquare()
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(5, 5)], make: rect)
        drag(&c, &canvas, [at(3, 3), at(10, 10)], make: rect)
        let patches = drag(&c, &canvas, [at(0, 19)], make: rect)
        #expect(patches.count == 1)
        #expect(!c.isActive)
    }

    @Test func transparentSelectionSkipsSecondaryColor() {
        var canvas = Canvas(width: 20, height: 20, background: .black)
        canvas.fill(PixelRect(x: 2, y: 2, width: 2, height: 2), with: .white)  // blanco = secundario
        canvas.setPixel(x: 3, y: 3, to: red)
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(3, 3)]) { SelectionTool(mode: .rectangle, isTransparent: true) }
        drag(&c, &canvas, [at(2, 2), at(10, 10)], make: rect)
        #expect(canvas.bitmap[11, 11] == red)
        #expect(canvas.bitmap[10, 10] == .black, "El blanco no se pega: se ve el fondo")
    }

    @Test func nudgeMovesByPixels() {
        var canvas = canvasWithSquare()
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(5, 5)], make: rect)
        c.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in tool.nudge(dx: 1, dy: 0, on: &canvas) }
        #expect(canvas.bitmap[6, 2] == red && canvas.bitmap[2, 2] == .white)
    }

    @Test func rotateSelectionContent() {
        var canvas = Canvas(width: 10, height: 10)
        canvas.fill(PixelRect(x: 0, y: 0, width: 4, height: 1), with: red)
        var c = ToolController()
        drag(&c, &canvas, [at(0, 0), at(3, 0)], make: rect)
        c.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in
            tool.transform(on: &canvas) { $0.rotated(quarterTurns: 1) }
        }
        #expect(selection(c)?.bounds == PixelRect(x: 0, y: 0, width: 1, height: 4))
        #expect(canvas.bitmap[0, 3] == red && canvas.bitmap[3, 0] == .white)
    }

    @Test func deleteFillsWithSecondary() throws {
        var canvas = canvasWithSquare()
        var c = ToolController()
        drag(&c, &canvas, [at(2, 2), at(5, 5)], make: rect)
        c.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in tool.deleteSelection(on: &canvas) }
        let committed = c.commit(canvas: &canvas)
        _ = try #require(committed)
        #expect(canvas.bitmap == Bitmap(width: 20, height: 20))
    }

    @Test func selectedPixelsForCopy() throws {
        var canvas = canvasWithSquare()
        var c = ToolController()
        drag(&c, &canvas, [at(1, 1), at(6, 6)], make: rect)
        let copied = try #require(selection(c)?.selectedPixels(in: canvas))
        #expect(copied.width == 6 && copied[1, 1] == red && copied[0, 0] == .white)
    }

    @Test func pasteFloatsWithoutHole() throws {
        var canvas = Canvas(width: 20, height: 20)
        var c = ToolController()
        _ = c.install(
            SelectionTool(pasting: Bitmap(width: 3, height: 3, fill: red), atX: 0, y: 0, background: .white),
            canvas: &canvas)
        c.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in tool.nudge(dx: 0, dy: 0, on: &canvas) }
        #expect(canvas.bitmap[2, 2] == red)
        drag(&c, &canvas, [at(1, 1), at(11, 1)], make: rect)
        #expect(canvas.bitmap[0, 0] == .white && canvas.bitmap[10, 0] == red)
        let committed = c.commit(canvas: &canvas)
        #expect(committed != nil)
    }

    @Test func lassoSelectsOnlyInsideShape() throws {
        var canvas = Canvas(width: 20, height: 20, background: red)
        var c = ToolController()
        // Triángulo con el ángulo recto arriba a la izquierda.
        drag(&c, &canvas, [at(0, 0), at(10, 0), at(0, 10), at(0, 1)]) { SelectionTool(mode: .freeForm) }
        let tool = try #require(selection(c))
        #expect(tool.hasSelection)
        let pixels = try #require(tool.selectedPixels(in: canvas))
        #expect(pixels[1, 1] == red)
        #expect(pixels[9, 9] == .clear, "Fuera del triángulo")
        // Al moverlo, el hueco solo tiene forma de triángulo.
        drag(&c, &canvas, [at(1, 1), at(11, 11)], make: rect)
        #expect(canvas.bitmap[1, 1] == .white)
        #expect(canvas.bitmap[9, 9] == red, "Fuera del lazo no se toca")
    }
}
