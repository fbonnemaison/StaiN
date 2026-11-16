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
        if editor.pixelMode { parts.append(String(localized: "Modo pixel")) }
        if editor.symmetry.contains(.horizontal) { parts.append(String(localized: "Simetría ↔")) }
        if editor.symmetry.contains(.vertical) { parts.append(String(localized: "Simetría ↕")) }
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
            if editor.showsToolPanel {
                ToolPanel(editor: editor)
                    .transition(.move(edge: .leading))
                Divider()
            }
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editor de imagen")
        .onChange(of: editor.transparentSelection) { _, value in document.setTransparentSelection(value) }
        .sheet(item: $editor.activeSheet) { sheet in
            switch sheet {
            case .resize: ResizeSheet(document: document)
            case .canvasSize: CanvasSizeSheet(document: document)
            case .filter(let kind): FilterSheet(kind: kind, document: document)
            }
        }
        // El título propio (con el popover para nombrar y guardar) sustituye al de la ventana.
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(
                    editor.showsToolPanel ? "Ocultar herramientas" : "Mostrar herramientas",
                    systemImage: "sidebar.left"
                ) {
                    withAnimation(.snappy(duration: 0.2)) { editor.showsToolPanel.toggle() }
                }
                .help(editor.showsToolPanel ? "Ocultar el panel de herramientas (⌃⌘S)" : "Mostrar el panel de herramientas (⌃⌘S)")
                .accessibilityIdentifier("toolPanelToggle")
            }
            ToolbarItem(placement: .navigation) {
                DocumentTitleButton()
            }
            .sharedBackgroundVisibility(.hidden)
            // Empuja el resto de botones al borde derecho, lejos del título.
            ToolbarSpacer(.flexible)
            ToolbarItemGroup {
                if editor.pixelMode || !editor.symmetry.isEmpty {
                    Text(modeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // Tres burbujas separadas: deshacer, portapapeles y vista/compartir.
            ToolbarItemGroup {
                Button(editor.undoTitle, systemImage: "arrow.uturn.backward") { UndoActions.undo() }
                    .disabled(!editor.canUndo)
                    .help("Deshacer (⌘Z)")
                Button(editor.redoTitle, systemImage: "arrow.uturn.forward") { UndoActions.redo() }
                    .disabled(!editor.canRedo)
                    .help("Rehacer (⇧⌘Z)")
            }
            ToolbarSpacer(.fixed)
            ToolbarItemGroup {
                Button("Cortar", systemImage: "scissors") { EditActions.cut() }
                    .help("Cortar la selección (⌘X)")
                Button("Copiar", systemImage: "doc.on.doc") { EditActions.copy() }
                    .help("Copiar la selección, o toda la imagen si no hay selección (⌘C)")
                Button("Pegar", systemImage: "clipboard") { EditActions.paste() }
                    .help("Pegar desde el portapapeles (⌘V)")
            }
            ToolbarSpacer(.fixed)
            ToolbarItemGroup {
                Toggle("Redimensionar lienzo", systemImage: "crop", isOn: $editor.showsCanvasHandles)
                    .help("Mostrar u ocultar los puntos de control para redimensionar el lienzo con el ratón (⌥⌘E)")
                    .accessibilityIdentifier("canvasHandlesToggle")
                Button("Ajustar a la ventana", systemImage: "arrow.up.left.and.arrow.down.right") { editor.zoomToFit() }
                    .help("Ajustar a la ventana (⌘9)")
                // ShareLink abre el menú Compartir anclado al propio botón de la barra.
                ShareLink(
                    item: ShareableImage(bitmap: document.canvas.bitmap, name: "StaiN"),
                    preview: SharePreview("StaiN", image: Image(nsImage: ShareIcon.image))
                ) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
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
            Picker("Nivel de zoom", selection: $editor.zoom) {
                // Con el pellizco el zoom puede quedar entre dos niveles: se muestra tal cual.
                if !EditorState.zoomLevels.contains(editor.zoom) {
                    Text(Self.format(editor.zoom)).tag(editor.zoom)
                }
                ForEach(EditorState.zoomLevels, id: \.self) { level in
                    Text(Self.format(level)).tag(level)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            .accessibilityIdentifier("zoomLevel")
            Button("Acercar", systemImage: "plus.magnifyingglass") { editor.zoomIn() }
                .disabled(!editor.canZoomIn)
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderless)
        .font(.callout.monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var cursorText: String {
        guard let cursor = editor.cursor else { return String(localized: "Fuera del lienzo") }
        return "\(cursor.x), \(cursor.y) px"
    }

    static func format(_ zoom: Double) -> String {
        zoom.formatted(.percent.precision(.fractionLength(0)))
    }
}
