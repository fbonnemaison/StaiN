import CoreGraphics

/// Polígono libre: cada clic añade un vértice y, entre clics, el lado siguiente sigue al ratón.
/// (También se puede arrastrar el primer lado.)
///
/// Se cierra con un clic sobre el primer vértice, con doble clic o con Escape (si ya tiene 3 vértices).
/// Mientras se crea se ven sus puntos de control (los vértices); al cerrarlo desaparecen.
public struct PolygonTool: Tool {
    public var fillMode: ShapeFillMode
    public var lineWidth: Int
    /// Vértices fijados.
    public private(set) var points: [(x: Int, y: Int)] = []
    /// Posición del ratón: extremo del lado que se está trazando.
    private var cursor: (x: Int, y: Int)?
    private var style: ShapeStyle?
    private var isClosed = false

    public init(fillMode: ShapeFillMode = .outline, lineWidth: Int = 1) {
        self.fillMode = fillMode
        self.lineWidth = lineWidth
    }

    public var isAwaitingInput: Bool { !points.isEmpty && !isClosed }
    public func accepts(_ event: PointerEvent) -> Bool { isAwaitingInput }
    /// Tiene vértices suficientes para cerrarse (Escape lo cierra en vez de descartarlo).
    public var canClose: Bool { points.count >= 3 && !isClosed }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        if points.isEmpty {
            style = ShapeStyle(fillMode: fillMode, lineWidth: lineWidth, button: event.button, canvas: canvas)
            points = [pixel]
        } else if event.clickCount >= 2 || isNearFirst(event) {
            // El primer clic del doble clic ya añadió un vértice en el mismo sitio: se quita.
            if event.clickCount >= 2, points.count > 3, let last = points.last, last == pixel {
                points.removeLast()
            }
            if points.count >= 3 { isClosed = true }
        } else if points.last.map({ $0 != pixel }) ?? true {
            points.append(pixel)
        }
        cursor = pixel
        render(on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        guard !isClosed, !points.isEmpty else { return }
        cursor = event.pixel
        render(on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        guard !isClosed, let last = points.last else { return }
        // Al arrastrar, el punto donde se suelta es un vértice más.
        if event.pixel != last, !isNearFirst(event) { points.append(event.pixel) }
        cursor = event.pixel
        render(on: &canvas)
    }

    public mutating func hover(_ event: PointerEvent, on canvas: inout Canvas) {
        guard !isClosed, !points.isEmpty else { return }
        cursor = event.pixel
        render(on: &canvas)
    }

    /// Confirma: con 3 vértices o más se cierra; con menos queda la línea abierta, sin el lado provisional.
    public mutating func commit(on canvas: inout Canvas) {
        if points.count >= 3 { isClosed = true }
        cursor = nil
        render(on: &canvas)
    }

    /// Puntos de control mientras se crea el polígono; al cerrarlo no hay ninguno.
    public var overlay: ToolOverlay? {
        guard !isClosed, let first = points.first else { return nil }
        var vertices = points
        if let cursor, cursor != vertices.last ?? first { vertices.append(cursor) }
        let centers = vertices.map { CGPoint(x: Double($0.x) + 0.5, y: Double($0.y) + 0.5) }
        return ToolOverlay(outline: centers, isClosed: false, handles: centers)
    }

    private func isNearFirst(_ event: PointerEvent) -> Bool {
        guard points.count >= 3, let first = points.first else { return false }
        let tolerance = max(event.hitTolerance, 2)
        return abs(Double(first.x) + 0.5 - event.location.x) <= tolerance
            && abs(Double(first.y) + 0.5 - event.location.y) <= tolerance
    }

    private func render(on canvas: inout Canvas) {
        guard let style, let first = points.first else { return }
        var vertices = points
        if !isClosed, let cursor, cursor != vertices.last ?? first { vertices.append(cursor) }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: Double(first.x) + 0.5, y: Double(first.y) + 0.5))
        for point in vertices.dropFirst() {
            path.addLine(to: CGPoint(x: Double(point.x) + 0.5, y: Double(point.y) + 0.5))
        }
        if vertices.count == 1 { path.addLine(to: CGPoint(x: Double(first.x) + 0.5, y: Double(first.y) + 0.5)) }
        if isClosed { path.closeSubpath() }
        canvas.revertToEditStart()
        canvas.drawPath(path, closed: isClosed, style: style)
    }
}
