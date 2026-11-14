import CoreGraphics

/// Curva al estilo de Paint: se arrastra una línea recta y después dos clics (o arrastres) la doblan.
public struct CurveTool: Tool {
    public var lineWidth: Int

    private enum Phase: Sendable {
        case idle
        case line
        case firstBend
        case secondBend
        case done
    }

    private var phase: Phase = .idle
    private var start = CGPoint.zero
    private var end = CGPoint.zero
    private var control1 = CGPoint.zero
    private var control2 = CGPoint.zero
    private var color: PaintColor = .black

    public init(lineWidth: Int = 1) {
        self.lineWidth = lineWidth
    }

    /// Espera el primer o el segundo doblez.
    public var isAwaitingInput: Bool {
        switch phase {
        case .firstBend, .secondBend: true
        default: false
        }
    }

    public func accepts(_ event: PointerEvent) -> Bool { isAwaitingInput }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let point = Self.center(event)
        switch phase {
        case .idle, .done:
            color = canvas.color(for: event.button)
            start = point
            end = point
            control1 = point
            control2 = point
            phase = .line
        case .firstBend:
            control1 = point
            control2 = point
        case .secondBend:
            control2 = point
        case .line:
            break
        }
        render(on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let point = Self.center(event)
        switch phase {
        case .line:
            end = point
            control1 = start
            control2 = point
        case .firstBend:
            control1 = point
            control2 = point
        case .secondBend:
            control2 = point
        case .idle, .done:
            return
        }
        render(on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        switch phase {
        case .line: phase = start == end ? .done : .firstBend
        case .firstBend: phase = .secondBend
        case .secondBend: phase = .done
        case .idle, .done: break
        }
    }

    public mutating func commit(on canvas: inout Canvas) {
        phase = .done
    }

    /// Centro del píxel bajo el puntero.
    private static func center(_ event: PointerEvent) -> CGPoint {
        CGPoint(x: Double(event.pixel.x) + 0.5, y: Double(event.pixel.y) + 0.5)
    }

    private func render(on canvas: inout Canvas) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: end, control1: control1, control2: control2)
        if start == end { path.addLine(to: end) }  // un punto: se pinta igualmente
        canvas.revertToEditStart()
        canvas.drawPath(
            path, closed: false, style: ShapeStyle(lineWidth: lineWidth, outlineColor: color, fillColor: color))
    }
}
