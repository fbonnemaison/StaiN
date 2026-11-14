import AppKit
import StainKit

/// Portapapeles del sistema: escribe PNG y TIFF, y lee cualquier imagen (o archivo de imagen).
@MainActor
enum Clipboard {
    static func write(_ bitmap: Bitmap) {
        guard let image = bitmap.makeCGImage() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let png = rep.representation(using: .png, properties: [:]) {
            pasteboard.setData(png, forType: .png)
        }
        if let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    static var hasImage: Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    static func readBitmap() -> Bitmap? {
        let pasteboard = NSPasteboard.general
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type), let bitmap = try? ImageCodec.decode(data) {
                return bitmap
            }
        }
        guard
            let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage,
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        return Bitmap(cgImage: cgImage)
    }
}
