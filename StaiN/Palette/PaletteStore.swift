import Foundation
import Observation
import StainKit

/// Paleta de colores editable y colores recientes, compartidos por todas las ventanas y guardados en `UserDefaults`.
@MainActor @Observable
final class PaletteStore {
    static let shared = PaletteStore()

    /// Los 28 colores clásicos de Paint: fila de arriba oscuros, fila de abajo claros.
    static let defaultColors: [PaintColor] = [
        "000000", "808080", "800000", "808000", "008000", "008080", "000080",
        "800080", "808040", "004040", "0080FF", "004080", "8000FF", "804000",
        "FFFFFF", "C0C0C0", "FF0000", "FFFF00", "00FF00", "00FFFF", "0000FF",
        "FF00FF", "FFFF80", "00FF80", "80FFFF", "8080FF", "FF0080", "FF8040",
    ].compactMap { PaintColor(hex: $0) }

    /// Columnas de la cuadrícula de 2 filas.
    var columns: Int { max(1, (colors.count + 1) / 2) }
    static let maxRecent = 10

    private(set) var colors: [PaintColor]
    private(set) var recent: [PaintColor]

    private let defaults: UserDefaults
    private enum Key {
        static let colors = "paletteColors"
        static let recent = "recentColors"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = (defaults.stringArray(forKey: Key.colors) ?? []).compactMap(PaintColor.init(hex:))
        colors = saved.isEmpty ? Self.defaultColors : saved
        recent = (defaults.stringArray(forKey: Key.recent) ?? []).compactMap(PaintColor.init(hex:))
    }

    func setColor(_ color: PaintColor, at index: Int) {
        guard colors.indices.contains(index) else { return }
        colors[index] = color
        defaults.set(colors.map(\.hex), forKey: Key.colors)
    }

    /// Sustituye la paleta entera (paletas cargadas de archivo, hasta 256 colores).
    func setColors(_ newColors: [PaintColor]) {
        guard !newColors.isEmpty else { return }
        colors = Array(newColors.prefix(256))
        defaults.set(colors.map(\.hex), forKey: Key.colors)
    }

    func resetColors() {
        colors = Self.defaultColors
        defaults.removeObject(forKey: Key.colors)
    }

    /// Recuerda un color usado que no esté en la paleta (el más reciente primero).
    func noteUsed(_ color: PaintColor) {
        guard !colors.contains(color) else { return }
        recent.removeAll { $0 == color }
        recent.insert(color, at: 0)
        if recent.count > Self.maxRecent { recent.removeLast(recent.count - Self.maxRecent) }
        defaults.set(recent.map(\.hex), forKey: Key.recent)
    }
}
