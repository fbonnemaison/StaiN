import CoreGraphics

/// Estado editable de una imagen: el bitmap, los colores activos y lo que ha cambiado.
///
/// Las herramientas solo modifican el bitmap a través de `Canvas`, que acumula la región sucia
/// (para redibujar solo eso) y agrupa cada trazo en una edición deshacible.
public struct Canvas: Sendable {
    public internal(set) var bitmap: Bitmap
    public var primaryColor: PaintColor = .black
    public var secondaryColor: PaintColor = .white

    /// Región cambiada desde la última llamada a `takeDirtyRect()`. La vista la usa para redibujar.
    public private(set) var dirtyRect: PixelRect = .zero

    /// Copia del bitmap al empezar la edición en curso (copy-on-write: no cuesta nada hasta que se pinta).
    private var editSnapshot: Bitmap?
    /// Región cambiada durante la edición en curso.
    private var editRect: PixelRect = .zero

    public init(bitmap: Bitmap) {
        self.bitmap = bitmap
    }

    public init(width: Int, height: Int, background: PaintColor = .white) {
        self.init(bitmap: Bitmap(width: width, height: height, fill: background))
    }

    /// Color correspondiente a un botón: primario para el izquierdo, secundario para el derecho.
    public func color(for button: PointerButton) -> PaintColor {
        button == .primary ? primaryColor : secondaryColor
    }

    public mutating func swapColors() {
        swap(&primaryColor, &secondaryColor)
    }

    // MARK: Dibujo

    /// Marca una región como modificada (se recorta a los límites de la imagen).
    public mutating func markDirty(_ rect: PixelRect) {
        let rect = rect.intersection(bitmap.bounds)
        guard !rect.isEmpty else { return }
        dirtyRect = dirtyRect.union(rect)
        if editSnapshot != nil { editRect = editRect.union(rect) }
    }

    /// Devuelve la región sucia acumulada y la reinicia.
    public mutating func takeDirtyRect() -> PixelRect {
        defer { dirtyRect = .zero }
        return dirtyRect
    }

    /// Dibuja con Core Graphics. Solo se pinta dentro de `rect`, que queda marcado como sucio.
    public mutating func draw(in rect: PixelRect, antialiased: Bool = true, _ body: (CGContext) -> Void) {
        let rect = rect.intersection(bitmap.bounds)
        guard !rect.isEmpty else { return }
        bitmap.draw(clippedTo: rect, antialiased: antialiased, body)
        markDirty(rect)
    }

    /// Cambia un píxel. Las coordenadas fuera de la imagen se ignoran.
    public mutating func setPixel(x: Int, y: Int, to color: PaintColor) {
        guard bitmap.contains(x: x, y: y) else { return }
        bitmap[x, y] = color
        markDirty(PixelRect(x: x, y: y, width: 1, height: 1))
    }

    /// Rellena el área contigua de color parecido al de `(x, y)`.
    public mutating func floodFill(x: Int, y: Int, with color: PaintColor, tolerance: UInt8 = 0) {
        markDirty(bitmap.floodFill(x: x, y: y, with: color, tolerance: tolerance))
    }

    /// Acceso al bitmap para las primitivas de dibujo del módulo. Quien llama marca la región sucia.
    mutating func bitmapStamp(_ mask: BrushMask, _ x: Int, _ y: Int, _ color: PaintColor) -> PixelRect {
        bitmap.stamp(mask, atX: x, y: y, color: color)
    }

    /// Copia `other` sobre la imagen en `rect.origin` y marca la región como sucia.
    mutating func replaceRegion(_ rect: PixelRect, with other: Bitmap) {
        markDirty(bitmap.replace(with: other, atX: rect.x, y: rect.y))
    }

    /// Color del píxel, o `nil` si está fuera de la imagen.
    public func color(atX x: Int, y: Int) -> PaintColor? {
        bitmap.contains(x: x, y: y) ? bitmap[x, y] : nil
    }

    /// Sustituye el bitmap completo (p. ej. al cambiar el tamaño). Toda la imagen queda sucia.
    public mutating func replaceBitmap(_ newBitmap: Bitmap) {
        bitmap = newBitmap
        dirtyRect = newBitmap.bounds
    }

    // MARK: Ediciones deshacibles

    public var isEditing: Bool { editSnapshot != nil }

    /// Empieza una edición: todo lo que se pinte hasta `endEdit()` forma un único paso de deshacer.
    public mutating func beginEdit() {
        precondition(editSnapshot == nil, "beginEdit() called twice")
        editSnapshot = bitmap
        editRect = .zero
    }

    /// Termina la edición y devuelve el parche para el historial, o `nil` si no cambió nada.
    public mutating func endEdit() -> UndoPatch? {
        guard let snapshot = editSnapshot else { preconditionFailure("endEdit() without beginEdit()") }
        editSnapshot = nil
        defer { editRect = .zero }
        return UndoPatch(before: snapshot, after: bitmap, region: editRect)
    }

    /// Parche de la edición en curso tal como está ahora, sin terminarla (para herramientas pendientes).
    public func currentEditPatch() -> UndoPatch? {
        guard let snapshot = editSnapshot else { return nil }
        return UndoPatch(before: snapshot, after: bitmap, region: editRect)
    }

    /// Descarta la edición en curso y restaura la imagen como estaba al empezar.
    public mutating func cancelEdit() {
        guard let snapshot = editSnapshot else { return }
        if let original = snapshot.cropped(to: editRect) {
            bitmap.replace(with: original, atX: editRect.x, y: editRect.y)
        }
        markDirty(editRect)
        editSnapshot = nil
        editRect = .zero
    }

    /// Devuelve la imagen al estado del principio de la edición, sin terminarla.
    /// Sirve para herramientas con vista previa (línea, formas): se borra la previa y se vuelve a dibujar.
    public mutating func revertToEditStart() {
        guard let snapshot = editSnapshot, !editRect.isEmpty else { return }
        if let original = snapshot.cropped(to: editRect) {
            bitmap.replace(with: original, atX: editRect.x, y: editRect.y)
        }
        dirtyRect = dirtyRect.union(editRect)
        editRect = .zero
    }

    /// Aplica un paso del historial (deshacer o rehacer).
    public mutating func apply(_ patch: UndoPatch, _ direction: UndoPatch.Direction) {
        precondition(editSnapshot == nil, "Cannot undo while an edit is in progress")
        markDirty(patch.apply(direction, to: &bitmap))
    }
}
