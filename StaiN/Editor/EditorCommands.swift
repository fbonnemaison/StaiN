import AppKit
import StainKit
import SwiftUI

extension FocusedValues {
    @Entry var editor: EditorState?
    @Entry var imageDocument: ImageDocument?
}

/// Menús que actúan sobre la ventana activa: Edición, Imagen, Visualización e imprimir.
struct EditorCommands: Commands {
    @FocusedValue(\.editor) private var editor
    @FocusedValue(\.imageDocument) private var document

    private var transparentBinding: Binding<Bool> {
        Binding(get: { editor?.transparentSelection ?? false }, set: { editor?.transparentSelection = $0 })
    }

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Imprimir…") {
                if let document { ImagePrinter.print(document.canvas.bitmap) }
            }
            .keyboardShortcut("p")
            .disabled(document == nil)
        }

        CommandGroup(after: .pasteboard) {
            Button("Pegar como documento nuevo") {
                guard let bitmap = Clipboard.readBitmap() else { return }
                ImageDocument.pendingNewBitmap.withLock { $0 = bitmap }
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }

        CommandMenu("Imagen") {
            Group {
                Button("Voltear horizontalmente") { document?.transform("Voltear") { $0.flippedHorizontally() } }
                Button("Voltear verticalmente") { document?.transform("Voltear") { $0.flippedVertically() } }
                Button("Girar 90° a la derecha") { document?.transform("Girar") { $0.rotated(quarterTurns: 1) } }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                Button("Girar 90° a la izquierda") { document?.transform("Girar") { $0.rotated(quarterTurns: -1) } }
                    .keyboardShortcut("l", modifiers: [.command, .option])
                Button("Girar 180°") { document?.transform("Girar") { $0.rotated(quarterTurns: 2) } }
            }
            .disabled(document == nil)
            Divider()
            Button("Cambiar tamaño e inclinar…") { editor?.activeSheet = .resize }
                .keyboardShortcut("r")
                .disabled(editor == nil)
            Button("Tamaño del lienzo…") { editor?.activeSheet = .canvasSize }
                .keyboardShortcut("e")
                .disabled(editor == nil)
            Button("Recortar a la selección") { document?.cropToSelection() }
                .keyboardShortcut("k")
                .disabled(editor?.selectionSize == nil)
            Divider()
            Button("Invertir colores") { document?.transform("Invertir colores") { $0.inverted() } }
                .keyboardShortcut("i")
                .disabled(document == nil)
            Button("Borrar imagen") {
                guard let document else { return }
                if document.hasSelection {
                    document.deleteSelection()
                } else {
                    document.replaceImage(
                        with: Bitmap(width: document.width, height: document.height, fill: document.secondaryColor),
                        actionName: "Borrar imagen")
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(document == nil)
            Divider()
            Toggle("Selección transparente", isOn: transparentBinding)
                .disabled(editor == nil)
        }

        CommandGroup(before: .toolbar) {
            Button(editor?.showsGrid == true ? "Ocultar cuadrícula" : "Mostrar cuadrícula") {
                editor?.showsGrid.toggle()
            }
            .keyboardShortcut("g")  // como Ctrl+G en Paint
            .disabled(editor == nil)
            Button("Acercar") { editor?.zoomIn() }
                .keyboardShortcut("+")
                .disabled(!(editor?.canZoomIn ?? false))
            Button("Alejar") { editor?.zoomOut() }
                .keyboardShortcut("-")
                .disabled(!(editor?.canZoomOut ?? false))
            Button("Tamaño real") { editor?.actualSize() }
                .keyboardShortcut("0")
                .disabled(editor == nil)
            Divider()
        }
    }
}
