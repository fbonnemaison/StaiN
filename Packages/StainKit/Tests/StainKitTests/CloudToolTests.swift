import CoreGraphics
import Testing

@testable import StainKit

private func at(_ x: Int, _ y: Int, clicks: Int = 1) -> PointerEvent {
    PointerEvent(location: CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5), clickCount: clicks, hitTolerance: 1)
}

private func click(_ controller: inout ToolController, _ canvas: inout Canvas, _ event: PointerEvent, make: () -> any Tool)
    -> UndoPatch?
{
    let first = controller.pointerDown(event, canvas: &canvas, makeTool: make)
    let second = controller.pointerUp(event, canvas: &canvas)
    return first ?? second
}

private func blackPixels(_ bitmap: Bitmap) -> [(x: Int, y: Int)] {
    var result: [(x: Int, y: Int)] = []
    for y in 0..<bitmap.height { for x in 0..<bitmap.width where bitmap[x, y] == .black { result.append((x, y)) } }
    return result
}

/// Puntos del trazado aplanado (los extremos de cada segmento y de cada curva).
private func samples(_ path: CGPath) -> [CGPoint] {
    var points: [CGPoint] = []
    path.applyWithBlock { element in
        let e = element.pointee
        switch e.type {
        case .moveToPoint, .addLineToPoint: points.append(e.points[0])
        case .addQuadCurveToPoint: points.append(e.points[1])
        case .addCurveToPoint: points.append(e.points[1]); points.append(e.points[2])
        default: break
        }
    }
    return points
}

@Suite struct CloudPathTests {
    let square = [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 10), CGPoint(x: 50, y: 50), CGPoint(x: 10, y: 50)]

    @Test func arcsFitEachSide() {
        #expect(CloudPath.arcCount(length: 40, chord: 10) == 4)
        #expect(CloudPath.arcCount(length: 44, chord: 10) == 4)
        #expect(CloudPath.arcCount(length: 3, chord: 10) == 1, "Un lado corto tiene al menos un arco")
    }

    @Test(arguments: [false, true])
    func arcsBulgeOutward(reversed: Bool) {
        // Da igual el sentido en que se dibujen los vértices: los arcos van siempre hacia fuera.
        let vertices = reversed ? square.reversed() : square
        let path = CloudPath.make(vertices: vertices, closed: true, chord: 10, seed: 1, jitter: 0)
        let inner = CGRect(x: 10.5, y: 10.5, width: 39, height: 39)
        for point in samples(path) {
            #expect(!inner.contains(point), "\(point) está dentro del polígono")
        }
        // Abomban: alguna parte sale claramente del cuadrado.
        let box = path.boundingBoxOfPath
        #expect(box.minX < 8 && box.maxX > 52 && box.minY < 8 && box.maxY > 52)
        #expect(box.minX > 0 && box.maxX < 60, "Pero no más que un radio de arco")
    }

    @Test func sameSeedSamePath() {
        let a = CloudPath.make(vertices: square, closed: true, chord: 10, seed: 42)
        let b = CloudPath.make(vertices: square, closed: true, chord: 10, seed: 42)
        let c = CloudPath.make(vertices: square, closed: true, chord: 10, seed: 43)
        #expect(a == b)
        #expect(a != c, "El estilo boceto varía con la semilla")
    }

    @Test func sketchJitterIsSmall() {
        let regular = CloudPath.make(vertices: square, closed: true, chord: 10, seed: 7, jitter: 0).boundingBoxOfPath
        let sketch = CloudPath.make(vertices: square, closed: true, chord: 10, seed: 7).boundingBoxOfPath
        #expect(abs(regular.width - sketch.width) < 6)
        #expect(abs(regular.height - sketch.height) < 6)
    }

    @Test func previewIsStableWhenAddingSides() {
        // Los arcos de un lado no cambian al añadir el siguiente (la vista previa no tiembla).
        let two = CloudPath.make(vertices: Array(square.prefix(2)), closed: false, chord: 10, seed: 5)
        let three = CloudPath.make(vertices: Array(square.prefix(3)), closed: false, chord: 10, seed: 5)
        let firstSide = samples(two)
        #expect(Array(samples(three).prefix(firstSide.count)) == firstSide)
    }
}

@Suite struct CloudToolTests {
    let make = { CloudTool(lineWidth: 1, arcSize: .small, seed: 3) as any Tool }

    /// Triángulo cerrado con doble clic.
    private func drawTriangle(_ controller: inout ToolController, _ canvas: inout Canvas) {
        _ = click(&controller, &canvas, at(10, 10), make: make)
        _ = click(&controller, &canvas, at(50, 10), make: make)
        _ = click(&controller, &canvas, at(50, 50), make: make)
        _ = click(&controller, &canvas, at(50, 50, clicks: 2), make: make)
    }

    @Test func doubleClickClosesAndKeepsEditable() throws {
        var canvas = Canvas(width: 64, height: 64)
        var controller = ToolController()
        drawTriangle(&controller, &canvas)
        let cloud = try #require(controller.tool as? CloudTool)
        #expect(cloud.isClosed)
        #expect(cloud.vertices.count == 3)
        #expect(controller.isPending, "Sigue editable con tiradores")
        #expect(controller.overlay?.handles.count == 8)
        #expect(!blackPixels(canvas.bitmap).isEmpty)
    }

    @Test func onlyOutlineNeverFills() {
        var canvas = Canvas(width: 64, height: 64)
        var controller = ToolController()
        drawTriangle(&controller, &canvas)
        _ = controller.commit(canvas: &canvas)
        #expect(canvas.bitmap[42, 20] == .white, "El interior queda sin rellenar")
    }

    @Test func dragInsideMoves() throws {
        var canvas = Canvas(width: 80, height: 80)
        var controller = ToolController()
        drawTriangle(&controller, &canvas)
        _ = controller.pointerDown(at(45, 20), canvas: &canvas, makeTool: make)
        controller.pointerDragged(at(55, 30), canvas: &canvas)
        _ = controller.pointerUp(at(55, 30), canvas: &canvas)
        let cloud = try #require(controller.tool as? CloudTool)
        #expect(cloud.vertices.first == CGPoint(x: 20, y: 20))
        #expect(cloud.bounds == PixelRect(x: 20, y: 20, width: 41, height: 41))
        #expect(controller.isPending)
    }

    @Test func handleResizes() throws {
        var canvas = Canvas(width: 120, height: 120)
        var controller = ToolController()
        drawTriangle(&controller, &canvas)
        // Tirador de abajo a la derecha (esquina del rectángulo de los vértices).
        let corner = PointerEvent(location: CGPoint(x: 51, y: 51), hitTolerance: 2)
        _ = controller.pointerDown(corner, canvas: &canvas, makeTool: make)
        controller.pointerDragged(at(90, 90), canvas: &canvas)
        _ = controller.pointerUp(at(90, 90), canvas: &canvas)
        let cloud = try #require(controller.tool as? CloudTool)
        #expect(cloud.bounds == PixelRect(x: 10, y: 10, width: 81, height: 81))
        #expect(cloud.vertices[1] == CGPoint(x: 90, y: 10))
    }

    @Test func clickOutsideCommitsAndStartsNew() throws {
        var canvas = Canvas(width: 120, height: 120)
        var controller = ToolController()
        drawTriangle(&controller, &canvas)
        let patch = controller.pointerDown(at(100, 100), canvas: &canvas, makeTool: make)
        #expect(try #require(patch).region.isEmpty == false)
        _ = controller.pointerUp(at(100, 100), canvas: &canvas)
        let cloud = try #require(controller.tool as? CloudTool)
        #expect(!cloud.isClosed && cloud.vertices.count == 1)
    }

    @Test func cancelDiscards() {
        var canvas = Canvas(width: 64, height: 64)
        var controller = ToolController()
        drawTriangle(&controller, &canvas)
        controller.cancel(canvas: &canvas)
        #expect(blackPixels(canvas.bitmap).isEmpty)
    }

    @Test func closeLeavesItEditable() throws {
        var canvas = Canvas(width: 64, height: 64)
        var controller = ToolController()
        _ = click(&controller, &canvas, at(10, 10), make: make)
        _ = click(&controller, &canvas, at(50, 10), make: make)
        #expect((controller.tool as? CloudTool)?.canClose == false)
        _ = click(&controller, &canvas, at(50, 50), make: make)
        #expect((controller.tool as? CloudTool)?.canClose == true)
        controller.modify(CloudTool.self, canvas: &canvas) { $0.close(on: &$1) }
        let cloud = try #require(controller.tool as? CloudTool)
        #expect(cloud.isClosed && controller.isPending)
    }
}
