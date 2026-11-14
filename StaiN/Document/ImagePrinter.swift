import AppKit
import StainKit

/// Imprime la imagen, reducida si hace falta para que quepa en la página y centrada.
@MainActor
enum ImagePrinter {
    static func print(_ bitmap: Bitmap) {
        guard let cgImage = bitmap.makeCGImage() else { return }
        let size = NSSize(width: bitmap.width, height: bitmap.height)
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.image = NSImage(cgImage: cgImage, size: size)
        imageView.imageScaling = .scaleProportionallyDown

        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo()
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = true
        info.orientation = bitmap.width > bitmap.height ? .landscape : .portrait

        let operation = NSPrintOperation(view: imageView, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }
}
