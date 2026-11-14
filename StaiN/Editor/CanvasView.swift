import AppKit
import StainKit

/// Vista que muestra el bitmap y convierte los eventos del ratón en trazos.
///
/// Su tamaño es el de la imagen en píxeles; el zoom lo aplica el `NSScrollView` (magnification),
/// así que las coordenadas de la vista son directamente coordenadas de píxel.
final class CanvasView: NSView {
    var document: ImageDocument? {
        didSet {
            guard document !== oldValue else { return }
            oldValue?.canvasDidChange = nil
            document?.canvasDidChange = { [weak self] rect in
                self?.setNeedsDisplay(NSRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
            }
            needsDisplay = true
        }
    }
    var editor: EditorState?
    var undoManagerForStrokes: UndoManager?
    var tool: ToolKind = .pencil {
        didSet { if tool != oldValue { window?.invalidateCursorRects(for: self) } }
    }

    private var strokeButton: PointerButton?
    private static let checkerboard = NSColor(patternImage: makeCheckerboard())

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Lienzo")
        setAccessibilityIdentifier("canvas")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: Dibujo

    override func draw(_ dirtyRect: NSRect) {
        guard let document, let context = NSGraphicsContext.current?.cgContext else { return }
        let visible = dirtyRect.intersection(bounds)
        guard !visible.isEmpty else { return }

        // Fondo a cuadros para ver la transparencia (de tamaño fijo en pantalla).
        Self.checkerboard.setFill()
        visible.fill()

        let pixels = PixelRect(
            x: Int(visible.minX.rounded(.down)), y: Int(visible.minY.rounded(.down)),
            width: Int(visible.maxX.rounded(.up)) - Int(visible.minX.rounded(.down)),
            height: Int(visible.maxY.rounded(.up)) - Int(visible.minY.rounded(.down)))
        // Solo se copia la parte que hay que redibujar.
        guard let region = document.canvas.bitmap.cropped(to: pixels), let image = region.makeCGImage() else { return }

        let target = CGRect(x: pixels.x, y: pixels.y, width: region.width, height: region.height)
        context.saveGState()
        context.interpolationQuality = (editor?.zoom ?? 1) >= 1 ? .none : .medium
        // La vista está volteada: se invierte localmente para que la imagen salga derecha.
        context.translateBy(x: 0, y: target.maxY + target.minY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: target)
        context.restoreGState()
    }

    private static func makeCheckerboard() -> NSImage {
        let side: CGFloat = 8
        return NSImage(size: NSSize(width: side * 2, height: side * 2), flipped: false) { _ in
            NSColor(white: 1, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: side * 2, height: side * 2).fill()
            NSColor(white: 0.82, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: side, height: side).fill()
            NSRect(x: side, y: side, width: side, height: side).fill()
            return true
        }
    }

    // MARK: Cursor

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: tool == .zoom ? .zoomIn : .crosshair)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self))
    }

    override func mouseMoved(with event: NSEvent) { updateCursorPosition(event) }
    override func mouseExited(with event: NSEvent) { editor?.cursor = nil }

    private func updateCursorPosition(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else {
            editor?.cursor = nil
            return
        }
        editor?.cursor = .init(x: Int(point.x.rounded(.down)), y: Int(point.y.rounded(.down)))
    }

    // MARK: Ratón

    override func mouseDown(with event: NSEvent) { pointerDown(event, button: .primary) }
    override func mouseDragged(with event: NSEvent) { pointerDragged(event, button: .primary) }
    override func mouseUp(with event: NSEvent) { pointerUp(event, button: .primary) }
    override func rightMouseDown(with event: NSEvent) { pointerDown(event, button: .secondary) }
    override func rightMouseDragged(with event: NSEvent) { pointerDragged(event, button: .secondary) }
    override func rightMouseUp(with event: NSEvent) { pointerUp(event, button: .secondary) }

    private func pointerDown(_ event: NSEvent, button: PointerButton) {
        window?.makeFirstResponder(self)
        guard strokeButton == nil, let document else { return }
        let pointer = pointerEvent(event, button: button)
        guard let tool = tool.makeTool() else {
            zoom(at: pointer)
            return
        }
        strokeButton = button
        document.beginStroke(with: tool, pointer)
    }

    private func pointerDragged(_ event: NSEvent, button: PointerButton) {
        updateCursorPosition(event)
        guard strokeButton == button else { return }
        autoscroll(with: event)
        document?.continueStroke(pointerEvent(event, button: button))
    }

    private func pointerUp(_ event: NSEvent, button: PointerButton) {
        guard strokeButton == button else { return }
        strokeButton = nil
        document?.endStroke(
            pointerEvent(event, button: button), actionName: tool.title, undoManager: undoManagerForStrokes)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, strokeButton != nil {  // Escape
            strokeButton = nil
            document?.cancelStroke()
        } else {
            super.keyDown(with: event)
        }
    }

    private func pointerEvent(_ event: NSEvent, button: PointerButton) -> PointerEvent {
        var modifiers: PointerModifiers = []
        let flags = event.modifierFlags
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        let pressure = event.type == .tabletPoint || event.subtype == .tabletPoint ? Double(event.pressure) : 1
        return PointerEvent(
            location: convert(event.locationInWindow, from: nil), button: button, modifiers: modifiers,
            pressure: pressure)
    }

    // MARK: Lupa

    /// Clic: acercar centrado en el punto. Opción-clic o clic derecho: alejar.
    private func zoom(at pointer: PointerEvent) {
        guard let scrollView = enclosingScrollView, let editor else { return }
        let zoomOut = pointer.button == .secondary || pointer.modifiers.contains(.option)
        let current = scrollView.magnification
        let next = zoomOut ? EditorState.level(before: current) : EditorState.level(after: current)
        scrollView.setMagnification(next, centeredAt: pointer.location)
        editor.zoom = scrollView.magnification
    }
}
