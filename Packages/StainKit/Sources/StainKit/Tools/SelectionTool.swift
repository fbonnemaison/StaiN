import CoreGraphics

/// Selección rectangular o libre (lazo), al estilo de Paint.
///
/// Al arrastrar dentro, los píxeles se "levantan" y flotan: el hueco se rellena con el color secundario
/// (o se deja intacto si se duplica con ⌥). Todo el trabajo con la selección es un único paso de deshacer,
/// que se confirma al hacer clic fuera, pulsar Intro/Escape o cambiar de herramienta.
public struct SelectionTool: Tool {
    public enum Mode: Sendable {
        case rectangle
        case freeForm
    }

    public let mode: Mode
    /// Los píxeles del color secundario no se pegan (Paint: "selección transparente").
    public var isTransparent: Bool

    private enum Phase: Sendable {
        case idle
        case drawingRectangle(anchor: (x: Int, y: Int))
        case drawingLasso
        case selected
        case moving(from: (x: Int, y: Int), startOrigin: (x: Int, y: Int))
    }

    private var phase: Phase = .idle
    private var lasso: [(x: Int, y: Int)] = []
    /// Posición actual de la selección (y de los píxeles flotantes).
    public private(set) var bounds: PixelRect = .zero
    /// De dónde se levantaron los píxeles.
    private var sourceBounds: PixelRect = .zero
    private var sourceMask: Bitmap?
    /// Máscara de la forma (lazo) en la posición actual; `nil` = rectángulo completo.
    private var mask: Bitmap?
    /// Píxeles flotantes; `nil` hasta que se levantan.
    private var content: Bitmap?
    private var leavesHole = true
    /// Copias que se han ido soltando con ⌥-arrastrar.
    private var stamps: [(content: Bitmap, mask: Bitmap?, at: PixelRect)] = []
    private var background: PaintColor = .white
    /// Posición de la selección cuando se terminó de dibujar el lazo (para desplazar su contorno).
    private var lassoAnchor: (x: Int, y: Int)?
    /// Tras girar o voltear, el contorno del lazo ya no coincide: se muestra el rectángulo.
    private var isTransformed = false

    public init(mode: Mode = .rectangle, isTransparent: Bool = false) {
        self.mode = mode
        self.isTransparent = isTransparent
    }

    /// Selección ya flotante con píxeles pegados en `(x, y)`.
    public init(pasting pasted: Bitmap, atX x: Int, y: Int, isTransparent: Bool = false, background: PaintColor) {
        self.init(mode: .rectangle, isTransparent: isTransparent)
        bounds = PixelRect(x: x, y: y, width: pasted.width, height: pasted.height)
        content = pasted
        leavesHole = false
        self.background = background
        phase = .selected
    }

    /// Selección rectangular ya hecha (p. ej. "Seleccionar todo").
    public init(selecting rect: PixelRect, isTransparent: Bool = false, background: PaintColor) {
        self.init(mode: .rectangle, isTransparent: isTransparent)
        bounds = rect
        self.background = background
        phase = .selected
    }

    public var hasSelection: Bool {
        switch phase {
        case .selected, .moving: !bounds.isEmpty
        default: false
        }
    }

    public var isFloating: Bool { content != nil }

    public var isAwaitingInput: Bool {
        if case .selected = phase { return !bounds.isEmpty }
        return false
    }

    public func accepts(_ event: PointerEvent) -> Bool {
        hasSelection && bounds.contains(x: event.pixel.x, y: event.pixel.y)
    }

    // MARK: Ratón

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        if hasSelection {
            // Arrastre dentro: mover. Con ⌥ se duplica.
            if event.modifiers.contains(.option) {
                if let content {
                    stamps.append((content, mask, bounds))
                } else {
                    lift(from: canvas, leavingHole: false)
                }
            } else if content == nil {
                lift(from: canvas, leavingHole: true)
            }
            phase = .moving(from: pixel, startOrigin: (bounds.x, bounds.y))
            render(on: &canvas)
            return
        }
        background = canvas.secondaryColor
        switch mode {
        case .rectangle:
            phase = .drawingRectangle(anchor: pixel)
            bounds = PixelRect(corner: pixel, pixel)
        case .freeForm:
            phase = .drawingLasso
            lasso = [pixel]
            bounds = PixelRect(corner: pixel, pixel)
        }
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        let pixel = event.pixel
        switch phase {
        case .drawingRectangle(let anchor):
            bounds = PixelRect(corner: anchor, pixel).intersection(canvas.bitmap.bounds)
        case .drawingLasso:
            if let last = lasso.last, last != pixel { lasso.append(pixel) }
            bounds = lassoBounds.intersection(canvas.bitmap.bounds)
        case .moving(let from, let start):
            bounds.x = start.x + pixel.x - from.x
            bounds.y = start.y + pixel.y - from.y
            render(on: &canvas)
        case .idle, .selected:
            break
        }
    }

    public mutating func end(_ event: PointerEvent, on canvas: inout Canvas) {
        drag(event, on: &canvas)
        switch phase {
        case .drawingRectangle(let anchor):
            // Un clic sin arrastrar no selecciona nada.
            phase = anchor == event.pixel ? .idle : .selected
        case .drawingLasso:
            if lasso.count >= 3, bounds.width > 1, bounds.height > 1 {
                mask = makeLassoMask()
                lassoAnchor = (bounds.x, bounds.y)
                phase = .selected
            } else {
                phase = .idle
            }
        case .moving:
            phase = .selected
        case .idle, .selected:
            break
        }
        if case .idle = phase { bounds = .zero }
    }

    public mutating func commit(on canvas: inout Canvas) {
        phase = .idle
    }

    public mutating func cancel(on canvas: inout Canvas) {
        phase = .idle
    }

    // MARK: Operaciones

    /// Píxeles seleccionados tal y como se ven ahora (fuera de la máscara, transparentes).
    public func selectedPixels(in canvas: Canvas) -> Bitmap? {
        guard hasSelection else { return nil }
        if let content { return content.masked(by: mask) }
        return canvas.bitmap.cropped(to: bounds)?.masked(by: mask)
    }

    /// Mueve la selección unos píxeles (flechas del teclado).
    public mutating func nudge(dx: Int, dy: Int, on canvas: inout Canvas) {
        guard hasSelection else { return }
        if content == nil { lift(from: canvas, leavingHole: true) }
        bounds.x += dx
        bounds.y += dy
        render(on: &canvas)
    }

    /// Aplica una transformación a los píxeles flotantes (voltear, girar, invertir…).
    public mutating func transform(on canvas: inout Canvas, _ change: (Bitmap) -> Bitmap) {
        guard hasSelection else { return }
        if content == nil { lift(from: canvas, leavingHole: true) }
        guard let current = content else { return }
        let transformed = change(current)
        // La máscara se transforma igual si cambian las dimensiones (giro) o la geometría (volteo).
        if let currentMask = mask {
            let probe = change(currentMask)
            mask = probe.width == transformed.width && probe.height == transformed.height ? probe : nil
        }
        content = transformed
        isTransformed = true
        bounds = PixelRect(x: bounds.x, y: bounds.y, width: transformed.width, height: transformed.height)
        render(on: &canvas)
    }

    /// Borra los píxeles seleccionados (quedan del color secundario). La selección desaparece.
    public mutating func deleteSelection(on canvas: inout Canvas) {
        guard hasSelection else { return }
        if content == nil { lift(from: canvas, leavingHole: true) }
        content = nil
        render(on: &canvas)
        phase = .idle
    }

    public mutating func setTransparent(_ value: Bool, on canvas: inout Canvas) {
        isTransparent = value
        if content != nil { render(on: &canvas) }
    }

    public var overlay: ToolOverlay? {
        switch phase {
        case .drawingLasso:
            return ToolOverlay(
                outline: lasso.map { CGPoint(x: Double($0.x) + 0.5, y: Double($0.y) + 0.5) }, isClosed: false,
                isMarchingAnts: true)
        case .drawingRectangle, .selected, .moving:
            guard !bounds.isEmpty else { return nil }
            if mode == .freeForm, mask != nil, !isTransformed, let anchor = lassoAnchor {
                // El contorno del lazo sigue a la selección cuando se mueve.
                let dx = Double(bounds.x - anchor.x) + 0.5
                let dy = Double(bounds.y - anchor.y) + 0.5
                return ToolOverlay(
                    outline: lasso.map { CGPoint(x: Double($0.x) + dx, y: Double($0.y) + dy) }, isMarchingAnts: true)
            }
            let r = bounds.cgRect
            return ToolOverlay(
                outline: [
                    CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
                    CGPoint(x: r.minX, y: r.maxY),
                ], isMarchingAnts: true)
        case .idle:
            return nil
        }
    }

    // MARK: Internos

    private var lassoBounds: PixelRect {
        let xs = lasso.map(\.x), ys = lasso.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .zero }
        return PixelRect(corner: (minX, minY), (maxX, maxY))
    }

    /// Máscara del lazo del tamaño de `bounds`.
    private func makeLassoMask() -> Bitmap? {
        guard !bounds.isEmpty, let first = lasso.first else { return nil }
        var result = Bitmap(width: bounds.width, height: bounds.height, fill: .clear)
        let path = CGMutablePath()
        let offset = (x: Double(bounds.x), y: Double(bounds.y))
        path.move(to: CGPoint(x: Double(first.x) + 0.5 - offset.x, y: Double(first.y) + 0.5 - offset.y))
        for point in lasso.dropFirst() {
            path.addLine(to: CGPoint(x: Double(point.x) + 0.5 - offset.x, y: Double(point.y) + 0.5 - offset.y))
        }
        path.closeSubpath()
        result.draw(antialiased: false) { context in
            context.setFillColor(PaintColor.white.cgColor)
            context.addPath(path)
            context.fillPath()
            // El borde del lazo también cuenta como seleccionado.
            context.addPath(path)
            context.setStrokeColor(PaintColor.white.cgColor)
            context.setLineWidth(1)
            context.strokePath()
        }
        return result
    }

    private mutating func lift(from canvas: Canvas, leavingHole: Bool) {
        sourceBounds = bounds
        sourceMask = mask
        content = canvas.bitmap.cropped(to: bounds)?.masked(by: mask)
        if let content, content.width != bounds.width || content.height != bounds.height {
            bounds = PixelRect(x: bounds.x, y: bounds.y, width: content.width, height: content.height)
        }
        leavesHole = leavingHole
    }

    /// Redibuja desde el estado inicial: hueco, copias soltadas y los píxeles flotantes en su posición.
    private func render(on canvas: inout Canvas) {
        canvas.revertToEditStart()
        if leavesHole, !sourceBounds.isEmpty {
            canvas.fill(sourceBounds, mask: sourceMask, with: background)
        }
        let key = isTransparent ? background : nil
        for stamp in stamps {
            canvas.composite(stamp.content, mask: stamp.mask, atX: stamp.at.x, y: stamp.at.y, transparentColor: key)
        }
        if let content {
            canvas.composite(content, mask: mask, atX: bounds.x, y: bounds.y, transparentColor: key)
        }
    }
}
