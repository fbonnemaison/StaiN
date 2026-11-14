import Foundation
import Observation

/// Estado de una ventana de edición: herramienta, zoom y posición del cursor.
@MainActor @Observable
final class EditorState {
    struct PixelPosition: Equatable {
        var x: Int
        var y: Int
    }

    var tool: ToolKind = .pencil
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
