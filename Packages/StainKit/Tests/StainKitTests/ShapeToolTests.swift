import CoreGraphics
import CoreText
import Testing

@testable import StainKit

private func at(
    _ x: Int, _ y: Int, _ button: PointerButton = .primary, _ modifiers: PointerModifiers = [], clicks: Int = 1
) -> PointerEvent {
    PointerEvent(
        location: CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5), button: button, modifiers: modifiers,
        clickCount: clicks, hitTolerance: 1)
}

private func count(_ color: PaintColor, in bitmap: Bitmap, _ rect: PixelRect? = nil) -> Int {
    let area = rect ?? bitmap.bounds
    var total = 0
    for y in area.minY..<area.maxY { for x in area.minX..<area.maxX where bitmap[x, y] == color { total += 1 } }
    return total
}

/// Arrastre completo (pulsar, mover, soltar) con un controlador. Devuelve los parches producidos.
@discardableResult
private func drag(
    _ controller: inout ToolController, _ canvas: inout Canvas, _ points: [PointerEvent],
    make: () -> any Tool
) -> [UndoPatch] {
    var patches: [UndoPatch] = []
    if let patch = controller.pointerDown(points[0], canvas: &canvas, makeTool: make) { patches.append(patch) }
    for point in points.dropFirst() { controller.pointerDragged(point, canvas: &canvas) }
    if let patch = controller.pointerUp(points.last ?? points[0], canvas: &canvas) { patches.append(patch) }
    return patches
}

let red = PaintColor(red: 255, green: 0, blue: 0)

@Suite struct ShapeDrawingTests {
    @Test func rectangleOutlineStaysInsideRect() {
        var canvas = Canvas(width: 12, height: 12)
        canvas.drawShape(
            .rectangle, in: PixelRect(x: 2, y: 2, width: 6, height: 4),
            style: ShapeStyle(outlineColor: .black, fillColor: red))
        #expect(count(.black, in: canvas.bitmap) == 2 * 6 + 2 * 2)
        #expect(canvas.bitmap[2, 2] == .black && canvas.bitmap[7, 5] == .black)
        #expect(canvas.bitmap[4, 3] == .white, "Sin relleno")
        #expect(canvas.bitmap[1, 1] == .white && canvas.bitmap[8, 6] == .white)
    }

    @Test(arguments: ShapeFillMode.allCases)
    func fillModes(mode: ShapeFillMode) {
        var canvas = Canvas(width: 12, height: 12)
        let rect = PixelRect(x: 1, y: 1, width: 10, height: 10)
        canvas.drawShape(.rectangle, in: rect, style: ShapeStyle(fillMode: mode, outlineColor: .black, fillColor: red))
        let inside = canvas.bitmap[5, 5]
        let edge = canvas.bitmap[1, 5]
        switch mode {
        case .outline: #expect(inside == .white && edge == .black)
        case .outlineAndFill: #expect(inside == red && edge == .black)
        case .fill: #expect(inside == .black && edge == .black && count(red, in: canvas.bitmap) == 0)
        }
    }

    @Test func ellipseIsInsideItsBoundingBox() {
        var canvas = Canvas(width: 20, height: 20)
        let rect = PixelRect(x: 2, y: 2, width: 16, height: 10)
        canvas.drawShape(
            .ellipse, in: rect, style: ShapeStyle(fillMode: .fill, outlineColor: .black, fillColor: .black))
        let all = count(.black, in: canvas.bitmap)
        #expect(all > 0 && all == count(.black, in: canvas.bitmap, rect))
        #expect(canvas.bitmap[2, 2] == .white, "Las esquinas quedan fuera de la elipse")
        #expect(canvas.bitmap[10, 7] == .black)
    }

    @Test func fillReplacesRegion() {
        var canvas = Canvas(width: 4, height: 4)
        canvas.fill(PixelRect(x: 1, y: 1, width: 10, height: 10), with: .clear)
        #expect(canvas.bitmap[0, 0] == .white && canvas.bitmap[3, 3] == .clear)
        #expect(canvas.dirtyRect == PixelRect(x: 1, y: 1, width: 3, height: 3))
    }
}

@Suite struct ShapeToolTests {
    let make = { ShapeTool(kind: .rectangle) as any Tool }

    @Test func shapeStaysEditableAfterRelease() {
        var canvas = Canvas(width: 30, height: 30)
        var controller = ToolController()
        let patches = drag(&controller, &canvas, [at(2, 2), at(10, 8)], make: make)
        #expect(patches.isEmpty, "Aún no se ha confirmado")
        #expect(controller.isPending)
        #expect(controller.overlay?.handles.count == 8)
        #expect(canvas.bitmap[2, 2] == .black)
    }

    @Test func dragInsideMovesShape() throws {
        var canvas = Canvas(width: 30, height: 30)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2), at(10, 8)], make: make)
        drag(&controller, &canvas, [at(5, 5), at(15, 15)], make: make)
        #expect(canvas.bitmap[2, 2] == .white, "La posición original se borra")
        #expect(canvas.bitmap[12, 12] == .black)
        let committed = controller.commit(canvas: &canvas)
        let patch = try #require(committed)
        // La región incluye la forma en su nueva posición (más un margen), pero no la original.
        #expect(
            patch.region.intersection(PixelRect(x: 12, y: 12, width: 9, height: 7))
                == PixelRect(x: 12, y: 12, width: 9, height: 7))
        #expect(!patch.region.contains(x: 2, y: 2))
    }

    @Test func handleResizes() {
        var canvas = Canvas(width: 30, height: 30)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2), at(10, 8)], make: make)
        // Tirador inferior derecho: esquina (11, 9) en coordenadas de borde.
        let handle = PointerEvent(location: CGPoint(x: 11, y: 9), hitTolerance: 1)
        _ = controller.pointerDown(handle, canvas: &canvas, makeTool: make)
        controller.pointerDragged(at(20, 20), canvas: &canvas)
        _ = controller.pointerUp(at(20, 20), canvas: &canvas)
        #expect(canvas.bitmap[20, 20] == .black)
        #expect(canvas.bitmap[10, 8] == .white)
    }

    @Test func clickOutsideCommitsAndStartsNewShape() {
        var canvas = Canvas(width: 30, height: 30)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2), at(6, 6)], make: make)
        let patches = drag(&controller, &canvas, [at(20, 20), at(25, 25)], make: make)
        #expect(patches.count == 1, "El primer rectángulo se confirma al hacer clic fuera")
        #expect(canvas.bitmap[2, 2] == .black && canvas.bitmap[20, 20] == .black)
    }

    @Test func shiftMakesSquare() {
        #expect(ShapeTool.constrain((0, 0), (10, 4), square: true) == (10, 10))
        #expect(ShapeTool.constrain((0, 0), (-3, 8), square: true) == (-8, 8))
    }

    @Test func rightButtonSwapsColors() {
        var canvas = Canvas(width: 20, height: 20)
        canvas.primaryColor = red
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2, .secondary), at(10, 10, .secondary)]) {
            ShapeTool(kind: .rectangle, fillMode: .outlineAndFill)
        }
        #expect(canvas.bitmap[2, 2] == .white, "Contorno con el secundario")
        #expect(canvas.bitmap[6, 6] == red, "Relleno con el primario")
    }
}

@Suite struct PolygonToolTests {
    let make = { PolygonTool() as any Tool }

    @Test func doubleClickClosesPolygon() throws {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2), at(15, 2)], make: make)
        #expect(controller.isPending)
        drag(&controller, &canvas, [at(15, 15)], make: make)
        #expect(controller.isPending)
        _ = controller.pointerDown(at(15, 15, clicks: 2), canvas: &canvas, makeTool: make)
        let patch = controller.pointerUp(at(15, 15, clicks: 2), canvas: &canvas)
        #expect(try #require(patch).region.isEmpty == false)
        #expect(!controller.isActive)
        // El lado de cierre (diagonal de (15,15) a (2,2)) existe.
        #expect(canvas.bitmap[8, 8] == .black)
    }

    @Test func clickOnFirstVertexCloses() {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2), at(15, 2)], make: make)
        drag(&controller, &canvas, [at(15, 15)], make: make)
        let patches = drag(&controller, &canvas, [at(2, 2)], make: make)
        #expect(patches.count == 1)
        #expect(!controller.isActive)
    }

    @Test func filledPolygon() {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        let fill = { PolygonTool(fillMode: .fill) as any Tool }
        drag(&controller, &canvas, [at(1, 1), at(18, 1)], make: fill)
        drag(&controller, &canvas, [at(18, 18)], make: fill)
        drag(&controller, &canvas, [at(1, 18)], make: fill)
        _ = controller.commit(canvas: &canvas)
        #expect(canvas.bitmap[10, 10] == .black)
    }
}

@Suite struct CurveToolTests {
    let make = { CurveTool() as any Tool }

    @Test func threeClicksDrawCurve() throws {
        var canvas = Canvas(width: 40, height: 40)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 20)], make: make)
        #expect(controller.isPending, "El primer clic solo fija el inicio")
        #expect(controller.overlay?.handles.count == 1)

        controller.pointerMoved(at(37, 20), canvas: &canvas)
        #expect(canvas.bitmap[20, 20] == .black, "Entre clics, la vista previa sigue al ratón")

        drag(&controller, &canvas, [at(37, 20)], make: make)
        #expect(controller.isPending, "El segundo clic fija el final")
        #expect(canvas.bitmap[20, 20] == .black, "Primero es una línea recta")
        #expect(controller.overlay?.handles.count == 3, "Inicio, punto de control y final")

        controller.pointerMoved(at(20, 2), canvas: &canvas)
        #expect(canvas.bitmap[20, 20] == .white, "Al doblarla, el centro se mueve")

        let patches = drag(&controller, &canvas, [at(20, 2)], make: make)
        #expect(patches.count == 1)
        #expect(!controller.isActive)
        #expect(controller.overlay == nil, "Al terminar no quedan puntos de control")
        #expect(canvas.bitmap[20, 11] == .black, "La curva pasa a media altura del punto de control")
    }

    @Test func dragDrawsStraightLineThenOneClickBends() {
        var canvas = Canvas(width: 40, height: 40)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 20), at(37, 20)], make: make)
        #expect(controller.isPending)
        #expect(canvas.bitmap[20, 20] == .black)
        let patches = drag(&controller, &canvas, [at(20, 2)], make: make)
        #expect(patches.count == 1)
        #expect(canvas.bitmap[20, 20] == .white)
    }

    @Test func committingEarlyKeepsLine() throws {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 10)], make: make)
        drag(&controller, &canvas, [at(17, 10)], make: make)
        let committed = controller.commit(canvas: &canvas)
        let patch = try #require(committed)
        #expect(patch.region.width >= 16)
    }

    @Test func committingWithOnlyStartDrawsNothing() {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 10)], make: make)
        controller.pointerMoved(at(17, 10), canvas: &canvas)
        #expect(controller.commit(canvas: &canvas) == nil)
        #expect(count(.black, in: canvas.bitmap) == 0)
    }
}

@Suite struct AirbrushToolTests {
    @Test func spraysWithinRadius() {
        var canvas = Canvas(width: 41, height: 41)
        var controller = ToolController()
        drag(&controller, &canvas, [at(20, 20)]) { AirbrushTool(radius: 5, density: 30, seed: 1) }
        let painted = count(.black, in: canvas.bitmap)
        #expect(painted > 0 && painted <= 30)
        #expect(painted == count(.black, in: canvas.bitmap, PixelRect(x: 15, y: 15, width: 11, height: 11)))
    }

    @Test func holdingStillKeepsSpraying() {
        var canvas = Canvas(width: 41, height: 41)
        var controller = ToolController()
        _ = controller.pointerDown(at(20, 20), canvas: &canvas) { AirbrushTool(radius: 8, density: 5, seed: 2) }
        #expect(controller.repeatsWhileHeld)
        let before = count(.black, in: canvas.bitmap)
        for _ in 0..<20 { controller.tick(canvas: &canvas) }
        #expect(count(.black, in: canvas.bitmap) > before)
        _ = controller.pointerUp(at(20, 20), canvas: &canvas)
        #expect(!controller.repeatsWhileHeld)
    }

    @Test func sameSeedIsDeterministic() {
        func run() -> Bitmap {
            var canvas = Canvas(width: 21, height: 21)
            var controller = ToolController()
            drag(&controller, &canvas, [at(10, 10)]) { AirbrushTool(radius: 6, seed: 42) }
            return canvas.bitmap
        }
        #expect(run() == run())
    }
}

@Suite struct BombAndControllerTests {
    @Test func bombClearsWithSecondaryAndIsUndoable() throws {
        var canvas = Canvas(width: 8, height: 8, background: red)
        var controller = ToolController()
        let patches = drag(&controller, &canvas, [at(1, 1)]) { BombTool() }
        #expect(count(.white, in: canvas.bitmap) == 64)
        canvas.apply(try #require(patches.first), .undo)
        #expect(count(red, in: canvas.bitmap) == 64)
    }

    @Test func cancelPendingShapeRestoresImage() {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        drag(&controller, &canvas, [at(2, 2), at(10, 10)]) { ShapeTool(kind: .ellipse) }
        controller.cancel(canvas: &canvas)
        #expect(canvas.bitmap == Bitmap(width: 20, height: 20))
        #expect(!controller.isActive)
    }

    @Test func simpleToolsFinishOnPointerUp() {
        var canvas = Canvas(width: 10, height: 10)
        var controller = ToolController()
        let patches = drag(&controller, &canvas, [at(1, 1), at(8, 8)]) { PencilTool() }
        #expect(patches.count == 1)
        #expect(!controller.isActive)
    }
}

@Suite struct TextDrawingTests {
    @Test func drawsGlyphsInsideRect() {
        var canvas = Canvas(width: 120, height: 40)
        let rect = PixelRect(x: 10, y: 5, width: 100, height: 30)
        canvas.drawText("Hola", style: TextStyle(size: 20, color: .black), in: rect)
        var inside = 0
        var outside = 0
        for y in 0..<40 {
            for x in 0..<120 where canvas.bitmap[x, y] != .white {
                if rect.contains(x: x, y: y) { inside += 1 } else { outside += 1 }
            }
        }
        #expect(inside > 30)
        #expect(outside == 0)
    }

    @Test func textStartsAtTopOfRect() {
        var canvas = Canvas(width: 100, height: 100)
        canvas.drawText(
            "M", style: TextStyle(size: 20, color: .black), in: PixelRect(x: 0, y: 0, width: 100, height: 100))
        let topHalf = (0..<50).contains { y in (0..<100).contains { canvas.bitmap[$0, y] != .white } }
        let bottomHalf = (50..<100).contains { y in (0..<100).contains { canvas.bitmap[$0, y] != .white } }
        #expect(topHalf && !bottomHalf, "El texto no debe salir invertido ni abajo")
    }

    @Test func opaqueBackgroundFillsRect() {
        var canvas = Canvas(width: 50, height: 20)
        canvas.drawText("", style: TextStyle(background: red), in: PixelRect(x: 0, y: 0, width: 10, height: 10))
        #expect(count(red, in: canvas.bitmap) == 100)
    }

    @Test func boldFallsBackGracefully() {
        let style = TextStyle(fontName: "Helvetica", size: 12, bold: true, italic: true)
        #expect(CTFontGetSize(style.ctFont) == 12)
    }

    @Test func polygonPresetsFitTheirFrame() {
        for kind in ShapeKind.polygonPresets {
            let vertices = kind.unitVertices ?? []
            #expect(vertices.count >= 3, "\(kind)")
            #expect(vertices.map(\.x).min() == 0 && vertices.map(\.x).max() == 1, "\(kind) ocupa todo el ancho")
            #expect(vertices.map(\.y).min() == 0 && vertices.map(\.y).max() == 1, "\(kind) ocupa todo el alto")
        }
        #expect(ShapeKind.arrowUp.unitVertices?.contains(CGPoint(x: 0.5, y: 0)) == true, "Punta arriba")
        #expect(ShapeKind.arrowLeft.unitVertices?.contains(CGPoint(x: 0, y: 0.5)) == true, "Punta a la izquierda")
    }

    @Test func drawingTriangleFillsOnlyItsHalf() {
        var canvas = Canvas(width: 20, height: 20)
        let style = ShapeStyle(fillMode: .fill, lineWidth: 1, outlineColor: red, fillColor: red)
        canvas.drawShape(.rightTriangle, in: PixelRect(x: 0, y: 0, width: 20, height: 20), style: style)
        #expect(canvas.bitmap[2, 17] == red, "Abajo a la izquierda, dentro")
        #expect(canvas.bitmap[17, 2] == .white, "Arriba a la derecha, fuera")
    }

    // MARK: Clic a clic (sin mantener pulsado)

    @Test func lineWithTwoClicksAndHoverPreview() throws {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        let make = { LineTool() as any Tool }
        drag(&controller, &canvas, [at(2, 2)], make: make)
        #expect(controller.isPending, "Tras el primer clic espera el final")
        controller.pointerMoved(at(17, 2), canvas: &canvas)
        #expect(controller.overlay?.handles.count == 2, "Puntos de control en los dos extremos")
        #expect(canvas.bitmap[10, 2] == .black, "Vista previa horizontal")
        controller.pointerMoved(at(2, 17), canvas: &canvas)
        #expect(canvas.bitmap[10, 2] == .white && canvas.bitmap[2, 10] == .black, "La vista previa sigue al ratón")
        let patches = drag(&controller, &canvas, [at(2, 17)], make: make)
        #expect(patches.count == 1, "Un solo paso de deshacer para toda la línea")
        #expect(!controller.isActive, "El segundo clic termina la línea")
        #expect(controller.overlay == nil, "Al terminar no quedan puntos de control")
        #expect(canvas.bitmap[2, 10] == .black)
    }

    @Test func arrowWithTwoClicksShowsControlPoints() {
        var canvas = Canvas(width: 40, height: 30)
        var controller = ToolController()
        let make = { ArrowTool(lineWidth: 3, antialiased: false) as any Tool }
        drag(&controller, &canvas, [at(5, 15)], make: make)
        #expect(controller.isPending, "Tras el primer clic espera la punta")
        #expect(controller.overlay?.handles.count == 2)
        controller.pointerMoved(at(35, 15), canvas: &canvas)
        #expect(canvas.bitmap[20, 15] == .black, "La vista previa sigue al ratón")
        let patches = drag(&controller, &canvas, [at(35, 15)], make: make)
        #expect(patches.count == 1)
        #expect(!controller.isActive, "El segundo clic termina la flecha")
        #expect(controller.overlay == nil, "Al terminar no quedan puntos de control")
        #expect(canvas.bitmap[20, 15] == .black)
    }

    @Test func polygonByClicksWithHoverAndCommitCloses() {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        let make = { PolygonTool() as any Tool }
        drag(&controller, &canvas, [at(2, 2)], make: make)
        controller.pointerMoved(at(15, 2), canvas: &canvas)
        #expect(canvas.bitmap[8, 2] == .black, "El primer lado sigue al ratón")
        drag(&controller, &canvas, [at(15, 2)], make: make)
        drag(&controller, &canvas, [at(15, 15)], make: make)
        controller.pointerMoved(at(10, 10), canvas: &canvas)
        #expect((controller.tool as? PolygonTool)?.canClose == true)
        #expect(controller.overlay?.handles.count == 4, "Un punto de control por vértice y otro en el ratón")
        // Escape = confirmar: se cierra sin el lado provisional hacia el ratón.
        _ = controller.commit(canvas: &canvas)
        #expect(canvas.bitmap[8, 8] == .black, "Lado de cierre de (15,15) a (2,2)")
        #expect(canvas.bitmap[12, 12] == .black)
    }
}
