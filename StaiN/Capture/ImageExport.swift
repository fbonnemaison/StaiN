import AppKit
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

    /// Menú Compartir del sistema con un PNG temporal de la imagen.
    static func share(_ bitmap: Bitmap, from window: NSWindow?) {
        guard let view = window?.contentView, let data = try? ImageCodec.encode(bitmap, as: .png) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("StaiN.png")
        guard (try? data.write(to: url)) != nil else { return }
        let picker = NSSharingServicePicker(items: [url])
        let anchor = NSRect(x: view.bounds.maxX - 60, y: view.bounds.maxY - 4, width: 1, height: 1)
        picker.show(relativeTo: anchor, of: view, preferredEdge: .minY)
    }
}
