import CoreGraphics

/// Botón del ratón o de la tableta. En Paint, el izquierdo pinta con el color primario y el derecho con el secundario.
public enum PointerButton: Sendable, Hashable {
    case primary
    case secondary
}

/// Teclas modificadoras relevantes para las herramientas.
public struct PointerModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Restringe ángulos y proporciones (líneas a 45°, cuadrados, círculos).
    public static let shift = PointerModifiers(rawValue: 1 << 0)
    /// Duplicar al mover una selección, dibujar desde el centro…
    public static let option = PointerModifiers(rawValue: 1 << 1)
    public static let command = PointerModifiers(rawValue: 1 << 2)
    public static let control = PointerModifiers(rawValue: 1 << 3)
}

/// Evento de puntero ya convertido a coordenadas de la imagen (en píxeles, origen arriba a la izquierda).
/// La posición puede tener decimales y quedar fuera de la imagen.
public struct PointerEvent: Sendable, Hashable {
    public var location: CGPoint
    public var button: PointerButton
    public var modifiers: PointerModifiers
    /// Presión entre 0 y 1 (1 para ratón).
    public var pressure: Double
    /// 1 para clic simple, 2 para doble clic…
    public var clickCount: Int
    /// Distancia (en píxeles de imagen) a la que se considera que el puntero "toca" un tirador.
    /// Depende del zoom: a más zoom, menos píxeles de imagen.
    public var hitTolerance: Double

    public init(
        location: CGPoint, button: PointerButton = .primary, modifiers: PointerModifiers = [], pressure: Double = 1,
        clickCount: Int = 1, hitTolerance: Double = 3
    ) {
        self.location = location
        self.button = button
        self.modifiers = modifiers
        self.pressure = pressure
        self.clickCount = clickCount
        self.hitTolerance = hitTolerance
    }

    /// Píxel bajo el puntero.
    public var pixel: (x: Int, y: Int) {
        (Int(location.x.rounded(.down)), Int(location.y.rounded(.down)))
    }
}

/// Herramienta de dibujo.
///
/// Quien la usa (la vista del lienzo) se encarga de la edición deshacible:
/// llama a `canvas.beginEdit()` antes de `begin`, a `canvas.endEdit()` después de `end`
/// y a `canvas.cancelEdit()` después de `cancel`. `ToolSession` hace esto por ti.
public protocol Tool: Sendable {
    /// Se pulsa el botón.
    mutating func begin(_ event: PointerEvent, on canvas: inout Canvas)
    /// El puntero se mueve con el botón pulsado.
    mutating func drag(_ event: PointerEvent, on canvas: inout Canvas)
    /// Se suelta el botón.
    mutating func end(_ event: PointerEvent, on canvas: inout Canvas)
    /// Se interrumpe la acción (Escape, cambio de herramienta…). La edición se descarta después.
    mutating func cancel(on canvas: inout Canvas)

    /// `true` si, tras soltar el botón, la herramienta sigue esperando más clics
    /// (polígono, curva, forma editable). La edición sigue abierta hasta `commit`.
    var isAwaitingInput: Bool { get }
    /// Con la herramienta esperando: ¿este clic le pertenece? Si no, se confirma y empieza una nueva.
    func accepts(_ event: PointerEvent) -> Bool
    /// Confirma el trabajo pendiente (Intro, cambio de herramienta, clic fuera).
    mutating func commit(on canvas: inout Canvas)
    /// Guías que la vista dibuja encima de la imagen (no forman parte de ella).
    var overlay: ToolOverlay? { get }
    /// `true` si la herramienta sigue actuando mientras el botón está pulsado aunque no se mueva (aerógrafo).
    var repeatsWhileHeld: Bool { get }
}

extension Tool {
    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {}
    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {}
    public mutating func cancel(on canvas: inout Canvas) {}
    public var isAwaitingInput: Bool { false }
    public func accepts(_ event: PointerEvent) -> Bool { false }
    public mutating func commit(on canvas: inout Canvas) {}
    public var overlay: ToolOverlay? { nil }
    public var repeatsWhileHeld: Bool { false }
}

/// Guías de edición en coordenadas de imagen: un contorno y tiradores.
public struct ToolOverlay: Sendable, Equatable {
    public var outline: [CGPoint]
    public var isClosed: Bool
    public var handles: [CGPoint]

    public init(outline: [CGPoint] = [], isClosed: Bool = true, handles: [CGPoint] = []) {
        self.outline = outline
        self.isClosed = isClosed
        self.handles = handles
    }
}

/// Conecta una herramienta con un lienzo y un historial: cada trazo completo es un paso de deshacer.
public struct ToolSession<T: Tool>: Sendable {
    public var tool: T
    public private(set) var isActive = false

    public init(tool: T) {
        self.tool = tool
    }

    public mutating func pointerDown(_ event: PointerEvent, canvas: inout Canvas) {
        if isActive { cancel(canvas: &canvas) }
        canvas.beginEdit()
        isActive = true
        tool.begin(event, on: &canvas)
    }

    public mutating func pointerDragged(_ event: PointerEvent, canvas: inout Canvas) {
        guard isActive else { return }
        tool.drag(event, on: &canvas)
    }

    /// Termina el trazo y devuelve el parche para deshacerlo, o `nil` si no cambió nada.
    public mutating func pointerUp(_ event: PointerEvent, canvas: inout Canvas) -> UndoPatch? {
        guard isActive else { return nil }
        tool.end(event, on: &canvas)
        isActive = false
        return canvas.endEdit()
    }

    /// Termina el trazo y, si cambió algo, lo guarda en el historial.
    public mutating func pointerUp(_ event: PointerEvent, canvas: inout Canvas, history: inout UndoHistory) {
        if let patch = pointerUp(event, canvas: &canvas) { history.record(patch) }
    }

    public mutating func cancel(canvas: inout Canvas) {
        guard isActive else { return }
        tool.cancel(on: &canvas)
        canvas.cancelEdit()
        isActive = false
    }
}
