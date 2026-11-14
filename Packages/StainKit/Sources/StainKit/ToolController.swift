/// Gestiona la herramienta activa sobre un lienzo, incluidas las que siguen abiertas entre clics.
///
/// Cada edición (un trazo, o todos los clics de un polígono o de una forma editable) produce
/// un único `UndoPatch` al terminar.
public struct ToolController: Sendable {
    public private(set) var tool: (any Tool)?
    public private(set) var isPointerDown = false
    private var lastEvent: PointerEvent?

    public init() {}

    /// La herramienta está esperando más clics (o el botón sigue pulsado).
    public var isActive: Bool { tool != nil }
    public var isPending: Bool { tool != nil && !isPointerDown }
    public var overlay: ToolOverlay? { tool?.overlay }
    public var repeatsWhileHeld: Bool { isPointerDown && (tool?.repeatsWhileHeld ?? false) }

    /// Pulsación. Si había una herramienta pendiente y el clic no le pertenece, se confirma primero
    /// y se devuelve su parche.
    public mutating func pointerDown(
        _ event: PointerEvent, canvas: inout Canvas, makeTool: () -> any Tool
    ) -> UndoPatch? {
        var committed: UndoPatch?
        if var pending = tool, !isPointerDown {
            if pending.accepts(event) {
                pending.begin(event, on: &canvas)
                tool = pending
                isPointerDown = true
                lastEvent = event
                return nil
            }
            committed = commit(canvas: &canvas)
        } else if isPointerDown {
            cancel(canvas: &canvas)
        }
        var newTool = makeTool()
        canvas.beginEdit()
        newTool.begin(event, on: &canvas)
        tool = newTool
        isPointerDown = true
        lastEvent = event
        return committed
    }

    public mutating func pointerDragged(_ event: PointerEvent, canvas: inout Canvas) {
        guard isPointerDown, var current = tool else { return }
        current.drag(event, on: &canvas)
        tool = current
        lastEvent = event
    }

    /// Suelta el botón. Devuelve el parche si la edición terminó (la herramienta no espera más clics).
    public mutating func pointerUp(_ event: PointerEvent, canvas: inout Canvas) -> UndoPatch? {
        guard isPointerDown, var current = tool else { return nil }
        current.end(event, on: &canvas)
        isPointerDown = false
        lastEvent = nil
        if current.isAwaitingInput {
            tool = current
            return nil
        }
        tool = nil
        return canvas.endEdit()
    }

    /// Repite la última acción con el botón quieto (aerógrafo). Llamar periódicamente.
    public mutating func tick(canvas: inout Canvas) {
        guard repeatsWhileHeld, let lastEvent else { return }
        pointerDragged(lastEvent, canvas: &canvas)
    }

    /// Confirma la herramienta pendiente (o en curso) y devuelve su parche.
    public mutating func commit(canvas: inout Canvas) -> UndoPatch? {
        guard var current = tool else { return nil }
        current.commit(on: &canvas)
        tool = nil
        isPointerDown = false
        lastEvent = nil
        return canvas.endEdit()
    }

    /// Descarta la herramienta en curso y restaura la imagen.
    public mutating func cancel(canvas: inout Canvas) {
        guard var current = tool else { return }
        current.cancel(on: &canvas)
        tool = nil
        isPointerDown = false
        lastEvent = nil
        canvas.cancelEdit()
    }
}
