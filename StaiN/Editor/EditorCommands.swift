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

    private func symmetryBinding(_ axis: Symmetry) -> Binding<Bool> {
        Binding(
            get: { editor?.symmetry.contains(axis) ?? false },
            set: { on in
                if on { editor?.symmetry.insert(axis) } else { editor?.symmetry.remove(axis) }
            })
    }

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

        // Menú Deshacer con el nombre de la acción ("Deshacer Lápiz"). Se envía `undo:` a la cadena de
        // respondedores para que también funcione dentro de los cuadros de texto.
        CommandGroup(replacing: .undoRedo) {
            Button(editor?.undoTitle ?? String(localized: "Deshacer")) { UndoActions.undo() }
                .keyboardShortcut("z")
                .disabled(editor.map { !$0.canUndo } ?? false)
            Button(editor?.redoTitle ?? String(localized: "Rehacer")) { UndoActions.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(editor.map { !$0.canRedo } ?? false)
        }

        CommandGroup(after: .newItem) {
            Button("Nuevo desde el portapapeles") {
                if let bitmap = Clipboard.readBitmap() { ImageExport.openAsNewDocument(bitmap) } else { NSSound.beep() }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Nueva captura de pantalla…") { ScreenCapturer.shared.start() }
                .keyboardShortcut("5", modifiers: [.command, .option])
            Menu("Nuevo pixel art") {
                ForEach([16, 32, 64], id: \.self) { side in
                    Button("\(side) × \(side)") {
                        ImageExport.openAsNewDocument(Bitmap(width: side, height: side, fill: .clear))
                    }
                }
            }
        }

        CommandGroup(after: .importExport) {
            Menu("Exportar a escala") {
                ForEach([2, 4, 8], id: \.self) { factor in
                    Button("PNG ×\(factor)…") {
                        if let document {
                            ImageExport.exportScaled(
                                document.canvas.bitmap, factor: factor, suggestedName: String(localized: "Imagen"))
                        }
                    }
                }
            }
            .disabled(document == nil)
        }

        CommandMenu("Filtros") {
            ForEach(FilterKind.allCases) { kind in
                Button(kind.parameters.isEmpty ? kind.title : "\(kind.title)…") {
                    if kind.parameters.isEmpty, let document {
                        document.transform(kind.title) { kind.filter([:]).apply(to: $0) }
                    } else {
                        editor?.activeSheet = .filter(kind)
                    }
                }
                .disabled(editor == nil)
            }
        }

        CommandGroup(after: .pasteboard) {
            Button("Copiar imagen") {
                if let document { Clipboard.write(document.canvas.bitmap) }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(document == nil)
            Button("Pegar como documento nuevo") {
                guard let bitmap = Clipboard.readBitmap() else { return }
                ImageDocument.pendingNewBitmap.withLock { $0 = bitmap }
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }

        CommandMenu("Imagen") {
            Group {
                Button("Voltear horizontalmente") {
                    document?.transform(String(localized: "Voltear")) { $0.flippedHorizontally() }
                }
                Button("Voltear verticalmente") {
                    document?.transform(String(localized: "Voltear")) { $0.flippedVertically() }
                }
                Button("Girar 90° a la derecha") {
                    document?.transform(String(localized: "Girar")) { $0.rotated(quarterTurns: 1) }
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
                Button("Girar 90° a la izquierda") {
                    document?.transform(String(localized: "Girar")) { $0.rotated(quarterTurns: -1) }
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
                Button("Girar 180°") { document?.transform(String(localized: "Girar")) { $0.rotated(quarterTurns: 2) } }
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
            Button(String(localized: "Invertir colores")) {
                document?.transform(String(localized: "Invertir colores")) { $0.inverted() }
            }
            .keyboardShortcut("i")
            .disabled(document == nil)
            Button(String(localized: "Borrar imagen")) {
                guard let document else { return }
                if document.hasSelection {
                    document.deleteSelection()
                } else {
                    document.replaceImage(
                        with: Bitmap(width: document.width, height: document.height, fill: document.secondaryColor),
                        actionName: String(localized: "Borrar imagen"))
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(document == nil)
            Divider()
            Toggle("Selección transparente", isOn: transparentBinding)
                .disabled(editor == nil)
        }

        CommandGroup(before: .toolbar) {
            Button(
                editor?.showsPixelGrid == true
                    ? String(localized: "Ocultar cuadrícula de píxeles")
                    : String(localized: "Mostrar cuadrícula de píxeles")
            ) {
                editor?.showsPixelGrid.toggle()
            }
            .disabled(editor == nil)
            Button(
                editor?.pixelMode == true
                    ? String(localized: "Desactivar modo pixel") : String(localized: "Activar modo pixel")
            ) {
                editor?.pixelMode.toggle()
            }
            .disabled(editor == nil)
            Menu("Simetría") {
                Toggle("Horizontal (izquierda ↔ derecha)", isOn: symmetryBinding(.horizontal))
                Toggle("Vertical (arriba ↕ abajo)", isOn: symmetryBinding(.vertical))
            }
            .disabled(editor == nil)
            Divider()
            Button(
                editor?.showsGrid == true
                    ? String(localized: "Ocultar cuadrícula") : String(localized: "Mostrar cuadrícula")
            ) {
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
            Button("Ajustar a la ventana") { editor?.zoomToFit() }
                .keyboardShortcut("9")
                .disabled(editor == nil)
            Divider()
        }
    }
}

/// Envía deshacer/rehacer al primer respondedor (el lienzo, un cuadro de texto, un campo de Ajustes…).
@MainActor
enum UndoActions {
    static func undo() { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
    static func redo() { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
}
