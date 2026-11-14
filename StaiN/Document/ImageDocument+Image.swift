import StainKit
import SwiftUI

/// Selección, portapapeles y operaciones de imagen (menús Edición e Imagen).
extension ImageDocument {
    // MARK: Selección

    var selection: SelectionTool? { controller.tool as? SelectionTool }
    var hasSelection: Bool { selection?.hasSelection ?? false }

    /// Píxeles seleccionados tal como se ven, o `nil` si no hay selección.
    var selectedPixels: Bitmap? { selection?.selectedPixels(in: canvas) }

    func selectAll(transparent: Bool) {
        install(
            SelectionTool(selecting: canvas.bitmap.bounds, isTransparent: transparent, background: secondaryColor),
            actionName: "Seleccionar todo")
    }

    /// Pega una imagen como selección flotante en `(x, y)`.
    func paste(_ bitmap: Bitmap, atX x: Int, y: Int, transparent: Bool) {
        install(
            SelectionTool(pasting: bitmap, atX: x, y: y, isTransparent: transparent, background: secondaryColor),
            actionName: "Pegar")
        controller.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in tool.nudge(dx: 0, dy: 0, on: &canvas) }
        toolDidChangeCanvas(colors: nil)
    }

    /// Borra lo seleccionado (queda el color secundario) y quita la selección.
    func deleteSelection() {
        guard hasSelection else { return }
        pendingActionName = "Eliminar"
        controller.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in tool.deleteSelection(on: &canvas) }
        commitTool(undoManager: undoManager)
    }

    func nudgeSelection(dx: Int, dy: Int) {
        guard hasSelection else { return }
        controller.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in tool.nudge(dx: dx, dy: dy, on: &canvas)
        }
        toolDidChangeCanvas(colors: nil)
    }

    func setTransparentSelection(_ value: Bool) {
        controller.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in
            tool.setTransparent(value, on: &canvas)
        }
        toolDidChangeCanvas(colors: nil)
    }

    private func install(_ tool: SelectionTool, actionName: String) {
        if let patch = controller.install(tool, canvas: &canvas) {
            finishEdit(patch, actionName: pendingActionName, undoManager: undoManager)
        }
        pendingActionName = actionName
        toolDidChangeCanvas(colors: nil)
    }

    // MARK: Transformaciones

    /// Aplica la transformación a la selección si la hay; si no, a toda la imagen.
    func transform(_ name: String, _ change: @escaping (Bitmap) -> Bitmap) {
        if hasSelection {
            pendingActionName = name
            controller.modify(SelectionTool.self, canvas: &canvas) { tool, canvas in
                tool.transform(on: &canvas, change)
            }
            toolDidChangeCanvas(colors: nil)
        } else {
            replaceImage(with: change(canvas.bitmap), actionName: name)
        }
    }

    /// Recorta la imagen a la selección.
    func cropToSelection() {
        guard let pixels = selectedPixels else { return }
        commitTool(undoManager: undoManager)
        replaceImage(with: pixels, actionName: "Recortar")
    }

    /// Sustituye la imagen entera (puede cambiar de tamaño) como un paso deshacible.
    func replaceImage(with newBitmap: Bitmap, actionName: String) {
        commitTool(undoManager: undoManager)
        let old = canvas.bitmap
        guard old != newBitmap else { return }
        swapImage(old: old, new: newBitmap, actionName: actionName)
    }

    private func swapImage(old: Bitmap, new: Bitmap, actionName: String) {
        cancelTool()
        let sizeChanged = old.width != new.width || old.height != new.height
        if sizeChanged { objectWillChange.send() }
        canvas.replaceBitmap(new)
        commit()
        flushChanges()
        overlayDidChange?()
        guard let undoManager else { return }
        noteUndoSize(old.byteCount + new.byteCount, undoManager: undoManager)
        undoManager.registerUndo(withTarget: self) { document in
            document.swapImage(old: new, new: old, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }
}
