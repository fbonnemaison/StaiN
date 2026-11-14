import AppKit
import StainKit
import SwiftUI

/// Envuelve el lienzo AppKit (scroll + zoom + `CanvasView`) para usarlo en SwiftUI.
struct CanvasRepresentable: NSViewRepresentable {
    let document: ImageDocument
    let editor: EditorState
    let zoom: Double
    let tool: ToolKind
    let imageSize: CGSize
    let textStyle: TextStyle
    let showsGrid: Bool
    let undoManager: UndoManager?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.contentView = CenteringClipView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .underPageBackgroundColor
        scrollView.allowsMagnification = true
        scrollView.minMagnification = EditorState.minZoom
        scrollView.maxMagnification = EditorState.maxZoom

        let canvas = CanvasView(frame: NSRect(origin: .zero, size: imageSize))
        scrollView.documentView = canvas

        // Zoom con pellizco del trackpad: se refleja en el estado (barra de estado, menús).
        context.coordinator.editor = editor
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.didEndLiveMagnify(_:)),
            name: NSScrollView.didEndLiveMagnifyNotification, object: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let canvas = scrollView.documentView as? CanvasView else { return }
        canvas.document = document
        canvas.editor = editor
        canvas.undoManagerForStrokes = undoManager
        canvas.tool = tool
        canvas.textStyle = textStyle
        canvas.showsGrid = showsGrid
        canvas.showsPixelGrid = editor.showsPixelGrid
        document.undoManager = undoManager
        if canvas.frame.size != imageSize {
            canvas.setFrameSize(imageSize)
            canvas.needsDisplay = true
        }
        if abs(scrollView.magnification - zoom) > 0.0001 {
            let visible = scrollView.contentView.bounds
            scrollView.setMagnification(zoom, centeredAt: NSPoint(x: visible.midX, y: visible.midY))
            canvas.needsDisplay = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        (scrollView.documentView as? CanvasView)?.document = nil
    }

    @MainActor
    final class Coordinator: NSObject {
        var editor: EditorState?

        @objc func didEndLiveMagnify(_ notification: Notification) {
            guard let scrollView = notification.object as? NSScrollView else { return }
            editor?.zoom = scrollView.magnification
            scrollView.documentView?.needsDisplay = true
        }
    }
}
