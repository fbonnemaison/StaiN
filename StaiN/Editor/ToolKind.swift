import StainKit

/// Herramientas del panel. Cada una crea una herramienta nueva de StainKit al empezar un trazo.
enum ToolKind: String, CaseIterable, Identifiable {
    case pencil
    case brush
    case eraser
    case fill
    case eyedropper
    case line
    case zoom

    var id: Self { self }

    var title: String {
        switch self {
        case .pencil: "Lápiz"
        case .brush: "Pincel"
        case .eraser: "Borrador"
        case .fill: "Relleno"
        case .eyedropper: "Cuentagotas"
        case .line: "Línea"
        case .zoom: "Lupa"
        }
    }

    var systemImage: String {
        switch self {
        case .pencil: "pencil"
        case .brush: "paintbrush.pointed"
        case .eraser: "eraser"
        case .fill: "drop.fill"
        case .eyedropper: "eyedropper"
        case .line: "line.diagonal"
        case .zoom: "magnifyingglass"
        }
    }

    /// Atajo de una tecla.
    var shortcut: Character {
        switch self {
        case .pencil: "p"
        case .brush: "b"
        case .eraser: "e"
        case .fill: "f"
        case .eyedropper: "i"
        case .line: "l"
        case .zoom: "z"
        }
    }

    /// Herramienta de dibujo configurada con las opciones actuales, o `nil` si solo actúa sobre la vista (lupa).
    @MainActor
    func makeTool(options: EditorState) -> (any Tool)? {
        switch self {
        case .pencil: PencilTool()
        case .brush: BrushTool(shape: options.brushShape, size: options.brushSize)
        case .eraser: EraserTool(size: options.eraserSize, erasesToTransparent: options.erasesToTransparent)
        case .fill: FillTool(tolerance: UInt8((options.fillTolerance * 255).rounded()))
        case .eyedropper: EyedropperTool()
        case .line: LineTool(width: options.lineWidth)
        case .zoom: nil
        }
    }
}
