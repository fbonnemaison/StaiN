/// Paso deshacible: la región que cambió, con sus píxeles de antes y de después.
///
/// Solo se guarda el rectángulo afectado, así que un trazo pequeño en una imagen grande ocupa poco.
public struct UndoPatch: Sendable, Hashable {
    public enum Direction: Sendable {
        case undo
        case redo
    }

    public let region: PixelRect
    let before: Bitmap
    let after: Bitmap

    /// Crea el parche comparando dos versiones del mismo tamaño en `region`.
    /// Devuelve `nil` si la región está vacía o si los píxeles no cambiaron.
    public init?(before old: Bitmap, after new: Bitmap, region: PixelRect) {
        precondition(old.width == new.width && old.height == new.height, "Bitmaps must have the same size")
        guard
            let before = old.cropped(to: region),
            let after = new.cropped(to: region),
            before != after
        else { return nil }
        self.region = region.intersection(old.bounds)
        self.before = before
        self.after = after
    }

    /// Memoria aproximada que ocupa el parche.
    public var byteCount: Int { before.byteCount + after.byteCount }

    /// Escribe los píxeles de antes (deshacer) o de después (rehacer). Devuelve la región modificada.
    @discardableResult
    public func apply(_ direction: Direction, to bitmap: inout Bitmap) -> PixelRect {
        bitmap.replace(with: direction == .undo ? before : after, atX: region.x, y: region.y)
    }
}

/// Pila de deshacer/rehacer con límite de pasos y de memoria.
///
/// Es independiente de AppKit para poder probarla. La app la conecta con `UndoManager`
/// (menú Edición, ⌘Z/⇧⌘Z) en la Fase 2.
public struct UndoHistory: Sendable {
    public let maxSteps: Int
    public let maxBytes: Int
    private var undoStack: [UndoPatch] = []
    private var redoStack: [UndoPatch] = []

    /// Por defecto, 100 pasos o 512 MB, lo que se alcance antes.
    public init(maxSteps: Int = 100, maxBytes: Int = 512 * 1024 * 1024) {
        precondition(maxSteps > 0 && maxBytes > 0)
        self.maxSteps = maxSteps
        self.maxBytes = maxBytes
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoCount: Int { undoStack.count }
    public var redoCount: Int { redoStack.count }
    public var byteCount: Int { (undoStack + redoStack).reduce(0) { $0 + $1.byteCount } }

    /// Añade un paso nuevo. Borra lo que se pudiera rehacer y descarta los pasos más antiguos si hace falta.
    public mutating func record(_ patch: UndoPatch) {
        redoStack.removeAll()
        undoStack.append(patch)
        var total = undoStack.reduce(0) { $0 + $1.byteCount }
        while undoStack.count > 1 && (undoStack.count > maxSteps || total > maxBytes) {
            total -= undoStack.removeFirst().byteCount
        }
    }

    /// Deshace el último paso. Devuelve la región modificada, o `nil` si no hay nada que deshacer.
    @discardableResult
    public mutating func undo(on canvas: inout Canvas) -> PixelRect? {
        guard let patch = undoStack.popLast() else { return nil }
        canvas.apply(patch, .undo)
        redoStack.append(patch)
        return patch.region
    }

    /// Rehace el último paso deshecho. Devuelve la región modificada, o `nil` si no hay nada que rehacer.
    @discardableResult
    public mutating func redo(on canvas: inout Canvas) -> PixelRect? {
        guard let patch = redoStack.popLast() else { return nil }
        canvas.apply(patch, .redo)
        undoStack.append(patch)
        return patch.region
    }

    public mutating func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
