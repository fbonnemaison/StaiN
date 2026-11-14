import CoreGraphics

/// Ejes de simetría para dibujar en espejo.
public struct Symmetry: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Refleja de izquierda a derecha (eje vertical en el centro).
    public static let horizontal = Symmetry(rawValue: 1 << 0)
    /// Refleja de arriba abajo (eje horizontal en el centro).
    public static let vertical = Symmetry(rawValue: 1 << 1)
}

/// Repite una herramienta de trazo libre reflejada respecto al centro de la imagen.
public struct MirroredTool: Tool {
    private var tools: [any Tool]
    private let flips: [(x: Bool, y: Bool)]
    private let width: Double
    private let height: Double

    public init(symmetry: Symmetry, canvasWidth: Int, canvasHeight: Int, make: () -> any Tool) {
        var flips: [(x: Bool, y: Bool)] = [(false, false)]
        if symmetry.contains(.horizontal) { flips.append((true, false)) }
        if symmetry.contains(.vertical) { flips.append((false, true)) }
        if symmetry.contains([.horizontal, .vertical]) { flips.append((true, true)) }
        self.flips = flips
        tools = flips.map { _ in make() }
        width = Double(canvasWidth)
        height = Double(canvasHeight)
    }

    private func reflected(_ event: PointerEvent, _ index: Int) -> PointerEvent {
        var copy = event
        let flip = flips[index]
        if flip.x { copy.location.x = width - event.location.x }
        if flip.y { copy.location.y = height - event.location.y }
        return copy
    }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        for i in tools.indices { tools[i].begin(reflected(event, i), on: &canvas) }
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        for i in tools.indices { tools[i].drag(reflected(event, i), on: &canvas) }
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        for i in tools.indices { tools[i].end(reflected(event, i), on: &canvas) }
    }

    public mutating func cancel(on canvas: inout Canvas) {
        for i in tools.indices { tools[i].cancel(on: &canvas) }
    }

    public var repeatsWhileHeld: Bool { tools.first?.repeatsWhileHeld ?? false }
}
