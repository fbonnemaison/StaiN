import SwiftUI

extension FocusedValues {
    @Entry var editor: EditorState?
    @Entry var imageDocument: ImageDocument?
}

/// Menús que actúan sobre la ventana activa: zoom e imprimir.
struct EditorCommands: Commands {
    @FocusedValue(\.editor) private var editor
    @FocusedValue(\.imageDocument) private var document

    var body: some Commands {
        CommandGroup(replacing: .printItem) {
            Button("Imprimir…") {
                if let document { ImagePrinter.print(document.canvas.bitmap) }
            }
            .keyboardShortcut("p")
            .disabled(document == nil)
        }

        CommandGroup(before: .toolbar) {
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
