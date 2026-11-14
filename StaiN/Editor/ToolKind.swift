import StainKit

/// Herramientas del panel. Cada una crea una herramienta nueva de StainKit al empezar un trazo.
enum ToolKind: String, CaseIterable, Identifiable {
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
    case zoom
    case bomb

    var id: Self { self }

    var title: String {
        switch self {
        case .pencil: "Lápiz"
        case .brush: "Pincel"
        case .airbrush: "Aerógrafo"
        case .eraser: "Borrador"
        case .fill: "Relleno"
        case .eyedropper: "Cuentagotas"
        case .text: "Texto"
        case .line: "Línea"
        case .curve: "Curva"
        case .rectangle: "Rectángulo"
        case .roundedRectangle: "Rectángulo redondeado"
        case .ellipse: "Elipse"
        case .polygon: "Polígono"
        case .zoom: "Lupa"
        case .bomb: "Bomba"
        }
    }

    var systemImage: String {
        switch self {
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
        case .zoom: "magnifyingglass"
        case .bomb: "burst"
        }
    }

    /// Atajo de una tecla (la bomba no tiene, para no borrar la imagen sin querer).
    var shortcut: Character? {
        switch self {
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
        case .zoom: "z"
        case .bomb: nil
        }
    }

    /// Las formas usan el modo de relleno y el grosor de línea compartidos.
    var usesShapeOptions: Bool {
        [.rectangle, .roundedRectangle, .ellipse, .polygon].contains(self)
    }

    /// Herramienta de dibujo configurada con las opciones actuales, o `nil` si la gestiona la vista (lupa, texto).
    @MainActor
    func makeTool(options: EditorState) -> (any Tool)? {
        let fill = options.shapeFillMode
        let width = options.shapeLineWidth
        return switch self {
        case .pencil: PencilTool()
        case .brush: BrushTool(shape: options.brushShape, size: options.brushSize)
        case .airbrush: AirbrushTool(radius: options.airbrushRadius)
        case .eraser: EraserTool(size: options.eraserSize, erasesToTransparent: options.erasesToTransparent)
        case .fill: FillTool(tolerance: UInt8((options.fillTolerance * 255).rounded()))
        case .eyedropper: EyedropperTool()
        case .line: LineTool(width: options.lineWidth)
        case .curve: CurveTool(lineWidth: options.lineWidth)
        case .rectangle: ShapeTool(kind: .rectangle, fillMode: fill, lineWidth: width)
        case .roundedRectangle: ShapeTool(kind: .roundedRectangle, fillMode: fill, lineWidth: width)
        case .ellipse: ShapeTool(kind: .ellipse, fillMode: fill, lineWidth: width)
        case .polygon: PolygonTool(fillMode: fill, lineWidth: width)
        case .bomb: BombTool()
        case .zoom, .text: nil
        }
    }
}
