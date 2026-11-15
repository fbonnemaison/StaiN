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
    let fitRequest: Int
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
        // Margen alrededor del lienzo para que los puntos de control se vean aunque ocupe toda la vista.
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(
            top: CanvasResizeOverlay.margin, left: CanvasResizeOverlay.margin,
            bottom: CanvasResizeOverlay.margin, right: CanvasResizeOverlay.margin)

        let overlay = CanvasResizeOverlay(canvas: canvas, scrollView: scrollView)
        overlay.frame = scrollView.bounds
        overlay.autoresizingMask = [.width, .height]
        scrollView.addSubview(overlay, positioned: .above, relativeTo: scrollView.contentView)

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
        let tip = editor.tipSize
        canvas.cursorKey = "\(tool.rawValue)-\(tip?.size ?? 0)-\(tip?.square ?? false)-\(zoom)"
        canvas.showsPixelGrid = editor.showsPixelGrid
        for case let overlay as CanvasResizeOverlay in scrollView.subviews {
            overlay.isActive = editor.showsCanvasHandles
        }
        document.undoManager = undoManager
        if context.coordinator.fitRequest != editor.fitRequest {
            context.coordinator.fitRequest = editor.fitRequest
            DispatchQueue.main.async { canvas.zoomToFit() }
        }
        canvas.setAccessibilityValue(
            String(localized: "\(Int(imageSize.width)) × \(Int(imageSize.height)) píxeles, herramienta \(tool.title)"))
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
        var fitRequest = 0

        @objc func didEndLiveMagnify(_ notification: Notification) {
            guard let scrollView = notification.object as? NSScrollView else { return }
            editor?.zoom = scrollView.magnification
            scrollView.documentView?.needsDisplay = true
        }
    }
}

/// Puntos de control en las esquinas y los costados del lienzo para cambiar su tamaño con el ratón.
///
/// Va encima de la vista de desplazamiento y solo recibe clics sobre los puntos; el resto pasa al lienzo.
/// Al soltar, el lienzo cambia de tamaño sin escalar la imagen: los píxeles nuevos toman el color
/// secundario y la imagen queda pegada al lado opuesto al punto arrastrado.
final class CanvasResizeOverlay: NSView {
    static let margin: CGFloat = 14
    private static let handleSide: CGFloat = 7
    private static let gap: CGFloat = 4

    /// Punto de control: -1, 0 o 1 en cada eje (con y hacia abajo).
    private struct Handle: Equatable {
        let dx: Int
        let dy: Int

        static let all: [Handle] = [
            Handle(dx: -1, dy: -1), Handle(dx: 0, dy: -1), Handle(dx: 1, dy: -1),
            Handle(dx: -1, dy: 0), Handle(dx: 1, dy: 0),
            Handle(dx: -1, dy: 1), Handle(dx: 0, dy: 1), Handle(dx: 1, dy: 1),
        ]

        /// La imagen se queda en el lado contrario al que se arrastra.
        var anchor: CanvasAnchor {
            CanvasAnchor(rawValue: (dy == -1 ? 2 : 0) * 3 + (dx == -1 ? 2 : 0)) ?? .topLeft
        }

        var cursor: NSCursor {
            let position: NSCursor.FrameResizePosition =
                switch (dx, dy) {
                case (-1, -1): .topLeft
                case (0, -1): .top
                case (1, -1): .topRight
                case (-1, 0): .left
                case (1, 0): .right
                case (-1, 1): .bottomLeft
                case (0, 1): .bottom
                default: .bottomRight
                }
            return NSCursor.frameResize(position: position, directions: .all)
        }
    }

    private weak var canvas: CanvasView?
    /// Se muestra y responde solo si está activada "Redimensionar lienzo".
    var isActive = false {
        didSet { if isActive != oldValue { layoutChanged() } }
    }
    private var drag: (handle: Handle, start: NSPoint, current: NSPoint)?

    init(canvas: CanvasView, scrollView: NSScrollView) {
        self.canvas = canvas
        super.init(frame: .zero)
        let clip = scrollView.contentView
        clip.postsBoundsChangedNotifications = true
        canvas.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(layoutChanged), name: NSView.boundsDidChangeNotification, object: clip)
        center.addObserver(
            self, selector: #selector(layoutChanged), name: NSView.frameDidChangeNotification, object: clip)
        center.addObserver(
            self, selector: #selector(layoutChanged), name: NSView.frameDidChangeNotification, object: canvas)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func layoutChanged() {
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutChanged()
    }

    /// Rectángulo del lienzo en coordenadas de esta vista.
    private var canvasRect: NSRect? {
        guard isActive, let canvas, canvas.document != nil else { return nil }
        return canvas.convert(canvas.bounds, to: self)
    }

    /// Píxeles de imagen por punto de pantalla.
    private var pixelsPerPoint: CGFloat {
        guard let canvas, let rect = canvasRect, rect.width > 0 else { return 1 }
        return canvas.bounds.width / rect.width
    }

    private func handleRect(_ handle: Handle, in rect: NSRect) -> NSRect {
        let side = Self.handleSide, offset = side / 2 + Self.gap
        let x: CGFloat =
            switch handle.dx {
            case -1: rect.minX - offset
            case 1: rect.maxX + offset
            default: rect.midX
            }
        let y: CGFloat =
            switch handle.dy {
            case -1: rect.minY - offset
            case 1: rect.maxY + offset
            default: rect.midY
            }
        return NSRect(x: x - side / 2, y: y - side / 2, width: side, height: side)
    }

    /// Zona sensible algo mayor que el punto dibujado.
    private func hitRect(_ handle: Handle, in rect: NSRect) -> NSRect {
        handleRect(handle, in: rect).insetBy(dx: -4, dy: -4)
    }

    private func handle(at point: NSPoint) -> Handle? {
        guard let rect = canvasRect else { return nil }
        let visible = visibleArea
        return Handle.all.first { hitRect($0, in: rect).contains(point) && visible.contains(point) }
    }

    /// Zona de la vista de desplazamiento sin barras de desplazamiento.
    private var visibleArea: NSRect {
        guard let clip = (superview as? NSScrollView)?.contentView else { return bounds }
        return clip.convert(clip.bounds, to: self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard drag == nil else { return self }
        let local = convert(point, from: superview)
        return handle(at: local) == nil ? nil : self
    }

    override func resetCursorRects() {
        guard let rect = canvasRect else { return }
        let visible = visibleArea
        for handle in Handle.all {
            let area = hitRect(handle, in: rect).intersection(visible)
            if !area.isEmpty { addCursorRect(area, cursor: handle.cursor) }
        }
    }

    // MARK: Dibujo

    override func draw(_ dirtyRect: NSRect) {
        guard let rect = canvasRect else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: visibleArea).addClip()
        if let drag {
            let preview = previewRect(for: drag.handle, from: rect, delta: delta(drag))
            let path = NSBezierPath(rect: preview.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 1
            NSColor.white.setStroke()
            path.stroke()
            path.setLineDash([4, 4], count: 2, phase: 0)
            NSColor.black.setStroke()
            path.stroke()
            drawSizeLabel(for: drag)
        } else {
            for handle in Handle.all {
                let box = handleRect(handle, in: rect)
                NSColor.white.setFill()
                box.fill()
                NSColor.controlAccentColor.setStroke()
                let border = NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5))
                border.lineWidth = 1
                border.stroke()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawSizeLabel(for drag: (handle: Handle, start: NSPoint, current: NSPoint)) {
        let size = newSize(for: drag)
        let text = "\(size.width) × \(size.height) px" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        var box = NSRect(
            x: drag.current.x + 12, y: drag.current.y + 12, width: textSize.width + 10, height: textSize.height + 4)
        let visible = visibleArea
        box.origin.x = min(box.origin.x, visible.maxX - box.width - 2)
        box.origin.y = min(box.origin.y, visible.maxY - box.height - 2)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        text.draw(at: NSPoint(x: box.minX + 5, y: box.minY + 2), withAttributes: attributes)
    }

    // MARK: Arrastre

    private func delta(_ drag: (handle: Handle, start: NSPoint, current: NSPoint)) -> NSSize {
        NSSize(width: drag.current.x - drag.start.x, height: drag.current.y - drag.start.y)
    }

    private func newSize(for drag: (handle: Handle, start: NSPoint, current: NSPoint)) -> (width: Int, height: Int) {
        guard let document = canvas?.document else { return (1, 1) }
        let d = delta(drag), scale = pixelsPerPoint
        let maxSide = AppSettings.maxCanvasSide
        let width = document.width + Int((CGFloat(drag.handle.dx) * d.width * scale).rounded())
        let height = document.height + Int((CGFloat(drag.handle.dy) * d.height * scale).rounded())
        return (min(max(width, 1), maxSide), min(max(height, 1), maxSide))
    }

    /// Rectángulo del lienzo con el nuevo tamaño, ajustado a píxeles enteros.
    private func previewRect(for handle: Handle, from rect: NSRect, delta: NSSize) -> NSRect {
        guard let drag else { return rect }
        let size = newSize(for: drag)
        let scale = pixelsPerPoint
        let width = CGFloat(size.width) / scale, height = CGFloat(size.height) / scale
        let x = handle.dx == -1 ? rect.maxX - width : rect.minX
        let y = handle.dy == -1 ? rect.maxY - height : rect.minY
        return NSRect(x: x, y: y, width: width, height: height)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let handle = handle(at: point) else { return }
        drag = (handle, point, point)
        handle.cursor.push()
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard drag != nil else { return }
        drag?.current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var drag else { return }
        drag.current = convert(event.locationInWindow, from: nil)
        self.drag = nil
        NSCursor.pop()
        needsDisplay = true
        guard let document = canvas?.document else { return }
        let size = newSize(for: drag)
        guard size.width != document.width || size.height != document.height else { return }
        let resized = document.canvas.bitmap.resizedCanvas(
            width: size.width, height: size.height, anchor: drag.handle.anchor, fill: document.secondaryColor)
        document.replaceImage(with: resized, actionName: String(localized: "Tamaño del lienzo"))
        layoutChanged()
    }
}
