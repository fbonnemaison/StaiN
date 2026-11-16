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

/// Icono de la app para la vista previa del menú Compartir, recortado a su parte visible:
/// el icono del sistema trae márgenes transparentes y se veía pequeño dentro del recuadro.
@MainActor
enum ShareIcon {
    static let image: NSImage = cropped(NSApp.applicationIconImage)

    private static func cropped(_ icon: NSImage, side: Int = 512) -> NSImage {
        guard
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return icon }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        guard let full = context.makeImage(), let data = context.data else { return icon }

        // Caja de los píxeles visibles (alfa > 0). Las filas del búfer van de arriba abajo.
        let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
        var minX = side, minY = side, maxX = -1, maxY = -1
        for y in 0..<side {
            for x in 0..<side where pixels[(y * side + x) * 4 + 3] > 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return icon }
        let box = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let crop = full.cropping(to: box) else { return icon }
        return NSImage(cgImage: crop, size: NSSize(width: box.width, height: box.height))
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
