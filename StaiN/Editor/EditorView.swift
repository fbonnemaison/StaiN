import AppKit
import StainKit
import SwiftUI
import UniformTypeIdentifiers

/// Ventana de edición: panel de herramientas, lienzo y barra de estado.
struct EditorView: View {
    @ObservedObject var document: ImageDocument
    @State private var editor = EditorState()
    @Environment(\.undoManager) private var undoManager
    @Environment(\.openDocument) private var openDocument

    private var modeSummary: String {
        var parts: [String] = []
        if editor.pixelMode { parts.append("Modo pixel") }
        if editor.symmetry.contains(.horizontal) { parts.append("Simetría ↔") }
        if editor.symmetry.contains(.vertical) { parts.append("Simetría ↕") }
        return parts.joined(separator: " · ")
    }

    /// Las imágenes pequeñas (pixel art) se abren ampliadas.
    private func zoomSmallImages() {
        let side = Double(max(document.width, document.height))
        guard side <= 128 else { return }
        editor.zoom = EditorState.zoomLevels.last { $0 * side <= 480 } ?? 1
        editor.pixelMode = true
    }

    var body: some View {
        HStack(spacing: 0) {
            ToolPanel(editor: editor)
            Divider()
            VStack(spacing: 0) {
                if editor.tool == .text {
                    TextOptionsBar(editor: editor)
                    Divider()
                }
                CanvasRepresentable(
                    document: document, editor: editor, zoom: editor.zoom, tool: editor.tool,
                    imageSize: CGSize(width: document.width, height: document.height),
                    textStyle: editor.textStyle(primary: document.primaryColor, secondary: document.secondaryColor),
                    showsGrid: editor.showsGrid, fitRequest: editor.fitRequest, undoManager: undoManager)
                Divider()
                PaletteBar(
                    primary: document.primaryColor, secondary: document.secondaryColor,
                    setColors: { document.setColors(primary: $0, secondary: $1) },
                    swapColors: { document.swapColors() })
                Divider()
                StatusBar(editor: editor, width: document.width, height: document.height)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .onChange(of: editor.transparentSelection) { _, value in document.setTransparentSelection(value) }
        .sheet(item: $editor.activeSheet) { sheet in
            switch sheet {
            case .resize: ResizeSheet(document: document)
            case .canvasSize: CanvasSizeSheet(document: document)
            case .filter(let kind): FilterSheet(kind: kind, document: document)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if editor.pixelMode || !editor.symmetry.isEmpty {
                    Text(modeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ControlGroup {
                    Button(editor.undoTitle, systemImage: "arrow.uturn.backward") { UndoActions.undo() }
                        .disabled(!editor.canUndo)
                    Button(editor.redoTitle, systemImage: "arrow.uturn.forward") { UndoActions.redo() }
                        .disabled(!editor.canRedo)
                }
                .help("Deshacer o rehacer (⌘Z / ⇧⌘Z)")
                Button("Ajustar a la ventana", systemImage: "arrow.up.left.and.arrow.down.right") { editor.zoomToFit() }
                    .help("Ajustar a la ventana (⌘9)")
                Button("Copiar imagen", systemImage: "doc.on.clipboard") { Clipboard.write(document.canvas.bitmap) }
                    .help("Copiar toda la imagen al portapapeles (⇧⌘C)")
                Button("Compartir", systemImage: "square.and.arrow.up") {
                    ImageExport.share(document.canvas.bitmap, from: NSApp.keyWindow)
                }
                .help("Compartir la imagen")
            }
        }
        .onAppear(perform: zoomSmallImages)
        .focusedSceneValue(\.editor, editor)
        .focusedSceneValue(\.imageDocument, document)
        // Soltar archivos de imagen sobre la ventana los abre como documentos nuevos.
        .dropDestination(for: URL.self) { urls, _ in
            let images = urls.filter { url in
                guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
                return ImageCodec.supportedTypes.contains { type.conforms(to: $0) }
            }
            for url in images {
                Task { try? await openDocument(at: url) }
            }
            return !images.isEmpty
        }
    }
}

/// Barra inferior: posición del cursor, tamaño de la imagen y zoom.
private struct StatusBar: View {
    @Bindable var editor: EditorState
    let width: Int
    let height: Int

    var body: some View {
        HStack(spacing: 16) {
            Label(cursorText, systemImage: "cursorarrow")
                .frame(minWidth: 110, alignment: .leading)
            if let selection = editor.selectionSize {
                Label("\(selection.x) × \(selection.y) px", systemImage: "rectangle.dashed")
                    .accessibilityIdentifier("selectionSize")
            }
            Label("\(width) × \(height) px", systemImage: "photo")
                .accessibilityIdentifier("imageSize")
            Spacer()
            Button("Alejar", systemImage: "minus.magnifyingglass") { editor.zoomOut() }
                .disabled(!editor.canZoomOut)
            Menu(Self.format(editor.zoom)) {
                ForEach(EditorState.zoomLevels, id: \.self) { level in
                    Button(Self.format(level)) { editor.zoom = level }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityIdentifier("zoomLevel")
            Button("Acercar", systemImage: "plus.magnifyingglass") { editor.zoomIn() }
                .disabled(!editor.canZoomIn)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderless)
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var cursorText: String {
        guard let cursor = editor.cursor else { return "—" }
        return "\(cursor.x), \(cursor.y) px"
    }

    static func format(_ zoom: Double) -> String {
        zoom.formatted(.percent.precision(.fractionLength(0)))
    }
}
