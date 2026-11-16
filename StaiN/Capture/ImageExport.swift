import AppKit
import CoreTransferable
import StainKit
import UniformTypeIdentifiers

/// Compartir, exportar a escala y abrir documentos nuevos con una imagen.
@MainActor
enum ImageExport {
    /// Abre un documento nuevo con la imagen.
    static func openAsNewDocument(_ bitmap: Bitmap) {
        ImageDocument.pendingNewBitmap.withLock { $0 = bitmap }
        NSDocumentController.shared.newDocument(nil)
    }

    /// Guarda un PNG escalado con vecino más cercano (pixel art nítido).
    static func exportScaled(_ bitmap: Bitmap, factor: Int, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(suggestedName) x\(factor).png"
        panel.message = String(
            localized: "Exportar a ×\(factor) (\(bitmap.width * factor) × \(bitmap.height * factor) px)")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scaled = bitmap.resized(width: bitmap.width * factor, height: bitmap.height * factor, smooth: false)
        do {
            try ImageCodec.encode(scaled, as: .png).write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// Imagen para el menú Compartir (`ShareLink`): el PNG se genera solo al elegir un servicio.
struct ShareableImage: Transferable {
    let bitmap: Bitmap
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { image in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(image.name).appendingPathExtension("png")
            try ImageCodec.encode(image.bitmap, as: .png).write(to: url)
            return SentTransferredFile(url)
        }
    }
}
