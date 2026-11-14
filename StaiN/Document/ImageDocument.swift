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
    /// El formato preferido (Ajustes) va primero: es el que se propone al guardar.
    nonisolated static var writableContentTypes: [UTType] {
        let preferred = AppSettings.saveFormat
        return [preferred] + ImageCodec.supportedTypes.filter { $0 != preferred }
    }

    var canvas: StainKit.Canvas
    /// Última versión terminada de la imagen (sin trazos a medias). macOS la lee desde otro hilo al guardar.
    private let committedBitmap: Mutex<Bitmap>
    /// Avisa a la vista de qué región hay que redibujar.
    var canvasDidChange: ((PixelRect) -> Void)?
    var controller = ToolController()
    /// Paso de deshacer de la herramienta pendiente, que se actualiza hasta confirmarla.
    private var pendingUndo: UndoBox?
    private var undoSizes: [Int] = []
    static let maxUndoBytes = 512 * 1024 * 1024
    static let maxUndoSteps = 200
    var pendingActionName = ""
    /// `UndoManager` de la ventana (lo asigna la vista). Lo usan las órdenes de menú.
    weak var undoManager: UndoManager?

    /// Imagen para el próximo documento nuevo ("Pegar como documento nuevo").
    nonisolated static let pendingNewBitmap = Mutex<Bitmap?>(nil)

    nonisolated init() {
        if let pasted = Self.pendingNewBitmap.withLock({ value -> Bitmap? in
            defer { value = nil }
            return value
        }) {
            canvas = StainKit.Canvas(bitmap: pasted)
        } else {
            let size = AppSettings.newCanvasSize
            canvas = StainKit.Canvas(width: size.width, height: size.height)
        }
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

    // MARK: Herramientas

    /// Guías de la herramienta pendiente (tiradores de una forma editable…).
    var overlay: ToolOverlay? { controller.overlay }
    /// Hay una herramienta abierta (trazo en curso o esperando más clics).
    var hasActiveTool: Bool { controller.isActive }
    /// La herramienta quiere que se llame a `tick()` mientras el botón siga pulsado (aerógrafo).
    var toolRepeatsWhileHeld: Bool { controller.repeatsWhileHeld }
    /// Avisa a la vista de que las guías cambiaron.
    var overlayDidChange: (() -> Void)?

    func pointerDown(
        _ event: PointerEvent, actionName: String, undoManager: UndoManager?, makeTool: () -> any Tool
    ) {
        let colors = (canvas.primaryColor, canvas.secondaryColor)
        let previousName = pendingActionName
        if let patch = controller.pointerDown(event, canvas: &canvas, makeTool: makeTool) {
            finishEdit(patch, actionName: previousName, undoManager: undoManager)
        }
        pendingActionName = actionName
        toolDidChangeCanvas(colors: colors)
    }

    func pointerDragged(_ event: PointerEvent) {
        let colors = (canvas.primaryColor, canvas.secondaryColor)
        controller.pointerDragged(event, canvas: &canvas)
        toolDidChangeCanvas(colors: colors)
    }

    func pointerUp(_ event: PointerEvent, undoManager: UndoManager?) {
        if let patch = controller.pointerUp(event, canvas: &canvas) {
            finishEdit(patch, actionName: pendingActionName, undoManager: undoManager)
        }
        toolDidChangeCanvas(colors: nil)
    }

    func tick() {
        controller.tick(canvas: &canvas)
        flushChanges()
    }

    /// Confirma la herramienta pendiente (Intro, cambio de herramienta, clic fuera…).
    func commitTool(undoManager: UndoManager?) {
        guard controller.isActive else { return }
        if let patch = controller.commit(canvas: &canvas) {
            finishEdit(patch, actionName: pendingActionName, undoManager: undoManager)
        }
        toolDidChangeCanvas(colors: nil)
    }

    /// Descarta la herramienta en curso (Escape).
    func cancelTool() {
        guard controller.isActive else { return }
        controller.cancel(canvas: &canvas)
        if let box = pendingUndo {
            // La edición descartada no deja paso de deshacer.
            undoManager?.removeAllActions(withTarget: box)
            pendingUndo = nil
        }
        commit()
        toolDidChangeCanvas(colors: nil)
    }

    /// Rasteriza un cuadro de texto como un paso deshacible.
    func drawText(_ text: String, style: TextStyle, in rect: PixelRect, undoManager: UndoManager?) {
        commitTool(undoManager: undoManager)
        canvas.beginEdit()
        canvas.drawText(text, style: style, in: rect)
        if let patch = canvas.endEdit() {
            finishEdit(patch, actionName: "Texto", undoManager: undoManager)
        }
        flushChanges()
    }

    func finishEdit(_ patch: UndoPatch, actionName: String, undoManager: UndoManager?) {
        commit()
        if let box = pendingUndo {
            // La edición ya tenía su paso de deshacer desde que quedó pendiente: solo se actualiza.
            box.patch = patch
            pendingUndo = nil
            return
        }
        let box = UndoBox(patch: patch)
        noteUndoSize(patch.byteCount, undoManager: undoManager)
        registerUndo(box, applying: .undo, actionName: actionName, undoManager: undoManager)
    }

    func toolDidChangeCanvas(colors: (PaintColor, PaintColor)?) {
        flushChanges()
        if let colors { colorsMayHaveChanged(from: colors) }
        overlayDidChange?()
        if controller.isPending { syncPendingUndo() }
    }

    /// Una herramienta pendiente (forma editable, selección flotante…) que ya cambió la imagen cuenta como
    /// modificación: tiene su paso de deshacer (que se va actualizando) y se incluye al guardar.
    private func syncPendingUndo() {
        guard let patch = canvas.currentEditPatch() else { return }
        commit()
        if let box = pendingUndo {
            box.patch = patch
        } else {
            let box = UndoBox(patch: patch)
            pendingUndo = box
            noteUndoSize(patch.byteCount, undoManager: undoManager)
            registerUndo(box, applying: .undo, actionName: pendingActionName, undoManager: undoManager)
        }
    }

    /// Mantiene el historial por debajo de `maxUndoBytes` ajustando cuántos pasos guarda el `UndoManager`.
    func noteUndoSize(_ bytes: Int, undoManager: UndoManager?) {
        undoSizes.append(bytes)
        if undoSizes.count > 1000 { undoSizes.removeFirst(undoSizes.count - 1000) }
        var total = 0
        var levels = 0
        for size in undoSizes.reversed() {
            total += size
            if total > Self.maxUndoBytes && levels > 0 { break }
            levels += 1
        }
        undoManager?.levelsOfUndo = min(levels, Self.maxUndoSteps)
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
    /// Registra cómo deshacer el parche de `box`. Al deshacer, se registra a su vez el rehacer.
    private func registerUndo(
        _ box: UndoBox, applying direction: UndoPatch.Direction, actionName: String, undoManager: UndoManager?
    ) {
        guard let undoManager else { return }
        // NSUndoManager no retiene el objetivo: la acción guarda la caja para que siga viva.
        undoManager.registerUndo(withTarget: box) { [weak self, box] _ in
            guard let self, let patch = box.patch else { return }
            self.cancelTool()
            self.canvas.apply(patch, direction)
            self.commit()
            self.flushChanges()
            self.registerUndo(
                box, applying: direction == .undo ? .redo : .undo, actionName: actionName, undoManager: undoManager)
        }
        undoManager.setActionName(actionName)
    }

    func commit() {
        let bitmap = canvas.bitmap
        committedBitmap.withLock { $0 = bitmap }
    }

    func flushChanges() {
        let dirty = canvas.takeDirtyRect()
        if !dirty.isEmpty { canvasDidChange?(dirty) }
    }
}

/// Contenedor mutable del parche de un paso de deshacer (una forma editable lo va cambiando).
final class UndoBox {
    var patch: UndoPatch?

    init(patch: UndoPatch?) {
        self.patch = patch
    }
}
