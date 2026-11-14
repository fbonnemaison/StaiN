import Foundation
import Observation
import StainKit

/// Estado de una ventana de edición: herramienta, zoom y posición del cursor.
@MainActor @Observable
final class EditorState {
    struct PixelPosition: Equatable {
        var x: Int
        var y: Int
    }

    var tool: ToolKind = .pencil {
        didSet {
            if oldValue != tool && oldValue != .eyedropper { previousTool = oldValue }
        }
    }
    private(set) var previousTool: ToolKind = .pencil

    // Opciones de las herramientas
    var brushShape: BrushShape = .round
    var brushSize = 3
    var eraserSize = 8
    var erasesToTransparent = false
    /// 0 = color exacto, 1 = todo.
    var fillTolerance = 0.0
    var lineWidth = 1

    /// "Selección transparente": al mover o pegar, el color secundario no tapa lo de debajo.
    var transparentSelection = false
    /// Tamaño de la selección actual (barra de estado).
    var selectionSize: PixelPosition?
    var showsGrid = false

    enum Sheet: String, Identifiable {
        case resize
        case canvasSize
        var id: Self { self }
    }
    var activeSheet: Sheet?

    var shapeFillMode: ShapeFillMode = .outline
    var shapeLineWidth = 1
    var airbrushRadius = 8

    // Texto
    var fontFamily = "Helvetica"
    var fontSize = 24.0
    var isBold = false
    var isItalic = false
    var isUnderlined = false
    /// Fondo del texto con el color secundario (opaco) o transparente.
    var hasOpaqueTextBackground = false

    func textStyle(primary: PaintColor, secondary: PaintColor) -> TextStyle {
        TextStyle(
            fontName: fontFamily, size: fontSize, bold: isBold, italic: isItalic, underline: isUnderlined,
            color: primary, background: hasOpaqueTextBackground ? secondary : nil)
    }

    static let brushSizes = [1, 2, 3, 5, 8, 12, 16, 24]
    static let airbrushRadii = [4, 8, 12, 16]
    static let fontSizes: [Double] = [8, 10, 12, 14, 18, 24, 36, 48, 72, 96]
    static let eraserSizes = [4, 6, 8, 10, 16, 24, 32]
    static let lineWidths = [1, 2, 3, 5, 8]

    func returnToPreviousTool() {
        tool = previousTool
    }
    /// 1 = 100 %.
    var zoom: Double = 1
    var cursor: PixelPosition?

    static let minZoom = 0.125
    static let maxZoom = 32.0
    static let zoomLevels: [Double] = [0.125, 0.25, 1.0 / 3, 0.5, 2.0 / 3, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32]

    static func level(after zoom: Double) -> Double {
        zoomLevels.first { $0 > zoom * 1.001 } ?? maxZoom
    }

    static func level(before zoom: Double) -> Double {
        zoomLevels.last { $0 < zoom / 1.001 } ?? minZoom
    }

    var canZoomIn: Bool { zoom < Self.maxZoom / 1.001 }
    var canZoomOut: Bool { zoom > Self.minZoom * 1.001 }

    func zoomIn() { zoom = Self.level(after: zoom) }
    func zoomOut() { zoom = Self.level(before: zoom) }
    func actualSize() { zoom = 1 }
}
