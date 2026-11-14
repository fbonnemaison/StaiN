import CoreGraphics

/// Polígono: se arrastra el primer lado y luego cada clic añade un vértice.
/// Doble clic, o un clic sobre el primer vértice, lo cierra.
public struct PolygonTool: Tool {
    public var fillMode: ShapeFillMode
    public var lineWidth: Int
    public private(set) var points: [(x: Int, y: Int)] = []
    private var style: ShapeStyle?
    private var isClosed = false

    public init(fillMode: ShapeFillMode = .outline, lineWidth: Int = 1) {
        self.fillMode = fillMode
        self.lineWidth = lineWidth
    }

    public var isAwaitingInput: Bool { !points.isEmpty && !isClosed }
    public func accepts(_ event: PointerEvent) -> Bool { isAwaitingInput }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        if points.isEmpty {
            style = ShapeStyle(fillMode: fillMode, lineWidth: lineWidth, button: event.button, canvas: canvas)
            points = [pixel, pixel]
        } else if event.clickCount >= 2 || isNearFirst(event) {
            // El primer clic del doble clic ya añadió un vértice en el mismo sitio: se quita.
            if event.clickCount >= 2, points.count > 3 { points.removeLast() }
            isClosed = true
        } else {
            points.append(pixel)
        }
        render(on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        guard !isClosed, !points.isEmpty else { return }
        points[points.count - 1] = event.pixel
        render(on: &canvas)
    }

    public mutating func commit(on canvas: inout Canvas) {
        guard points.count >= 3 else { return }
        isClosed = true
        render(on: &canvas)
    }

    private func isNearFirst(_ event: PointerEvent) -> Bool {
        guard points.count >= 3, let first = points.first else { return false }
        let tolerance = max(event.hitTolerance, 2)
        return abs(Double(first.x) + 0.5 - event.location.x) <= tolerance
            && abs(Double(first.y) + 0.5 - event.location.y) <= tolerance
    }

    private func render(on canvas: inout Canvas) {
        guard let style, let first = points.first else { return }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: Double(first.x) + 0.5, y: Double(first.y) + 0.5))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: Double(point.x) + 0.5, y: Double(point.y) + 0.5))
        }
        if isClosed { path.closeSubpath() }
        canvas.revertToEditStart()
        canvas.drawPath(path, closed: isClosed, style: style)
    }
}
