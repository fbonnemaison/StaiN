import CoreGraphics

/// Rectángulo, rectángulo redondeado o elipse.
///
/// Al soltar, la forma sigue editable: arrastrando dentro se mueve y con los tiradores se redimensiona.
/// Un clic fuera (o cambiar de herramienta) la confirma. Con Shift, proporción 1:1 (cuadrado o círculo).
public struct ShapeTool: Tool {
    public let kind: ShapeKind
    public var fillMode: ShapeFillMode
    public var lineWidth: Int

    private enum Phase: Sendable {
        case idle
        case drawing(anchor: (x: Int, y: Int))
        case editing
        case moving(from: (x: Int, y: Int), original: PixelRect)
        case resizing(handle: Int, original: PixelRect)
    }

    private var phase: Phase = .idle
    private var style: ShapeStyle?
    public private(set) var rect: PixelRect = .zero

    public init(kind: ShapeKind, fillMode: ShapeFillMode = .outline, lineWidth: Int = 1) {
        self.kind = kind
        self.fillMode = fillMode
        self.lineWidth = lineWidth
    }

    public var isAwaitingInput: Bool {
        if case .editing = phase { return true }
        return false
    }

    public func accepts(_ event: PointerEvent) -> Bool {
        guard case .editing = phase else { return false }
        return handle(at: event.location, tolerance: event.hitTolerance) != nil
            || rect.cgRect.insetBy(dx: -event.hitTolerance, dy: -event.hitTolerance).contains(event.location)
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        switch phase {
        case .editing:
            if let index = handle(at: event.location, tolerance: event.hitTolerance) {
                phase = .resizing(handle: index, original: rect)
            } else {
                phase = .moving(from: pixel, original: rect)
            }
        default:
            style = ShapeStyle(fillMode: fillMode, lineWidth: lineWidth, button: event.button, canvas: canvas)
            phase = .drawing(anchor: pixel)
            rect = PixelRect(corner: pixel, pixel)
            render(on: &canvas)
        }
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        switch phase {
        case .drawing(let anchor):
            rect = PixelRect(corner: anchor, Self.constrain(anchor, pixel, square: event.modifiers.contains(.shift)))
        case .moving(let from, let original):
            rect = PixelRect(
                x: original.x + pixel.x - from.x, y: original.y + pixel.y - from.y, width: original.width,
                height: original.height)
        case .resizing(let index, let original):
            rect = Self.resize(original, handle: index, to: pixel)
        case .idle, .editing:
            return
        }
        render(on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        phase = .editing
    }

    public mutating func commit(on canvas: inout Canvas) {
        phase = .idle
    }

    public mutating func cancel(on canvas: inout Canvas) {
        phase = .idle
    }

    public var overlay: ToolOverlay? {
        guard isAwaitingInput else { return nil }
        let r = rect.cgRect
        return ToolOverlay(
            outline: [
                CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
                CGPoint(x: r.minX, y: r.maxY),
            ],
            handles: Self.handlePoints(r))
    }

    private func render(on canvas: inout Canvas) {
        guard let style else { return }
        canvas.revertToEditStart()
        canvas.drawShape(kind, in: rect, style: style)
    }

    // MARK: Geometría

    /// Esquinas y puntos medios, en el sentido de las agujas del reloj empezando arriba a la izquierda.
    static func handlePoints(_ r: CGRect) -> [CGPoint] {
        [
            CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
            CGPoint(x: r.maxX, y: r.midY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.midX, y: r.maxY),
            CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.midY),
        ]
    }

    private func handle(at point: CGPoint, tolerance: Double) -> Int? {
        Self.handlePoints(rect.cgRect).firstIndex {
            abs($0.x - point.x) <= tolerance && abs($0.y - point.y) <= tolerance
        }
    }

    static func constrain(_ anchor: (x: Int, y: Int), _ point: (x: Int, y: Int), square: Bool) -> (x: Int, y: Int) {
        guard square else { return point }
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        let side = max(abs(dx), abs(dy))
        return (anchor.x + (dx < 0 ? -side : side), anchor.y + (dy < 0 ? -side : side))
    }

    /// Mueve los bordes que controla el tirador hasta el píxel (incluido).
    static func resize(_ r: PixelRect, handle: Int, to pixel: (x: Int, y: Int)) -> PixelRect {
        var left = r.minX
        var top = r.minY
        var right = r.maxX - 1
        var bottom = r.maxY - 1
        if [0, 6, 7].contains(handle) { left = pixel.x }
        if [2, 3, 4].contains(handle) { right = pixel.x }
        if [0, 1, 2].contains(handle) { top = pixel.y }
        if [4, 5, 6].contains(handle) { bottom = pixel.y }
        return PixelRect(corner: (left, top), (right, bottom))
    }
}
