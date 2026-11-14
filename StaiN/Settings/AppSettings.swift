import Foundation

/// Preferencias guardadas en `UserDefaults`. Se pueden sobrescribir al lanzar la app (`-canvasWidth 320`).
enum AppSettings {
    enum Key {
        static let canvasWidth = "canvasWidth"
        static let canvasHeight = "canvasHeight"
        static let jpegQuality = "jpegQuality"
        static let gridSpacing = "gridSpacing"
    }

    static let defaultGridSpacing = 16

    /// Separación de la cuadrícula en píxeles de imagen.
    static var gridSpacing: Int {
        let value = UserDefaults.standard.integer(forKey: Key.gridSpacing)
        return value > 0 ? min(value, 1024) : defaultGridSpacing
    }

    static let defaultCanvasWidth = 800
    static let defaultCanvasHeight = 600
    static let defaultJPEGQuality = 0.9
    static let maxCanvasSide = 16_384

    /// Tamaño del lienzo para documentos nuevos.
    static var newCanvasSize: (width: Int, height: Int) {
        let defaults = UserDefaults.standard
        func side(_ key: String, _ fallback: Int) -> Int {
            let value = defaults.integer(forKey: key)
            return value > 0 ? min(value, maxCanvasSide) : fallback
        }
        return (side(Key.canvasWidth, defaultCanvasWidth), side(Key.canvasHeight, defaultCanvasHeight))
    }

    /// Calidad (0–1) al guardar en JPEG o HEIC.
    static var jpegQuality: Double {
        let value = UserDefaults.standard.object(forKey: Key.jpegQuality) as? Double
        return min(max(value ?? defaultJPEGQuality, 0.05), 1)
    }
}
