import StainKit

/// Herramientas del panel. Cada una crea una herramienta nueva de StainKit al empezar un trazo.
enum ToolKind: String, CaseIterable, Identifiable {
    case freeFormSelect
    case select
    case pencil
    case brush
    case airbrush
    case eraser
    case fill
    case eyedropper
    case text
    case line
    case curve
    case rectangle
    case roundedRectangle
    case ellipse
    case polygon
    case arrow
    case highlighter
    case redact
    case marker
    case zoom
    case bomb

    var id: Self { self }

    var title: String {
        switch self {
        case .freeFormSelect: String(localized: "Selección libre")
        case .select: String(localized: "Selección")
        case .pencil: String(localized: "Lápiz")
        case .brush: String(localized: "Pincel")
        case .airbrush: String(localized: "Aerógrafo")
        case .eraser: String(localized: "Borrador")
        case .fill: String(localized: "Relleno")
        case .eyedropper: String(localized: "Cuentagotas")
        case .text: String(localized: "Texto")
        case .line: String(localized: "Línea")
        case .curve: String(localized: "Curva")
        case .rectangle: String(localized: "Rectángulo")
        case .roundedRectangle: String(localized: "Rectángulo redondeado")
        case .ellipse: String(localized: "Elipse")
        case .polygon: String(localized: "Polígono")
        case .arrow: String(localized: "Flecha")
        case .highlighter: String(localized: "Resaltador")
        case .redact: String(localized: "Ocultar")
        case .marker: String(localized: "Marcador numerado")
        case .zoom: String(localized: "Lupa")
        case .bomb: String(localized: "Bomba")
        }
    }

    var systemImage: String {
        switch self {
        case .freeFormSelect: "lasso"
        case .select: "rectangle.dashed"
        case .pencil: "pencil"
        case .brush: "paintbrush.pointed"
        case .airbrush: "aqi.medium"
        case .eraser: "eraser"
        case .fill: "drop.fill"
        case .eyedropper: "eyedropper"
        case .text: "textformat"
        case .line: "line.diagonal"
        case .curve: "point.topleft.down.curvedto.point.bottomright.up"
        case .rectangle: "rectangle"
        case .roundedRectangle: "app"
        case .ellipse: "oval"
        case .polygon: "pentagon"
        case .arrow: "arrow.up.right"
        case .highlighter: "highlighter"
        case .redact: "eye.slash"
        case .marker: "1.circle"
        case .zoom: "magnifyingglass"
        case .bomb: "burst"
        }
    }

    /// Atajo de una tecla (la bomba no tiene, para no borrar la imagen sin querer).
    var shortcut: Character? {
        switch self {
        case .freeFormSelect: "q"
        case .select: "s"
        case .pencil: "p"
        case .brush: "b"
        case .airbrush: "a"
        case .eraser: "e"
        case .fill: "f"
        case .eyedropper: "i"
        case .text: "t"
        case .line: "l"
        case .curve: "c"
        case .rectangle: "r"
        case .roundedRectangle: "u"
        case .ellipse: "o"
        case .polygon: "g"
        case .arrow: "w"
        case .highlighter: "h"
        case .redact: "k"
        case .marker: "n"
        case .zoom: "z"
        case .bomb: nil
        }
    }

    var isSelection: Bool { self == .select || self == .freeFormSelect }

    /// Las formas usan el modo de relleno y el grosor de línea compartidos.
    var usesShapeOptions: Bool {
        [.rectangle, .roundedRectangle, .ellipse, .polygon].contains(self)
    }

    /// Herramientas de trazo libre, que admiten simetría.
    var isFreehand: Bool { [.pencil, .brush, .eraser, .airbrush].contains(self) }

    /// Herramienta de dibujo configurada con las opciones actuales, o `nil` si la gestiona la vista (lupa, texto).
    @MainActor
    func makeTool(options: EditorState, canvasWidth: Int, canvasHeight: Int) -> (any Tool)? {
        guard let base = makeBaseTool(options: options) else { return nil }
        guard isFreehand, !options.symmetry.isEmpty else { return base }
        return MirroredTool(symmetry: options.symmetry, canvasWidth: canvasWidth, canvasHeight: canvasHeight) {
            makeBaseTool(options: options) ?? base
        }
    }

    @MainActor
    private func makeBaseTool(options: EditorState) -> (any Tool)? {
        let fill = options.shapeFillMode
        let width = options.shapeLineWidth
        let smooth = !options.pixelMode
        return switch self {
        case .freeFormSelect: SelectionTool(mode: .freeForm, isTransparent: options.transparentSelection)
        case .select: SelectionTool(mode: .rectangle, isTransparent: options.transparentSelection)
        case .pencil: PencilTool()
        case .brush: BrushTool(shape: options.brushShape, size: options.brushSize, usesPressure: true)
        case .airbrush: AirbrushTool(radius: options.airbrushRadius)
        case .eraser: EraserTool(size: options.eraserSize, erasesToTransparent: options.erasesToTransparent)
        case .fill: FillTool(tolerance: UInt8((options.fillTolerance * 255).rounded()))
        case .eyedropper: EyedropperTool()
        case .line: LineTool(width: options.lineWidth)
        case .curve: CurveTool(lineWidth: options.lineWidth)
        case .rectangle: ShapeTool(kind: .rectangle, fillMode: fill, lineWidth: width)
        case .roundedRectangle: ShapeTool(kind: .roundedRectangle, fillMode: fill, lineWidth: width)
        case .ellipse: ShapeTool(kind: .ellipse, fillMode: fill, lineWidth: width)
        case .polygon:
            if let kind = options.polygonShape {
                ShapeTool(kind: kind, fillMode: fill, lineWidth: width)
            } else {
                PolygonTool(fillMode: fill, lineWidth: width)
            }
        case .arrow: ArrowTool(lineWidth: options.arrowWidth, antialiased: smooth)
        case .highlighter: HighlighterTool(size: options.highlighterSize, antialiased: smooth)
        case .redact: RedactTool(mode: options.redactMode)
        case .marker: StepMarkerTool(number: options.nextMarker, radius: options.markerRadius, antialiased: smooth)
        case .bomb: BombTool()
        case .zoom, .text: nil
        }
    }
}
