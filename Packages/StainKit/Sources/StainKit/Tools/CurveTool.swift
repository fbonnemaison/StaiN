import CoreGraphics

/// Curva de Bézier con tres clics: el primero fija el inicio, el segundo el final y el tercero
/// el punto de control que la dobla. Entre clics, la vista previa sigue al ratón.
///
/// También se puede arrastrar: arrastrar el primer clic traza la línea recta de una vez, y arrastrar
/// el segundo o el tercero mueve ese punto hasta soltar. Mientras se crea se ven los puntos de control
/// y sus guías; al terminar desaparecen y queda solo la curva.
public struct CurveTool: Tool {
    public var lineWidth: Int

    private enum Phase: Sendable {
        case idle
        /// Pulsado el primer clic (o arrastrando la línea recta).
        case placingStart
        /// Inicio fijado: el final sigue al ratón.
        case awaitingEnd
        /// Pulsado el segundo clic.
        case placingEnd
        /// Recta fijada: el punto de control sigue al ratón.
        case awaitingControl
        /// Pulsado el tercer clic.
        case placingControl
        case done
    }

    private var phase: Phase = .idle
    private var start = CGPoint.zero
    private var end = CGPoint.zero
    private var control = CGPoint.zero
    private var color: PaintColor = .black

    public init(lineWidth: Int = 1) {
        self.lineWidth = lineWidth
    }

    /// Espera el segundo o el tercer clic.
    public var isAwaitingInput: Bool {
        switch phase {
        case .awaitingEnd, .awaitingControl: true
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
            control = point
            phase = .placingStart
        case .awaitingEnd:
            end = point
            control = Self.midpoint(start, point)
            phase = .placingEnd
        case .awaitingControl:
            control = point
            phase = .placingControl
        case .placingStart, .placingEnd, .placingControl:
            break
        }
        render(on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let point = Self.center(event)
        switch phase {
        case .placingStart, .placingEnd:
            end = point
            control = Self.midpoint(start, point)
        case .placingControl:
            control = point
        default:
            return
        }
        render(on: &canvas)
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        switch phase {
        // Un clic sin arrastrar solo fija el inicio; un arrastre ya deja la recta hecha.
        case .placingStart: phase = start == end ? .awaitingEnd : .awaitingControl
        // Si el segundo clic cae sobre el inicio, se sigue esperando el final.
        case .placingEnd: phase = start == end ? .awaitingEnd : .awaitingControl
        case .placingControl: phase = .done
        default: break
        }
        render(on: &canvas)
    }

    public mutating func hover(_ event: PointerEvent, on canvas: inout Canvas) {
        let point = Self.center(event)
        switch phase {
        case .awaitingEnd:
            end = point
            control = Self.midpoint(start, point)
        case .awaitingControl:
            control = point
        default:
            return
        }
        render(on: &canvas)
    }

    /// Confirma: con solo el inicio no queda nada; con la recta fijada queda la recta.
    public mutating func commit(on canvas: inout Canvas) {
        switch phase {
        case .awaitingEnd, .placingStart:
            canvas.revertToEditStart()
        case .awaitingControl, .placingEnd:
            control = Self.midpoint(start, end)
            phase = .done
            render(on: &canvas)
        default:
            break
        }
        phase = .done
    }

    /// Puntos de control y guías mientras se crea la curva; al terminar no hay ninguno.
    public var overlay: ToolOverlay? {
        switch phase {
        case .placingStart where start == end, .awaitingEnd where start == end:
            ToolOverlay(outline: [start], isClosed: false, handles: [start])
        case .placingStart, .awaitingEnd, .placingEnd:
            ToolOverlay(outline: [start, end], isClosed: false, handles: [start, end])
        case .awaitingControl, .placingControl:
            ToolOverlay(outline: [start, control, end], isClosed: false, handles: [start, control, end])
        case .idle, .done:
            nil
        }
    }

    /// Centro del píxel bajo el puntero.
    private static func center(_ event: PointerEvent) -> CGPoint {
        CGPoint(x: Double(event.pixel.x) + 0.5, y: Double(event.pixel.y) + 0.5)
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func render(on canvas: inout Canvas) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        if start == end { path.addLine(to: end) }  // un punto: se pinta igualmente
        canvas.revertToEditStart()
        canvas.drawPath(
            path, closed: false, style: ShapeStyle(lineWidth: lineWidth, outlineColor: color, fillColor: color))
    }
}
