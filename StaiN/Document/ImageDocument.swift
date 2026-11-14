import StainKit
import SwiftUI
import Synchronization
import UniformTypeIdentifiers

/// Documento de imagen. Guarda el lienzo y conecta cada trazo con el `UndoManager` de la ventana.
///
/// Registrar el deshacer es también lo que marca el documento como modificado, y con ello
/// funcionan el aviso de cambios sin guardar, el autoguardado y las versiones de macOS.
@MainActor
final class ImageDocument: ReferenceFileDocument {
    nonisolated static var readableContentTypes: [UTType] { ImageCodec.supportedTypes }
    nonisolated static var writableContentTypes: [UTType] { ImageCodec.supportedTypes }

    private(set) var canvas: StainKit.Canvas
    /// Última versión terminada de la imagen (sin trazos a medias). macOS la lee desde otro hilo al guardar.
    private let committedBitmap: Mutex<Bitmap>
    /// Avisa a la vista de qué región hay que redibujar.
    var canvasDidChange: ((PixelRect) -> Void)?
    private var activeTool: (any Tool)?

    nonisolated init() {
        let size = AppSettings.newCanvasSize
        canvas = StainKit.Canvas(width: size.width, height: size.height)
        committedBitmap = Mutex(canvas.bitmap)
    }

    init(bitmap: Bitmap) {
        canvas = StainKit.Canvas(bitmap: bitmap)
        committedBitmap = Mutex(bitmap)
    }

    nonisolated required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let bitmap = try ImageCodec.decode(data)
        canvas = StainKit.Canvas(bitmap: bitmap)
        committedBitmap = Mutex(bitmap)
    }

    /// Puede llamarse desde cualquier hilo (NSDocument guarda en segundo plano).
    nonisolated func snapshot(contentType: UTType) throws -> Bitmap {
        committedBitmap.withLock { $0 }
    }

    nonisolated func fileWrapper(snapshot: Bitmap, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try ImageCodec.encode(snapshot, as: configuration.contentType, quality: AppSettings.jpegQuality)
        return FileWrapper(regularFileWithContents: data)
    }

    var width: Int { canvas.bitmap.width }
    var height: Int { canvas.bitmap.height }

    // MARK: Trazos

    var isStroking: Bool { activeTool != nil }

    func beginStroke(with tool: any Tool, _ event: PointerEvent) {
        if activeTool != nil { cancelStroke() }
        var tool = tool
        let colors = (canvas.primaryColor, canvas.secondaryColor)
        canvas.beginEdit()
        tool.begin(event, on: &canvas)
        activeTool = tool
        flushChanges()
        colorsMayHaveChanged(from: colors)
    }

    func continueStroke(_ event: PointerEvent) {
        guard var tool = activeTool else { return }
        let colors = (canvas.primaryColor, canvas.secondaryColor)
        tool.drag(event, on: &canvas)
        activeTool = tool
        flushChanges()
        colorsMayHaveChanged(from: colors)
    }

    func endStroke(_ event: PointerEvent, actionName: String, undoManager: UndoManager?) {
        guard var tool = activeTool else { return }
        tool.end(event, on: &canvas)
        activeTool = nil
        if let patch = canvas.endEdit() {
            commit()
            registerUndo(of: patch, applying: .undo, actionName: actionName, undoManager: undoManager)
        }
        flushChanges()
    }

    func cancelStroke() {
        guard var tool = activeTool else { return }
        tool.cancel(on: &canvas)
        activeTool = nil
        canvas.cancelEdit()
        flushChanges()
    }

    var primaryColor: PaintColor { canvas.primaryColor }
    var secondaryColor: PaintColor { canvas.secondaryColor }

    func setColors(primary: PaintColor? = nil, secondary: PaintColor? = nil) {
        let old = (canvas.primaryColor, canvas.secondaryColor)
        if let primary { canvas.primaryColor = primary }
        if let secondary { canvas.secondaryColor = secondary }
        colorsMayHaveChanged(from: old)
    }

    func swapColors() {
        canvas.swapColors()
        objectWillChange.send()
    }

    /// Refresca la interfaz y guarda en "recientes" los colores nuevos (paleta, selector o cuentagotas).
    private func colorsMayHaveChanged(from old: (PaintColor, PaintColor)) {
        let new = (canvas.primaryColor, canvas.secondaryColor)
        guard new != old else { return }
        objectWillChange.send()
        if new.0 != old.0 { PaletteStore.shared.noteUsed(new.0) }
        if new.1 != old.1 { PaletteStore.shared.noteUsed(new.1) }
    }

    // MARK: Deshacer

    /// Registra cómo deshacer `patch`. Al deshacer, se registra a su vez el rehacer.
    private func registerUndo(
        of patch: UndoPatch, applying direction: UndoPatch.Direction, actionName: String, undoManager: UndoManager?
    ) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { document in
            if document.isStroking { document.cancelStroke() }
            document.canvas.apply(patch, direction)
            document.commit()
            document.flushChanges()
            document.registerUndo(
                of: patch, applying: direction == .undo ? .redo : .undo, actionName: actionName,
                undoManager: undoManager)
        }
        undoManager.setActionName(actionName)
    }

    /// Publica el estado actual para guardar. Solo al terminar una edición: copiar a mitad de un trazo
    /// obligaría a duplicar la imagen entera en el siguiente píxel pintado (copy-on-write).
    private func commit() {
        let bitmap = canvas.bitmap
        committedBitmap.withLock { $0 = bitmap }
    }

    private func flushChanges() {
        let dirty = canvas.takeDirtyRect()
        if !dirty.isEmpty { canvasDidChange?(dirty) }
    }
}
