import AppKit
import StainKit

/// Vista que muestra el bitmap y convierte los eventos del ratón en acciones de herramienta.
///
/// Su tamaño es el de la imagen en píxeles; el zoom lo aplica el `NSScrollView` (magnification),
/// así que las coordenadas de la vista son directamente coordenadas de píxel.
final class CanvasView: NSView, NSMenuItemValidation {
    var document: ImageDocument? {
        didSet {
            guard document !== oldValue else { return }
            oldValue?.canvasDidChange = nil
            oldValue?.overlayDidChange = nil
            document?.canvasDidChange = { [weak self] rect in
                self?.setNeedsDisplay(NSRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
            }
            document?.overlayDidChange = { [weak self] in
                self?.overlayDidChange()
                self?.refreshUndoState()
            }
            needsDisplay = true
        }
    }
    var editor: EditorState?
    var undoManagerForStrokes: UndoManager? {
        didSet {
            guard undoManagerForStrokes !== oldValue else { return }
            let center = NotificationCenter.default
            if let oldValue {
                for name in Self.undoNotifications { center.removeObserver(self, name: name, object: oldValue) }
            }
            if let undoManagerForStrokes {
                for name in Self.undoNotifications {
                    center.addObserver(
                        self, selector: #selector(undoStateChanged), name: name, object: undoManagerForStrokes)
                }
            }
            refreshUndoState()
        }
    }

    private static let undoNotifications: [Notification.Name] = [
        .NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange,
        .NSUndoManagerCheckpoint,
    ]

    @objc private func undoStateChanged(_ notification: Notification) {
        refreshUndoState()
    }

    /// Copia el estado del `UndoManager` al estado del editor (menú y barra de herramientas).
    func refreshUndoState() {
        guard let editor else { return }
        let manager = undoManagerForStrokes
        let canUndo = manager?.canUndo ?? false
        let canRedo = manager?.canRedo ?? false
        if editor.canUndo != canUndo { editor.canUndo = canUndo }
        if editor.canRedo != canRedo { editor.canRedo = canRedo }
        let undoName = canUndo ? manager?.undoActionName ?? "" : ""
        let redoName = canRedo ? manager?.redoActionName ?? "" : ""
        if editor.undoActionName != undoName { editor.undoActionName = undoName }
        if editor.redoActionName != redoName { editor.redoActionName = redoName }
    }

    /// Zoom para que la imagen entera quepa en la ventana.
    func zoomToFit() {
        guard let scrollView = enclosingScrollView, let editor, bounds.width > 0, bounds.height > 0 else { return }
        let available = scrollView.contentSize
        let fit = min(available.width / bounds.width, available.height / bounds.height) * 0.95
        let level = min(max(fit, EditorState.minZoom), EditorState.maxZoom)
        scrollView.setMagnification(level, centeredAt: NSPoint(x: bounds.midX, y: bounds.midY))
        editor.zoom = scrollView.magnification
        needsDisplay = true
    }
    var tool: ToolKind = .pencil {
        didSet {
            guard tool != oldValue else { return }
            // Cambiar de herramienta confirma lo que estuviera a medias (forma editable, texto…).
            commitText()
            document?.commitTool(undoManager: undoManagerForStrokes)
            window?.invalidateCursorRects(for: self)
            refreshCursor()
        }
    }
    /// Estilo del cuadro de texto (fuente y colores actuales).
    var textStyle = TextStyle() {
        didSet { if textStyle != oldValue { applyTextStyle() } }
    }

    private var strokeButton: PointerButton?
    private var repeatTimer: Timer?
    private var drawnOverlayRect: NSRect?
    private var antsTimer: Timer?
    private var antsPhase: CGFloat = 0
    var showsGrid = false {
        didSet { if showsGrid != oldValue { needsDisplay = true } }
    }
    var showsPixelGrid = true {
        didSet { if showsPixelGrid != oldValue { needsDisplay = true } }
    }

    // Texto
    private var textView: NSTextView?
    private var textRect: PixelRect?
    private var textDraftStart: (x: Int, y: Int)?
    private var textDraftRect: PixelRect?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Lienzo"))
        setAccessibilityIdentifier("canvas")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var magnification: CGFloat { enclosingScrollView?.magnification ?? 1 }

    // MARK: Dibujo

    override func draw(_ dirtyRect: NSRect) {
        guard let document, let context = NSGraphicsContext.current?.cgContext else { return }
        let visible = dirtyRect.intersection(bounds)
        guard !visible.isEmpty else { return }

        // Fondo a cuadros para ver la transparencia (de tamaño fijo en pantalla).
        Checkerboard.color.setFill()
        visible.fill()

        let pixels = PixelRect(
            x: Int(visible.minX.rounded(.down)), y: Int(visible.minY.rounded(.down)),
            width: Int(visible.maxX.rounded(.up)) - Int(visible.minX.rounded(.down)),
            height: Int(visible.maxY.rounded(.up)) - Int(visible.minY.rounded(.down)))
        // Solo se copia la parte que hay que redibujar. Con zoom alejado basta un píxel de cada `step`:
        // así el coste depende de la pantalla y no del tamaño de la imagen.
        let deviceScale = magnification * (window?.backingScaleFactor ?? 2)
        let step = deviceScale < 1 ? max(1, Int((1 / deviceScale).rounded(.down))) : 1
        if let region = document.canvas.bitmap.sampled(pixels, step: step), let image = region.makeCGImage() {
            // Cada muestra cubre `step` píxeles; lo que sobresalga lo recorta AppKit.
            let target = CGRect(x: pixels.x, y: pixels.y, width: region.width * step, height: region.height * step)
            context.saveGState()
            context.interpolationQuality = magnification >= 1 ? .none : .medium
            // La vista está volteada: se invierte localmente para que la imagen salga derecha.
            context.translateBy(x: 0, y: target.maxY + target.minY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: target)
            context.restoreGState()
        }
        if showsPixelGrid, magnification >= 8 { drawPixelGrid(in: visible) }
        if showsGrid { drawGrid(in: visible) }
        drawGuides()
    }

    /// Una línea entre cada píxel, para pixel art (solo con mucho zoom).
    private func drawPixelGrid(in rect: NSRect) {
        let path = NSBezierPath()
        for x in Int(rect.minX.rounded(.down))...Int(rect.maxX.rounded(.up)) {
            path.move(to: NSPoint(x: CGFloat(x), y: rect.minY))
            path.line(to: NSPoint(x: CGFloat(x), y: rect.maxY))
        }
        for y in Int(rect.minY.rounded(.down))...Int(rect.maxY.rounded(.up)) {
            path.move(to: NSPoint(x: rect.minX, y: CGFloat(y)))
            path.line(to: NSPoint(x: rect.maxX, y: CGFloat(y)))
        }
        path.lineWidth = 1 / magnification
        NSColor.gray.withAlphaComponent(0.35).setStroke()
        path.stroke()
    }

    /// Cuadrícula cada `AppSettings.gridSpacing` píxeles (se oculta si queda demasiado apretada).
    private func drawGrid(in rect: NSRect) {
        let spacing = CGFloat(AppSettings.gridSpacing)
        guard spacing * magnification >= 4 else { return }
        let path = NSBezierPath()
        var x = (rect.minX / spacing).rounded(.down) * spacing
        while x <= rect.maxX {
            path.move(to: NSPoint(x: x, y: rect.minY))
            path.line(to: NSPoint(x: x, y: rect.maxY))
            x += spacing
        }
        var y = (rect.minY / spacing).rounded(.down) * spacing
        while y <= rect.maxY {
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            y += spacing
        }
        path.lineWidth = 1 / magnification
        NSColor.black.withAlphaComponent(0.25).setStroke()
        path.stroke()
    }

    /// Contorno y tiradores de la herramienta pendiente, y el marco del cuadro de texto.
    private func drawGuides() {
        let scale = 1 / magnification
        if let overlay = document?.overlay, !overlay.outline.isEmpty {
            let path = NSBezierPath()
            path.move(to: overlay.outline[0])
            overlay.outline.dropFirst().forEach { path.line(to: $0) }
            if overlay.isClosed { path.close() }
            Self.strokeDashed(path, scale: scale, phase: overlay.isMarchingAnts ? antsPhase : 0)
            for point in overlay.handles {
                let side = 6 * scale
                let handle = NSRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
                NSColor.white.setFill()
                handle.fill()
                NSColor.controlAccentColor.setStroke()
                let border = NSBezierPath(rect: handle)
                border.lineWidth = scale
                border.stroke()
            }
        }
        if let rect = textRect ?? textDraftRect {
            Self.strokeDashed(NSBezierPath(rect: NSRect(rect)), scale: scale)
        }
    }

    private static func strokeDashed(_ path: NSBezierPath, scale: CGFloat, phase: CGFloat = 0) {
        path.lineWidth = scale
        NSColor.white.setStroke()
        path.stroke()
        path.setLineDash([4 * scale, 4 * scale], count: 2, phase: phase * scale)
        NSColor.black.setStroke()
        path.stroke()
    }

    /// Redibuja solo donde estaban y donde están ahora las guías.
    private func overlayDidChange() {
        let margin = 8 / magnification
        var rect: NSRect?
        if let overlay = document?.overlay, !overlay.outline.isEmpty {
            let xs = overlay.outline.map(\.x) + overlay.handles.map(\.x)
            let ys = overlay.outline.map(\.y) + overlay.handles.map(\.y)
            if let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() {
                rect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).insetBy(
                    dx: -margin, dy: -margin)
            }
        }
        if let old = drawnOverlayRect { setNeedsDisplay(old) }
        if let rect { setNeedsDisplay(rect) }
        drawnOverlayRect = rect
        updateMarchingAnts()
        if let bounds = document?.selection?.bounds, document?.hasSelection == true {
            editor?.selectionSize = .init(x: bounds.width, y: bounds.height)
        } else {
            editor?.selectionSize = nil
        }
    }

    /// Anima el borde de la selección mientras exista.
    private func updateMarchingAnts() {
        let animate = document?.overlay?.isMarchingAnts == true
        if animate, antsTimer == nil {
            let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.antsPhase = (self.antsPhase + 1).truncatingRemainder(dividingBy: 8)
                    if let rect = self.drawnOverlayRect { self.setNeedsDisplay(rect) }
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            antsTimer = timer
        } else if !animate {
            antsTimer?.invalidate()
            antsTimer = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // El lienzo recibe Cortar/Copiar/Pegar y las teclas desde el principio.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, !(window.firstResponder is NSTextView) else { return }
            window.makeFirstResponder(self)
        }
    }

    // MARK: Cursor

    override func resetCursorRects() {
        let tip = editor?.tipSize
        let cursor = ToolCursors.cursor(
            for: tool, size: tip?.size, square: tip?.square ?? false, magnification: magnification)
        addCursorRect(visibleRect, cursor: cursor)
    }

    /// Clave del cursor actual: si cambia (tamaño de punta, zoom), se rehacen los cursores.
    var cursorKey = "" {
        didSet {
            guard cursorKey != oldValue else { return }
            window?.invalidateCursorRects(for: self)
            refreshCursor()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
                owner: self))
    }

    // El cursor se fija en cada movimiento, no solo con los rectángulos de cursor: SwiftUI vuelve a poner
    // la flecha cuando redibuja la ventana (p. ej. la posición en la barra de estado), y sin esto
    // el cursor alternaba al azar entre la flecha y el de la herramienta.
    override func cursorUpdate(with event: NSEvent) { applyCursor(for: event) }

    override func mouseMoved(with event: NSEvent) {
        updateCursorPosition(event)
        applyCursor(for: event)
        // Línea y polígono abiertos: el tramo siguiente sigue al ratón entre clics.
        if strokeButton == nil, tool == .line || tool == .polygon, document?.hasActiveTool == true {
            document?.pointerHovered(pointerEvent(event, button: .primary))
        }
    }

    override func mouseEntered(with event: NSEvent) { applyCursor(for: event) }

    /// Cursor fijado al pulsar (p. ej. el de redimensionar al agarrar un punto de la selección),
    /// que se mantiene mientras dura el arrastre.
    private var dragCursor: NSCursor?

    private var toolCursor: NSCursor {
        let tip = editor?.tipSize
        return ToolCursors.cursor(
            for: tool, size: tip?.size, square: tip?.square ?? false, magnification: magnification)
    }

    /// Cursor que corresponde a un punto del lienzo: redimensionar sobre un punto de la selección,
    /// o el de la herramienta.
    private func cursor(at point: NSPoint) -> NSCursor {
        if tool == .select || tool == .freeFormSelect, let selection = document?.selection,
            let handle = selection.handle(at: point, tolerance: 5 / magnification)
        {
            return Self.resizeCursor(for: handle)
        }
        return toolCursor
    }

    /// Pone el cursor que toca si el ratón está sobre el lienzo (tras cambiar de herramienta o de zoom).
    private func refreshCursor() {
        guard dragCursor == nil, let window, window.isKeyWindow else { return }
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard visibleRect.contains(point) else { return }
        cursor(at: point).set()
    }

    private func applyCursor(for event: NSEvent) {
        if let dragCursor {
            dragCursor.set()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard visibleRect.contains(point) else { return }
        cursor(at: point).set()
    }

    private static func resizeCursor(for handle: SelectionTool.Handle) -> NSCursor {
        let position: NSCursor.FrameResizePosition =
            switch (handle.dx, handle.dy) {
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
        guard strokeButton == nil, let document, let editor else { return }
        let pointer = pointerEvent(event, button: button)
        switch tool {
        case .zoom:
            window?.makeFirstResponder(self)
            zoom(at: pointer)
            return
        case .text:
            textPointerDown(pointer)
            strokeButton = button
            return
        case .bomb:
            confirmBomb(pointer)
            return
        default:
            break
        }
        window?.makeFirstResponder(self)
        guard
            let kind = editor.tool.makeTool(
                options: editor, canvasWidth: document.width, canvasHeight: document.height)
        else { return }
        strokeButton = button
        dragCursor = cursor(at: pointer.location)
        dragCursor?.set()
        document.pointerDown(pointer, actionName: tool.title, undoManager: undoManagerForStrokes) { kind }
        startRepeatingIfNeeded()
    }

    private func pointerDragged(_ event: NSEvent, button: PointerButton) {
        updateCursorPosition(event)
        applyCursor(for: event)
        guard strokeButton == button else { return }
        autoscroll(with: event)
        let pointer = pointerEvent(event, button: button)
        if tool == .text {
            textPointerDragged(pointer)
        } else {
            document?.pointerDragged(pointer)
        }
    }

    private func pointerUp(_ event: NSEvent, button: PointerButton) {
        guard strokeButton == button else { return }
        strokeButton = nil
        dragCursor = nil
        stopRepeating()
        let pointer = pointerEvent(event, button: button)
        if tool == .text {
            textPointerUp(pointer)
            return
        }
        document?.pointerUp(pointer, undoManager: undoManagerForStrokes)
        // Como en Paint, el cuentagotas vuelve a la herramienta anterior al soltar.
        if tool == .eyedropper { editor?.returnToPreviousTool() }
        if tool == .marker { editor?.nextMarker += 1 }
        applyCursor(for: event)
    }

    override func keyDown(with event: NSEvent) {
        let step = event.modifierFlags.contains(.shift) ? 10 : 1
        let selecting = document?.hasSelection == true
        switch event.keyCode {
        case 53 where selecting || document?.pendingToolClosesOnEscape == true, 36, 76:
            // Escape con selección o con un polígono de 3 vértices o más, Intro: confirmar.
            document?.commitTool(undoManager: undoManagerForStrokes)
        case 53:  // Escape: descarta lo que esté a medias.
            strokeButton = nil
            stopRepeating()
            document?.cancelTool()
        case 51 where selecting, 117 where selecting:  // ⌫ / Supr
            document?.deleteSelection()
        case 123 where selecting: document?.nudgeSelection(dx: -step, dy: 0)
        case 124 where selecting: document?.nudgeSelection(dx: step, dy: 0)
        case 125 where selecting: document?.nudgeSelection(dx: 0, dy: step)
        case 126 where selecting: document?.nudgeSelection(dx: 0, dy: -step)
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: Portapapeles (menú Edición)

    @objc func copy(_ sender: Any?) {
        guard let document else { return }
        Clipboard.write(document.selectedPixels ?? document.canvas.bitmap)
    }

    @objc func cut(_ sender: Any?) {
        guard let pixels = document?.selectedPixels else { return }
        Clipboard.write(pixels)
        document?.deleteSelection()
    }

    @objc func delete(_ sender: Any?) {
        document?.deleteSelection()
    }

    @objc override func selectAll(_ sender: Any?) {
        switchTool(to: .select)
        document?.selectAll(transparent: editor?.transparentSelection ?? false)
    }

    @objc func paste(_ sender: Any?) {
        guard let bitmap = Clipboard.readBitmap(), let document, let window else { return }
        let fits = bitmap.width <= document.width && bitmap.height <= document.height
        if fits {
            pasteFloating(bitmap)
            return
        }
        let alert = NSAlert()
        alert.messageText = String(localized: "La imagen pegada es más grande que el lienzo")
        alert.informativeText = String(localized: "¿Quieres agrandar el lienzo para que quepa?")
        alert.addButton(withTitle: String(localized: "Agrandar"))
        alert.addButton(withTitle: String(localized: "No agrandar"))
        alert.beginSheetModal(for: window) { [weak self] response in
            MainActor.assumeIsolated {
                guard let self, let document = self.document else { return }
                if response == .alertFirstButtonReturn {
                    let bigger = document.canvas.bitmap.resizedCanvas(
                        width: max(bitmap.width, document.width), height: max(bitmap.height, document.height),
                        anchor: .topLeft, fill: document.secondaryColor)
                    document.replaceImage(with: bigger, actionName: String(localized: "Agrandar lienzo"))
                }
                self.pasteFloating(bitmap)
            }
        }
    }

    /// Pega en la esquina superior izquierda de la zona visible, con la herramienta Selección.
    private func pasteFloating(_ bitmap: Bitmap) {
        switchTool(to: .select)
        let visible = visibleRect.intersection(bounds)
        let x = max(0, Int(visible.minX.rounded(.up)))
        let y = max(0, Int(visible.minY.rounded(.up)))
        document?.paste(bitmap, atX: x, y: y, transparent: editor?.transparentSelection ?? false)
        window?.makeFirstResponder(self)
    }

    private func switchTool(to newTool: ToolKind) {
        tool = newTool
        editor?.tool = newTool
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(cut(_:)), #selector(delete(_:)): document?.hasSelection == true
        case #selector(paste(_:)): Clipboard.hasImage
        case #selector(copy(_:)), #selector(selectAll(_:)): document != nil
        default: true
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
        let clicks =
            [.leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp].contains(event.type)
            ? event.clickCount : 1
        return PointerEvent(
            location: convert(event.locationInWindow, from: nil), button: button, modifiers: modifiers,
            pressure: pressure, clickCount: clicks, hitTolerance: 5 / magnification)
    }

    // MARK: Aerógrafo

    private func startRepeatingIfNeeded() {
        guard document?.toolRepeatsWhileHeld == true else { return }
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.document?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    // MARK: Bomba

    private func confirmBomb(_ pointer: PointerEvent) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "¿Borrar toda la imagen?")
        alert.informativeText = String(localized: "Se rellenará con el color secundario. Puedes deshacerlo con ⌘Z.")
        alert.alertStyle = .warning
        let erase = alert.addButton(withTitle: String(localized: "Borrar"))
        erase.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancelar"))
        alert.beginSheetModal(for: window) { [weak self] response in
            MainActor.assumeIsolated {
                guard let self else { return }
                if response == .alertFirstButtonReturn, let document = self.document {
                    document.pointerDown(
                        pointer, actionName: ToolKind.bomb.title, undoManager: self.undoManagerForStrokes
                    ) {
                        BombTool()
                    }
                    document.pointerUp(pointer, undoManager: self.undoManagerForStrokes)
                }
                self.editor?.returnToPreviousTool()
            }
        }
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

// MARK: - Texto

extension CanvasView {
    /// Pulsar fuera del cuadro de texto lo confirma; si no había cuadro, empieza a dibujar uno.
    fileprivate func textPointerDown(_ pointer: PointerEvent) {
        if textView != nil {
            commitText()
            textDraftStart = nil
            return
        }
        textDraftStart = pointer.pixel
        textDraftRect = PixelRect(corner: pointer.pixel, pointer.pixel)
        needsDisplay = true
    }

    fileprivate func textPointerDragged(_ pointer: PointerEvent) {
        guard let start = textDraftStart else { return }
        if let old = textDraftRect { setNeedsDisplay(NSRect(old).insetBy(dx: -4, dy: -4)) }
        textDraftRect = PixelRect(corner: start, pointer.pixel)
        if let rect = textDraftRect { setNeedsDisplay(NSRect(rect).insetBy(dx: -4, dy: -4)) }
    }

    fileprivate func textPointerUp(_ pointer: PointerEvent) {
        guard let start = textDraftStart else { return }
        textDraftStart = nil
        var rect = PixelRect(corner: start, pointer.pixel)
        // Un clic sin arrastrar crea un cuadro de tamaño razonable para la fuente actual.
        let minHeight = Int((textStyle.size * 1.4).rounded(.up))
        if rect.width < 16 || rect.height < minHeight {
            rect = PixelRect(
                x: rect.x, y: rect.y, width: max(rect.width, Int(textStyle.size * 8)),
                height: max(rect.height, minHeight))
        }
        textDraftRect = nil
        beginTextEditing(in: rect.intersection(bounds.pixelRect))
    }

    private func beginTextEditing(in rect: PixelRect) {
        guard !rect.isEmpty else { return }
        let view = NSTextView(frame: NSRect(rect))
        view.isRichText = false
        view.allowsUndo = true
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.setAccessibilityIdentifier("textBox")
        addSubview(view)
        textView = view
        textRect = rect
        applyTextStyle()
        window?.makeFirstResponder(view)
        needsDisplay = true
    }

    /// Rasteriza el texto en la imagen (si hay algo escrito o fondo opaco) y quita el cuadro.
    func commitText() {
        guard let view = textView, let rect = textRect else { return }
        let text = view.string
        endTextEditing()
        if !text.isEmpty || textStyle.background != nil {
            document?.drawText(text, style: textStyle, in: rect, undoManager: undoManagerForStrokes)
        }
    }

    func cancelText() {
        endTextEditing()
    }

    private func endTextEditing() {
        // El cuadro registra su escritura en el `UndoManager` de la ventana, que no retiene el objetivo:
        // si sus acciones quedan en la pila, el siguiente ⌘Z llamaría a un NSTextView ya liberado.
        if let view = textView {
            view.breakUndoCoalescing()
            for manager in [view.undoManager, undoManagerForStrokes, window?.undoManager] {
                manager?.removeAllActions(withTarget: view)
            }
        }
        textView?.removeFromSuperview()
        textView = nil
        textRect = nil
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    /// Muestra el texto en edición con la misma fuente y colores con que se rasterizará.
    fileprivate func applyTextStyle() {
        guard let view = textView else { return }
        let font = textStyle.ctFont as NSFont
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: textStyle.color.nsColor,
        ]
        if textStyle.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        view.font = font
        view.textColor = textStyle.color.nsColor
        view.insertionPointColor = textStyle.color.nsColor
        view.typingAttributes = attributes
        view.textStorage?.setAttributes(attributes, range: NSRange(location: 0, length: view.string.utf16.count))
        if let background = textStyle.background {
            view.drawsBackground = true
            view.backgroundColor = background.nsColor
        } else {
            view.drawsBackground = false
        }
    }
}

extension NSRect {
    init(_ rect: PixelRect) {
        self.init(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    var pixelRect: PixelRect {
        PixelRect(x: Int(minX), y: Int(minY), width: Int(width), height: Int(height))
    }
}
