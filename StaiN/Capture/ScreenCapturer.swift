import AppKit
import ScreenCaptureKit
import StainKit

/// Captura una ventana o una pantalla con el selector del sistema y la abre como documento nuevo.
/// macOS pide permiso de "Grabación de pantalla" la primera vez.
@MainActor
final class ScreenCapturer: NSObject, SCContentSharingPickerObserver {
    static let shared = ScreenCapturer()

    func start() {
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow, .singleDisplay]
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.isActive = true
        picker.present()
    }

    private func finish() {
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
    }

    private func capture(_ filter: SCContentFilter) async {
        defer { finish() }
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        configuration.width = Int(filter.contentRect.width * scale)
        configuration.height = Int(filter.contentRect.height * scale)
        configuration.showsCursor = false
        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            guard let bitmap = Bitmap(cgImage: image) else { return }
            ImageDocument.pendingNewBitmap.withLock { $0 = bitmap }
            NSDocumentController.shared.newDocument(nil)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    nonisolated func contentSharingPicker(
        _ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?
    ) {
        // SCContentFilter no es Sendable, pero el sistema no lo vuelve a tocar tras entregarlo.
        nonisolated(unsafe) let delivered = filter
        Task { @MainActor in await self.capture(delivered) }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in self.finish() }
    }
}
