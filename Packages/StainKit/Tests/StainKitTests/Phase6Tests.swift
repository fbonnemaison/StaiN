import CoreGraphics
import Testing

@testable import StainKit

private func at(_ x: Int, _ y: Int, _ button: PointerButton = .primary) -> PointerEvent {
    PointerEvent(location: CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5), button: button)
}

@discardableResult
private func stroke(_ canvas: inout Canvas, _ points: [PointerEvent], make: () -> any Tool) -> UndoPatch? {
    var controller = ToolController()
    _ = controller.pointerDown(points[0], canvas: &canvas, makeTool: make)
    points.dropFirst().forEach { controller.pointerDragged($0, canvas: &canvas) }
    return controller.pointerUp(points.last ?? points[0], canvas: &canvas)
}

private func close(_ a: PaintColor, _ b: PaintColor, _ tolerance: Int = 3) -> Bool {
    abs(Int(a.red) - Int(b.red)) <= tolerance && abs(Int(a.green) - Int(b.green)) <= tolerance
        && abs(Int(a.blue) - Int(b.blue)) <= tolerance && abs(Int(a.alpha) - Int(b.alpha)) <= tolerance
}

@Suite struct FilterTests {
    @Test func grayscaleEqualizesChannels() {
        let result = ImageFilter.grayscale.apply(
            to: Bitmap(width: 4, height: 4, fill: PaintColor(red: 200, green: 50, blue: 90)))
        let p = result[2, 2]
        #expect(abs(Int(p.red) - Int(p.green)) <= 2 && abs(Int(p.green) - Int(p.blue)) <= 2)
    }

    @Test func identityColorControlsKeepsColor() {
        let color = PaintColor(red: 120, green: 80, blue: 200)
        let result = ImageFilter.colorControls(brightness: 0, contrast: 1, saturation: 1)
            .apply(to: Bitmap(width: 4, height: 4, fill: color))
        #expect(close(result[1, 1], color))
    }

    @Test func brightnessMakesLighter() {
        let result = ImageFilter.colorControls(brightness: 0.3, contrast: 1, saturation: 1)
            .apply(to: Bitmap(width: 2, height: 2, fill: PaintColor(red: 100, green: 100, blue: 100)))
        #expect(result[0, 0].red > 130)
    }

    @Test func blurSoftensEdgeButKeepsSize() {
        var bitmap = Bitmap(width: 20, height: 20)
        for y in 0..<20 { for x in 0..<10 { bitmap[x, y] = .black } }
        let result = ImageFilter.blur(radius: 3).apply(to: bitmap)
        #expect(result.width == 20 && result.height == 20)
        #expect(result[10, 10].red > 0 && result[10, 10].red < 255, "El borde queda gris")
        #expect(result[0, 0].alpha == 255, "Los bordes no se vuelven transparentes")
    }

    @Test func sepiaTintsGray() {
        let result = ImageFilter.sepia(intensity: 1).apply(
            to: Bitmap(width: 2, height: 2, fill: PaintColor(red: 128, green: 128, blue: 128)))
        #expect(result[0, 0].red > result[0, 0].blue)
    }

    @Test func pixelateAveragesBlocks() {
        var bitmap = Bitmap(width: 4, height: 2)
        bitmap[0, 0] = .black
        bitmap[1, 1] = .black  // bloque 2×2 izquierdo: mitad negro, mitad blanco
        let result = bitmap.pixelated(blockSize: 2)
        #expect(result[0, 0] == result[1, 1] && result[0, 0] == result[1, 0])
        #expect(close(result[0, 0], PaintColor(red: 128, green: 128, blue: 128), 1))
        #expect(result[2, 0] == .white)
    }

    @Test func thresholdLeavesOnlyBlackAndWhite() {
        var bitmap = Bitmap(width: 3, height: 1)
        bitmap[0, 0] = PaintColor(red: 30, green: 30, blue: 30)
        bitmap[1, 0] = PaintColor(red: 220, green: 220, blue: 220)
        bitmap[2, 0] = .clear
        let result = bitmap.thresholded(level: 0.5)
        #expect(result[0, 0] == .black && result[1, 0] == .white && result[2, 0] == .clear)
    }

    @Test func posterizeReducesColors() {
        var bitmap = Bitmap(width: 64, height: 1)
        for x in 0..<64 { bitmap[x, 0] = PaintColor(red: UInt8(x * 4), green: UInt8(x * 4), blue: UInt8(x * 4)) }
        let result = ImageFilter.posterize(levels: 2).apply(to: bitmap)
        let distinct = Set((0..<64).map { result[$0, 0].red })
        #expect(distinct.count <= 4)
    }
}

@Suite struct AnnotationToolTests {
    @Test func arrowDrawsShaftAndHead() {
        var canvas = Canvas(width: 60, height: 30)
        canvas.primaryColor = red
        stroke(&canvas, [at(5, 15), at(50, 15)]) { ArrowTool(lineWidth: 3, antialiased: false) }
        #expect(canvas.bitmap[20, 15] == red, "Cuerpo de la flecha")
        #expect(canvas.bitmap[42, 12] == red, "La punta es más ancha que el cuerpo")
        #expect(canvas.bitmap[20, 11] == .white)
    }

    @Test func highlighterIsTranslucentAndDoesNotAccumulate() {
        var canvas = Canvas(width: 40, height: 40)
        canvas.primaryColor = PaintColor(red: 255, green: 255, blue: 0)
        // Trazo que pasa dos veces por el mismo sitio.
        stroke(&canvas, [at(5, 20), at(35, 20), at(5, 20)]) { HighlighterTool(size: 8, antialiased: false) }
        let pixel = canvas.bitmap[20, 20]
        #expect(pixel.blue < 255 && pixel.blue > 60, "Amarillo translúcido sobre blanco: \(pixel)")
        let other = canvas.bitmap[10, 20]
        #expect(pixel == other, "Donde el trazo se cruza no se oscurece más")
    }

    @Test(arguments: RedactTool.Mode.allCases)
    func redactionChangesOnlyTheRegion(mode: RedactTool.Mode) {
        var canvas = Canvas(width: 40, height: 40)
        for x in stride(from: 10, to: 30, by: 2) { canvas.drawPixelLine(fromX: x, y: 10, toX: x, y: 29, color: .black) }
        let before = canvas.bitmap
        let patch = stroke(&canvas, [at(10, 10), at(29, 29)]) { RedactTool(mode: mode) }
        #expect(patch != nil)
        #expect(canvas.bitmap != before)
        #expect(canvas.bitmap[5, 5] == .white && canvas.bitmap[35, 35] == .white, "Fuera de la zona no cambia")
        if mode == .block { #expect(canvas.bitmap[15, 15] == .black && canvas.bitmap[11, 11] == .black) }
    }

    @Test func redactionShowsOutlineWhileDragging() {
        var canvas = Canvas(width: 20, height: 20)
        var controller = ToolController()
        _ = controller.pointerDown(at(2, 2), canvas: &canvas) { RedactTool() }
        controller.pointerDragged(at(10, 10), canvas: &canvas)
        #expect(controller.overlay?.outline.count == 4)
        #expect(canvas.bitmap == Bitmap(width: 20, height: 20), "No se aplica hasta soltar")
    }

    @Test func stepMarkerDrawsCircleWithNumber() {
        var canvas = Canvas(width: 40, height: 40)
        canvas.primaryColor = red
        stroke(&canvas, [at(20, 20)]) { StepMarkerTool(number: 7, radius: 12, antialiased: false) }
        #expect(canvas.bitmap[20, 9] == red, "Borde superior del círculo")
        #expect(canvas.bitmap[20, 5] == .white, "Fuera del círculo")
        var whiteInside = 0
        for y in 14..<27 { for x in 14..<27 where canvas.bitmap[x, y] == .white { whiteInside += 1 } }
        #expect(whiteInside > 5, "El número se ve en blanco sobre rojo")
    }
}

@Suite struct SymmetryTests {
    @Test func horizontalMirrorsAcrossCenter() {
        var canvas = Canvas(width: 10, height: 10)
        stroke(&canvas, [at(1, 3)]) {
            MirroredTool(symmetry: .horizontal, canvasWidth: 10, canvasHeight: 10) { PencilTool() }
        }
        #expect(canvas.bitmap[1, 3] == .black && canvas.bitmap[8, 3] == .black)
        #expect(canvas.bitmap[1, 6] == .white)
    }

    @Test func bothAxesMakeFourCopies() {
        var canvas = Canvas(width: 10, height: 10)
        stroke(&canvas, [at(1, 2)]) {
            MirroredTool(symmetry: [.horizontal, .vertical], canvasWidth: 10, canvasHeight: 10) { PencilTool() }
        }
        #expect(canvas.bitmap[1, 2] == .black && canvas.bitmap[8, 2] == .black)
        #expect(canvas.bitmap[1, 7] == .black && canvas.bitmap[8, 7] == .black)
    }

    @Test func mirroredStrokeIsOneUndoStep() throws {
        var canvas = Canvas(width: 20, height: 10)
        let patch = try #require(
            stroke(&canvas, [at(1, 1), at(5, 5)]) {
                MirroredTool(symmetry: .horizontal, canvasWidth: 20, canvasHeight: 10) { BrushTool(size: 2) }
            })
        canvas.apply(patch, .undo)
        #expect(canvas.bitmap == Bitmap(width: 20, height: 10))
    }
}

@Suite struct PaletteFileTests {
    let colors = [PaintColor(red: 255, green: 0, blue: 0), PaintColor(red: 1, green: 2, blue: 3)]

    @Test func gplRoundTrip() {
        let text = PaletteFile.gpl(name: "Prueba", colors: colors)
        #expect(text.hasPrefix("GIMP Palette"))
        #expect(PaletteFile.parse(text) == colors)
    }

    @Test func hexRoundTrip() {
        #expect(PaletteFile.hex(colors: colors) == "ff0000\n010203\n")
        #expect(PaletteFile.parse("ff0000\n#010203\n; comentario\n\nnada") == colors)
    }

    @Test func gplIgnoresHeaderAndComments() {
        let text = "GIMP Palette\nName: Algo\nColumns: 4\n# comentario\n  0 128 255 Azul\n300 0 0 malo\n"
        #expect(PaletteFile.parse(text) == [PaintColor(red: 0, green: 128, blue: 255)])
    }
}
