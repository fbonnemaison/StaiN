import AppKit
import StainKit
import SwiftUI
import UniformTypeIdentifiers

/// Título del documento en la barra de la ventana. Al pulsarlo se abre un popover para darle nombre,
/// formato y carpeta, y guardarlo ahí.
///
/// macOS solo ofrece ese popover a las apps con autoguardado en el sitio, que StaiN desactiva para
/// preguntar antes de cerrar (ver `ClassicSaving`); por eso se reproduce aquí.
struct DocumentTitleButton: View {
    @State private var model = DocumentTitleModel()
    @State private var showsPopover = false

    var body: some View {
        Button {
            model.prepareDraft()
            showsPopover = true
        } label: {
            HStack(spacing: 5) {
                Image(nsImage: model.icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(model.title)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Nombrar y guardar el documento")
        .accessibilityLabel(Text("Documento \(model.title)"))
        .accessibilityIdentifier("documentTitle")
        .background(WindowReader { model.attach(to: $0) })
        .popover(isPresented: $showsPopover, arrowEdge: .bottom) {
            DocumentSavePopover(
                model: model,
                close: { showsPopover = false },
                // Elegir otra carpeta abre un panel, que cierra el popover: se vuelve a abrir al terminar.
                chooseFolder: {
                    showsPopover = false
                    model.chooseFolder { showsPopover = true }
                })
        }
    }
}

private struct DocumentSavePopover: View {
    @Bindable var model: DocumentTitleModel
    let close: () -> Void
    let chooseFolder: () -> Void
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
                GridRow {
                    Text("Nombre:").gridColumnAlignment(.trailing)
                    TextField("Nombre", text: $model.draftName)
                        .labelsHidden()
                        .focused($nameFocused)
                        .onSubmit(save)
                        .accessibilityIdentifier("documentName")
                }
                GridRow {
                    Text("Formato del archivo:")
                    Picker("Formato del archivo", selection: $model.draftType) {
                        ForEach(ImageCodec.supportedTypes, id: \.identifier) { type in
                            Text(DocumentTitleModel.formatName(type)).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityIdentifier("documentFormat")
                }
                GridRow {
                    Text("Ubicación:")
                    Menu {
                        ForEach(model.folderChoices, id: \.self) { folder in
                            Button {
                                model.draftFolder = folder
                            } label: {
                                Label {
                                    Text(FileManager.default.displayName(atPath: folder.path))
                                } icon: {
                                    Image(nsImage: DocumentTitleModel.icon(for: folder))
                                }
                            }
                        }
                        Divider()
                        Button("Otra…", action: chooseFolder)
                    } label: {
                        Label {
                            Text(FileManager.default.displayName(atPath: model.draftFolder.path))
                        } icon: {
                            Image(nsImage: DocumentTitleModel.icon(for: model.draftFolder))
                        }
                    }
                    .help(model.draftFolder.path)
                }
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button("Cancelar", role: .cancel, action: close)
                    .keyboardShortcut(.cancelAction)
                Button("Guardar", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.trimmedName.isEmpty || model.isSaving)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear { nameFocused = true }
    }

    private func save() {
        guard !model.trimmedName.isEmpty else { return }
        Task {
            if await model.save() { close() }
        }
    }
}

/// Une el título y el popover con el `NSDocument` de la ventana.
@MainActor @Observable
final class DocumentTitleModel {
    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var titleObservation: NSKeyValueObservation?

    private(set) var title = ""
    private(set) var fileURL: URL?

    var draftName = ""
    var draftType: UTType = .png
    var draftFolder = DocumentTitleModel.picturesFolder
    var errorMessage: String?
    private(set) var isSaving = false

    /// Carpetas con permiso de escritura en esta sesión (elegidas en un panel). La app está aislada
    /// (sandbox): fuera de ellas, de Imágenes y de Descargas solo se puede guardar a través de un panel.
    private static var grantedFolders: [URL] = []

    var trimmedName: String { draftName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var document: NSDocument? { window?.windowController?.document as? NSDocument }

    var icon: NSImage {
        if let fileURL { return NSWorkspace.shared.icon(forFile: fileURL.path) }
        return NSWorkspace.shared.icon(for: contentType)
    }

    private var contentType: UTType {
        document?.fileType.flatMap { UTType($0) } ?? ImageDocument.writableContentTypes[0]
    }

    func attach(to window: NSWindow?) {
        guard let window, window !== self.window else { return }
        self.window = window
        // El documento cambia el título de la ventana al guardarse o moverse.
        titleObservation = window.observe(\.title, options: [.initial]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        fileURL = document?.fileURL
        title = document?.displayName ?? window?.title ?? ""
    }

    /// Rellena el popover con el estado actual del documento.
    func prepareDraft() {
        refresh()
        errorMessage = nil
        if let fileURL {
            draftName = fileURL.deletingPathExtension().lastPathComponent
            draftFolder = fileURL.deletingLastPathComponent()
        } else {
            draftName = title
            draftFolder = Self.grantedFolders.last ?? Self.picturesFolder
        }
        draftType = Self.supportedType(for: contentType) ?? .png
    }

    var folderChoices: [URL] {
        var folders: [URL] = []
        if let fileURL { folders.append(fileURL.deletingLastPathComponent()) }
        folders += Self.grantedFolders.reversed()
        folders += [Self.picturesFolder, Self.downloadsFolder]
        var seen = Set<String>()
        return folders.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    func chooseFolder(then reopen: @escaping () -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = draftFolder
        panel.prompt = String(localized: "Elegir")
        let finish: (NSApplication.ModalResponse) -> Void = { [self] response in
            if response == .OK, let url = panel.url {
                Self.grant(url)
                draftFolder = url
            }
            reopen()
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    /// Guarda (o renombra y mueve) el documento según el popover. Devuelve `true` si terminó.
    func save() async -> Bool {
        guard let document else { return false }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        let (type, target) = destination(for: document)
        if target != document.fileURL, FileManager.default.fileExists(atPath: target.path) {
            errorMessage = String(
                localized: "Ya existe «\(target.lastPathComponent)» en esa carpeta. Elige otro nombre.")
            return false
        }
        do {
            try await perform(on: document, to: target, type: type)
        } catch  where Self.isPermissionError(error) {
            // Sin permiso sobre la carpeta (sandbox): se confirma en un panel, que sí lo concede.
            guard let url = await askWithSavePanel(suggesting: target, type: type) else { return false }
            do {
                try await perform(on: document, to: url, type: type)
            } catch {
                errorMessage = error.localizedDescription
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
        refresh()
        return true
    }

    /// Tipo y URL de destino. Una extensión de imagen escrita en el nombre elige el formato.
    private func destination(for document: NSDocument) -> (UTType, URL) {
        var name = trimmedName.replacingOccurrences(of: "/", with: ":")
        let typed = (name as NSString).pathExtension
        if !typed.isEmpty, let typedType = UTType(filenameExtension: typed).flatMap(Self.supportedType(for:)) {
            draftType = typedType
            name = (name as NSString).deletingPathExtension
        }
        let type = draftType
        // Se conserva la extensión del archivo si ya es de ese formato (p. ej. «jpeg» en vez de «jpg»).
        let currentExt = document.fileURL?.pathExtension
        let ext =
            currentExt.flatMap { UTType(filenameExtension: $0)?.conforms(to: type) == true ? $0 : nil }
            ?? type.preferredFilenameExtension ?? "png"
        let url = draftFolder.appendingPathComponent(name, isDirectory: false).appendingPathExtension(ext)
        return (type, url)
    }

    private func perform(on document: NSDocument, to target: URL, type: UTType) async throws {
        // Documento nuevo o cambio de formato: se guarda un archivo nuevo (el original no se toca).
        if document.fileURL == nil || Self.supportedType(for: contentType) != type {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                document.save(to: target, ofType: type.identifier, for: .saveAsOperation) { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } else {
            if document.fileURL?.standardizedFileURL != target.standardizedFileURL {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    document.move(to: target) { error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
            }
            if document.isDocumentEdited, let url = document.fileURL, let fileType = document.fileType {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    document.save(to: url, ofType: fileType, for: .saveOperation) { error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
            }
        }
        Self.grant(target.deletingLastPathComponent())
    }

    static func supportedType(for type: UTType) -> UTType? {
        ImageCodec.supportedTypes.first { type.conforms(to: $0) }
    }

    static func formatName(_ type: UTType) -> String {
        type.preferredFilenameExtension?.uppercased() ?? type.identifier
    }

    private func askWithSavePanel(suggesting target: URL, type: UTType) async -> URL? {
        let panel = NSSavePanel()
        panel.directoryURL = target.deletingLastPathComponent()
        panel.nameFieldStringValue = target.lastPathComponent
        panel.allowedContentTypes = [UTType(filenameExtension: target.pathExtension) ?? type]
        panel.canCreateDirectories = true
        panel.message = String(
            localized: "Confirma dónde guardar: StaiN necesita tu permiso para escribir en esta carpeta.")
        let response: NSApplication.ModalResponse
        if let window {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = panel.runModal()
        }
        guard response == .OK, let url = panel.url else { return nil }
        // El panel ya preguntó si reemplazar un archivo existente; mover no sobrescribe, así que va a la papelera.
        if document?.fileURL != nil, Self.supportedType(for: contentType) == type,
            document?.fileURL?.standardizedFileURL != url.standardizedFileURL
        {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
        return url
    }

    private static func grant(_ folder: URL) {
        grantedFolders.removeAll { $0.standardizedFileURL == folder.standardizedFileURL }
        grantedFolders.append(folder)
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
            [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(nsError.code)
        {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSPOSIXErrorDomain && [Int(EPERM), Int(EACCES)].contains(underlying.code)
                || isPermissionError(underlying)
        }
        return nsError.domain == NSPOSIXErrorDomain && [Int(EPERM), Int(EACCES)].contains(nsError.code)
    }

    static func icon(for folder: URL) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: folder.path)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    /// Carpeta personal real (dentro del sandbox, `homeDirectoryForCurrentUser` apunta al contenedor).
    private static var realHome: URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static var picturesFolder: URL { realHome.appendingPathComponent("Pictures", isDirectory: true) }
    static var downloadsFolder: URL { realHome.appendingPathComponent("Downloads", isDirectory: true) }
}

/// Entrega la ventana que contiene la vista.
private struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) {
        view.onWindow = onWindow
    }

    final class ReaderView: NSView {
        var onWindow: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}
