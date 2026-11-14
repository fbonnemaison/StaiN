import AppKit
import StainKit
import UniformTypeIdentifiers

/// Preferencias guardadas en `UserDefaults`. Se pueden sobrescribir al lanzar la app (`-canvasWidth 320`).
enum AppSettings {
    enum Key {
        static let canvasWidth = "canvasWidth"
        static let canvasHeight = "canvasHeight"
        static let jpegQuality = "jpegQuality"
        static let gridSpacing = "gridSpacing"
        static let appearance = "appearance"
        static let saveFormat = "saveFormat"
        static let pixelModeByDefault = "pixelModeByDefault"
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: Self { self }
    }

    static var appearance: Appearance {
        UserDefaults.standard.string(forKey: Key.appearance).flatMap(Appearance.init) ?? .system
    }

    /// Aplica la apariencia elegida a toda la app (ventanas, menús y paneles).
    @MainActor
    static func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Formato que se propone al guardar un documento nuevo.
    static var saveFormat: UTType {
        UserDefaults.standard.string(forKey: Key.saveFormat).flatMap { UTType($0) }
            .flatMap { type in ImageCodec.supportedTypes.first { $0 == type } } ?? .png
    }

    static var pixelModeByDefault: Bool {
        UserDefaults.standard.bool(forKey: Key.pixelModeByDefault)
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
