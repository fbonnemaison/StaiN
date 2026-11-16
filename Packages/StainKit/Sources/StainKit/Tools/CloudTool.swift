import CoreGraphics
import Foundation

/// Tamaño de los arcos de la nube de revisión (longitud aproximada de la cuerda de cada arco, en píxeles).
public enum CloudArcSize: String, CaseIterable, Sendable, Hashable {
    case small
    case medium
    case large

    public var chord: Double {
        switch self {
        case .small: 10
        case .medium: 18
        case .large: 30
        }
    }
}

/// Trazado de una nube de revisión: cada lado de un polígono se reparte en arcos que abomban hacia fuera.
public enum CloudPath {
    /// - Parameters:
    ///   - vertices: vértices del polígono (en coordenadas de imagen, ya centrados en el píxel).
    ///   - closed: si se une el último vértice con el primero.
    ///   - chord: longitud deseada de cada arco; los arcos de un lado se reparten para que encajen exactos.
    ///   - seed: semilla del estilo boceto (pequeñas variaciones de radio). La misma semilla da la misma nube.
    ///   - jitter: variación máxima del radio, como fracción (0 = arcos regulares).
    public static func make(
        vertices: [CGPoint], closed: Bool, chord: Double, seed: UInt64, jitter: Double = 0.18
    ) -> CGPath {
        let path = CGMutablePath()
        guard let first = vertices.first else { return path }
        path.move(to: first)
        guard vertices.count >= 2 else { return path }
        // Sentido del polígono: decide hacia qué lado está "fuera".
        let clockwiseOnScreen = signedArea(vertices) >= 0
        let sides = closed ? vertices.count : vertices.count - 1
        for side in 0..<sides {
            let p = vertices[side]
            let q = vertices[(side + 1) % vertices.count]
            addArcs(
                to: path, from: p, to: q, outwardIsRight: clockwiseOnScreen, chord: chord,
                seed: seed &+ UInt64(side) &* 0x9E37_79B9_7F4A_7C15, jitter: jitter)
        }
        if closed { path.closeSubpath() }
        return path
    }

    /// Número de arcos de un lado de longitud `length`.
    public static func arcCount(length: Double, chord: Double) -> Int {
        max(1, Int((length / max(chord, 1)).rounded()))
    }

    /// Área con signo (fórmula del lazo). Con y hacia abajo, positiva = sentido horario en pantalla.
    static func signedArea(_ points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    private static func addArcs(
        to path: CGMutablePath, from p: CGPoint, to q: CGPoint, outwardIsRight: Bool, chord: Double, seed: UInt64,
        jitter: Double
    ) {
        let dx = q.x - p.x, dy = q.y - p.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0.01 else { return }
        let ux = dx / length, uy = dy / length
        // Normal hacia fuera: a la derecha del avance si el polígono va en sentido horario (área positiva).
        let nx = outwardIsRight ? uy : -uy
        let ny = outwardIsRight ? -ux : ux
        let count = arcCount(length: length, chord: chord)
        let step = length / Double(count)
        var random = SplitMix64(seed: seed)
        for index in 0..<count {
            let start = CGPoint(x: p.x + ux * step * Double(index), y: p.y + uy * step * Double(index))
            let end = CGPoint(x: p.x + ux * step * Double(index + 1), y: p.y + uy * step * Double(index + 1))
            let half = step / 2
            // Radio algo mayor que media cuerda (arco algo menor que media circunferencia), variado a mano.
            let variation = 1 + jitter * (random.nextUnit() * 2 - 1)
            let radius = max(half, half * 1.15 * variation)
            // El centro queda hacia dentro, para que el arco abombe hacia fuera.
            let inset = (radius * radius - half * half).squareRoot()
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let center = CGPoint(x: mid.x - nx * inset, y: mid.y - ny * inset)
            let startAngle = atan2(start.y - center.y, start.x - center.x)
            let endAngle = atan2(end.y - center.y, end.x - center.x)
            let outwardAngle = atan2(ny, nx)
            // Barrido de start a end que pasa por el lado de fuera.
            var delta = normalized(endAngle - startAngle)
            if normalized(outwardAngle - startAngle) > delta { delta -= 2 * .pi }
            path.addRelativeArc(center: center, radius: radius, startAngle: startAngle, delta: delta)
        }
    }

    /// Ángulo en [0, 2π).
    private static func normalized(_ angle: Double) -> Double {
        let full = 2 * Double.pi
        let value = angle.truncatingRemainder(dividingBy: full)
        return value < 0 ? value + full : value
    }
}

extension SplitMix64 {
    /// Número en [0, 1).
    mutating func nextUnit() -> Double { Double(next() >> 11) / Double(UInt64(1) << 53) }
}

/// Nube de revisión: rodea una zona con arcos, como en las revisiones de planos y PDF.
///
/// Se dibuja como el polígono libre (un clic por vértice; doble clic, clic en el primer vértice o
/// Escape para cerrar) y, una vez cerrada, sigue editable como las formas: arrastrando dentro se mueve
/// y con los 8 tiradores se redimensiona. Intro, un clic fuera o cambiar de herramienta la confirman.
/// Solo contorno, con el color del botón.
public struct CloudTool: Tool {
    public var lineWidth: Int
    public var arcSize: CloudArcSize
    /// Semilla del estilo boceto, fija para toda la nube (la vista previa no tiembla).
    public let seed: UInt64

    private enum Phase: Sendable {
        case placing
        case editing
        case moving(from: CGPoint, original: [CGPoint])
        case resizing(handle: Int, original: [CGPoint], originalRect: PixelRect)
    }

    private var phase: Phase = .placing
    private var style: ShapeStyle?
    /// Vértices (coordenadas de píxel: el centro del píxel x es x + 0,5).
    public private(set) var vertices: [CGPoint] = []
    private var cursor: CGPoint?

    public init(lineWidth: Int = 2, arcSize: CloudArcSize = .medium, seed: UInt64 = .random(in: .min ... .max)) {
        self.lineWidth = lineWidth
        self.arcSize = arcSize
        self.seed = seed
    }

    private var isPlacing: Bool {
        if case .placing = phase { return true }
        return false
    }

    public var isClosed: Bool { !isPlacing }

    public var isAwaitingInput: Bool {
        switch phase {
        case .placing: !vertices.isEmpty
        case .editing: true
        case .moving, .resizing: false
        }
    }

    /// Tiene vértices suficientes para cerrarse (Escape la cierra en vez de descartarla).
    public var canClose: Bool { isPlacing && vertices.count >= 3 }

    public func accepts(_ event: PointerEvent) -> Bool {
        switch phase {
        case .placing: return !vertices.isEmpty
        case .editing:
            return handle(at: event.location, tolerance: event.hitTolerance) != nil
                || bounds.cgRect.insetBy(dx: -event.hitTolerance, dy: -event.hitTolerance).contains(event.location)
        case .moving, .resizing: return false
        }
    }

    /// Rectángulo que abarca los vértices (los tiradores van en sus esquinas y lados).
    public var bounds: PixelRect {
        guard let first = vertices.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in vertices {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return PixelRect(
            corner: (Int(minX.rounded()), Int(minY.rounded())), (Int(maxX.rounded()), Int(maxY.rounded())))
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = Self.point(event.pixel)
        switch phase {
        case .placing:
            if vertices.isEmpty {
                style = ShapeStyle(fillMode: .outline, lineWidth: lineWidth, button: event.button, canvas: canvas)
                vertices = [pixel]
            } else if event.clickCount >= 2 || isNearFirst(event) {
                // El primer clic del doble clic ya añadió un vértice en el mismo sitio: se quita.
                if event.clickCount >= 2, vertices.count > 3, vertices.last == pixel { vertices.removeLast() }
                if vertices.count >= 3 { close() }
            } else if vertices.last != pixel {
                vertices.append(pixel)
            }
            cursor = pixel
        case .editing:
            if let index = handle(at: event.location, tolerance: event.hitTolerance) {
                phase = .resizing(handle: index, original: vertices, originalRect: bounds)
            } else {
                phase = .moving(from: pixel, original: vertices)
            }
        case .moving, .resizing:
            return
        }
        render(on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = Self.point(event.pixel)
        switch phase {
        case .placing:
            guard !vertices.isEmpty else { return }
            cursor = pixel
        case .moving(let from, let original):
            vertices = original.map { CGPoint(x: $0.x + pixel.x - from.x, y: $0.y + pixel.y - from.y) }
        case .resizing(let index, let original, let originalRect):
            let target = ShapeTool.resize(originalRect, handle: index, to: event.pixel)
            vertices = Self.map(original, from: originalRect, to: target)
        case .editing:
            return
        }
        render(on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        switch phase {
        case .placing:
            guard let last = vertices.last else { return }
            // Al arrastrar, el punto donde se suelta es un vértice más.
            let pixel = Self.point(event.pixel)
            if pixel != last, !isNearFirst(event) { vertices.append(pixel) }
            cursor = pixel
            render(on: &canvas)
        case .moving, .resizing:
            drag(event, on: &canvas)
            phase = .editing
        case .editing:
            return
        }
    }

    public mutating func hover(_ event: PointerEvent, on canvas: inout Canvas) {
        guard isPlacing, !vertices.isEmpty else { return }
        cursor = Self.point(event.pixel)
        render(on: &canvas)
    }

    /// Cierra la nube (con 3 vértices o más) y la deja editable con tiradores.
    public mutating func close(on canvas: inout Canvas) {
        guard canClose else { return }
        close()
        render(on: &canvas)
    }

    /// Confirma: con 3 vértices o más se cierra; con menos queda la línea de arcos abierta.
    public mutating func commit(on canvas: inout Canvas) {
        if canClose { close() }
        cursor = nil
        render(on: &canvas)
    }

    private mutating func close() {
        phase = .editing
        cursor = nil
    }

    public var overlay: ToolOverlay? {
        switch phase {
        case .placing:
            guard let first = vertices.first else { return nil }
            var points = vertices
            if let cursor, cursor != points.last ?? first { points.append(cursor) }
            let centers = points.map(Self.center)
            return ToolOverlay(outline: centers, isClosed: false, handles: centers)
        case .editing:
            let r = bounds.cgRect
            return ToolOverlay(
                outline: [
                    CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
                    CGPoint(x: r.minX, y: r.maxY),
                ],
                handles: ShapeTool.handlePoints(r))
        case .moving, .resizing:
            return nil
        }
    }

    /// Trazado actual de la nube (con el lado provisional hacia el ratón mientras se crea).
    public var path: CGPath {
        var points = vertices
        if isPlacing, let cursor, let last = points.last, cursor != last { points.append(cursor) }
        return CloudPath.make(
            vertices: points.map(Self.center), closed: isClosed, chord: arcSize.chord + Double(lineWidth),
            seed: seed)
    }

    private func render(on canvas: inout Canvas) {
        guard let style, !vertices.isEmpty else { return }
        canvas.revertToEditStart()
        canvas.drawPath(path, closed: isClosed, style: style)
    }

    // MARK: Geometría

    private static func point(_ pixel: (x: Int, y: Int)) -> CGPoint { CGPoint(x: pixel.x, y: pixel.y) }
    private static func center(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x + 0.5, y: point.y + 0.5) }

    private func isNearFirst(_ event: PointerEvent) -> Bool {
        guard vertices.count >= 3, let first = vertices.first else { return false }
        let tolerance = max(event.hitTolerance, 2)
        return abs(first.x + 0.5 - event.location.x) <= tolerance && abs(first.y + 0.5 - event.location.y) <= tolerance
    }

    private func handle(at point: CGPoint, tolerance: Double) -> Int? {
        ShapeTool.handlePoints(bounds.cgRect).firstIndex {
            abs($0.x - point.x) <= tolerance && abs($0.y - point.y) <= tolerance
        }
    }

    /// Lleva los vértices de un rectángulo a otro, proporcionalmente (en píxeles: de la primera a la última fila).
    static func map(_ points: [CGPoint], from old: PixelRect, to new: PixelRect) -> [CGPoint] {
        func scale(_ value: Double, _ oldMin: Int, _ oldSize: Int, _ newMin: Int, _ newSize: Int) -> Double {
            guard oldSize > 1 else { return Double(newMin) + Double(newSize - 1) / 2 }
            return Double(newMin) + (value - Double(oldMin)) * Double(newSize - 1) / Double(oldSize - 1)
        }
        return points.map {
            CGPoint(
                x: scale($0.x, old.minX, old.width, new.minX, new.width),
                y: scale($0.y, old.minY, old.height, new.minY, new.height))
        }
    }
}
