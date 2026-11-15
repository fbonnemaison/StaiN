import Foundation
import Observation
import StainKit

/// Paletas y colores personalizados, compartidos por todas las ventanas
/// y guardados en `UserDefaults`.
///
/// - La paleta visible sale de una paleta incluida o de una importada desde archivo, y no se edita.
/// - Los colores personalizados (hasta 28, en 2 filas de 1 a 14 columnas) son independientes
///   de la paleta elegida y se pueden guardar como paleta JSON.
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

    /// Paleta cargada desde un archivo `.json`, `.gpl` o `.hex`.
    struct ImportedPalette: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var colors: [String]

        var paintColors: [PaintColor] { colors.compactMap(PaintColor.init(hex:)) }
    }

    /// Casillas personalizadas que se guardan (2 filas × 14 columnas como máximo).
    static let customSlotCount = 28
    static let customColumnsRange = 1...14
    static let defaultCustomColumns = 4
    /// Clave de `UserDefaults` (y `@AppStorage`) con las columnas visibles de colores personalizados.
    static let customColumnsKey = "customColorColumns"
    static let maxImported = 12

    private(set) var colors: [PaintColor]
    private(set) var source: Source
    private(set) var imported: [ImportedPalette]
    /// Casillas personalizadas; `nil` = vacía.
    private(set) var customColors: [PaintColor?]

    /// Columnas de la cuadrícula de 2 filas.
    var columns: Int { max(1, (colors.count + 1) / 2) }

    private let defaults: UserDefaults
    private enum Key {
        static let source = "paletteSource"
        static let imported = "importedPalettes"
        static let custom = "customColors"
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
        colors = Self.colors(for: source, imported: loaded)
        // Las versiones anteriores permitían editar la paleta; esas ediciones ya no se usan.
        defaults.removeObject(forKey: "paletteColors")
        defaults.removeObject(forKey: "paletteModified")
        let custom = (defaults.stringArray(forKey: Key.custom) ?? []).map { PaintColor(hex: $0) }
        customColors = (0..<Self.customSlotCount).map { $0 < custom.count ? custom[$0] : nil }
        // Las versiones anteriores guardaban colores recientes; ya no se usan.
        defaults.removeObject(forKey: "recentColors")
    }

    private static func colors(for source: Source, imported: [ImportedPalette]) -> [PaintColor] {
        switch source {
        case .preset(let preset): preset.colors
        case .imported(let id): imported.first { $0.id == id }?.paintColors ?? PalettePreset.classic.colors
        }
    }

    // MARK: Paleta visible

    /// Cambia a otra paleta.
    func select(_ newSource: Source) {
        source = newSource
        colors = Self.colors(for: newSource, imported: imported)
        save()
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

    func clearCustomColors() {
        for index in customColors.indices { customColors[index] = nil }
        defaults.set(customColors.map { _ in "" }, forKey: Key.custom)
    }

    /// Colores personalizados no vacíos, en orden.
    var filledCustomColors: [PaintColor] { customColors.compactMap(\.self) }

    private func save() {
        defaults.set(source.key, forKey: Key.source)
        defaults.set(try? JSONEncoder().encode(imported), forKey: Key.imported)
    }
}
