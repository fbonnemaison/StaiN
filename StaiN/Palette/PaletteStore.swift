import Foundation
import Observation
import StainKit

/// Paletas, colores personalizados y colores recientes, compartidos por todas las ventanas
/// y guardados en `UserDefaults`.
///
/// - La paleta visible sale de una paleta incluida o de una importada desde archivo, y se puede editar
///   (doble clic en una muestra). "Restaurar" vuelve a sus colores originales.
/// - Los 8 colores personalizados son independientes de la paleta elegida.
@MainActor @Observable
final class PaletteStore {
    static let shared = PaletteStore()

    /// De dónde sale la paleta visible.
    enum Source: Hashable, Sendable {
        case preset(PalettePreset)
        case imported(UUID)

        var key: String {
            switch self {
            case .preset(let preset): "preset.\(preset.rawValue)"
            case .imported(let id): "imported.\(id.uuidString)"
            }
        }

        init?(key: String) {
            if key.hasPrefix("preset."), let preset = PalettePreset(rawValue: String(key.dropFirst(7))) {
                self = .preset(preset)
            } else if key.hasPrefix("imported."), let id = UUID(uuidString: String(key.dropFirst(9))) {
                self = .imported(id)
            } else {
                return nil
            }
        }
    }

    /// Paleta cargada desde un archivo `.gpl` o `.hex`.
    struct ImportedPalette: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var colors: [String]

        var paintColors: [PaintColor] { colors.compactMap(PaintColor.init(hex:)) }
    }

    static let customSlotCount = 8
    static let maxRecent = 10
    static let maxImported = 12

    private(set) var colors: [PaintColor]
    private(set) var source: Source
    /// La paleta visible tiene muestras editadas respecto a su origen.
    private(set) var isModified: Bool
    private(set) var imported: [ImportedPalette]
    /// 8 casillas; `nil` = vacía.
    private(set) var customColors: [PaintColor?]
    private(set) var recent: [PaintColor]

    /// Columnas de la cuadrícula de 2 filas.
    var columns: Int { max(1, (colors.count + 1) / 2) }

    private let defaults: UserDefaults
    private enum Key {
        static let colors = "paletteColors"
        static let source = "paletteSource"
        static let modified = "paletteModified"
        static let imported = "importedPalettes"
        static let custom = "customColors"
        static let recent = "recentColors"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded =
            defaults.data(forKey: Key.imported).flatMap {
                try? JSONDecoder().decode([ImportedPalette].self, from: $0)
            } ?? []
        imported = loaded
        var source = defaults.string(forKey: Key.source).flatMap(Source.init(key:)) ?? .preset(.classic)
        if case .imported(let id) = source, !loaded.contains(where: { $0.id == id }) { source = .preset(.classic) }
        self.source = source
        let saved = (defaults.stringArray(forKey: Key.colors) ?? []).compactMap(PaintColor.init(hex:))
        let original = Self.colors(for: source, imported: loaded)
        colors = saved.isEmpty ? original : saved
        isModified = !saved.isEmpty && saved != original
        let custom = (defaults.stringArray(forKey: Key.custom) ?? []).map { PaintColor(hex: $0) }
        customColors = (0..<Self.customSlotCount).map { $0 < custom.count ? custom[$0] : nil }
        recent = (defaults.stringArray(forKey: Key.recent) ?? []).compactMap(PaintColor.init(hex:))
    }

    private static func colors(for source: Source, imported: [ImportedPalette]) -> [PaintColor] {
        switch source {
        case .preset(let preset): preset.colors
        case .imported(let id): imported.first { $0.id == id }?.paintColors ?? PalettePreset.classic.colors
        }
    }

    // MARK: Paleta visible

    /// Cambia a otra paleta (se pierden las ediciones de la actual).
    func select(_ newSource: Source) {
        source = newSource
        colors = Self.colors(for: newSource, imported: imported)
        isModified = false
        save()
    }

    /// Edita una muestra de la paleta visible.
    func setColor(_ color: PaintColor, at index: Int) {
        guard colors.indices.contains(index) else { return }
        colors[index] = color
        isModified = colors != Self.colors(for: source, imported: imported)
        save()
    }

    /// Vuelve a los colores originales de la paleta elegida.
    func resetColors() {
        select(source)
    }

    /// Añade una paleta de archivo al selector y la elige. Si ya había una con el mismo nombre, la sustituye.
    func importPalette(named name: String, colors newColors: [PaintColor]) {
        guard !newColors.isEmpty else { return }
        let hexes = newColors.prefix(256).map(\.hex)
        if let index = imported.firstIndex(where: { $0.name == name }) {
            imported[index].colors = Array(hexes)
            select(.imported(imported[index].id))
        } else {
            let palette = ImportedPalette(id: UUID(), name: name, colors: Array(hexes))
            imported.append(palette)
            if imported.count > Self.maxImported { imported.removeFirst(imported.count - Self.maxImported) }
            select(.imported(palette.id))
        }
    }

    /// Quita una paleta importada del selector (si estaba elegida, se vuelve a la clásica).
    func removeImported(_ id: UUID) {
        imported.removeAll { $0.id == id }
        if source == .imported(id) { select(.preset(.classic)) } else { save() }
    }

    // MARK: Colores personalizados

    func setCustomColor(_ color: PaintColor?, at index: Int) {
        guard customColors.indices.contains(index) else { return }
        customColors[index] = color
        defaults.set(customColors.map { $0?.hex ?? "" }, forKey: Key.custom)
    }

    // MARK: Recientes

    /// Recuerda un color usado que no esté en la paleta (el más reciente primero).
    func noteUsed(_ color: PaintColor) {
        guard !colors.contains(color) else { return }
        recent.removeAll { $0 == color }
        recent.insert(color, at: 0)
        if recent.count > Self.maxRecent { recent.removeLast(recent.count - Self.maxRecent) }
        defaults.set(recent.map(\.hex), forKey: Key.recent)
    }

    private func save() {
        defaults.set(source.key, forKey: Key.source)
        defaults.set(isModified, forKey: Key.modified)
        if isModified {
            defaults.set(colors.map(\.hex), forKey: Key.colors)
        } else {
            defaults.removeObject(forKey: Key.colors)
        }
        defaults.set(try? JSONEncoder().encode(imported), forKey: Key.imported)
    }
}
