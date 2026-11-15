import StainKit

extension PalettePreset {
    var title: String {
        switch self {
        case .classic: String(localized: "Clásica")
        case .modern: String(localized: "Moderna")
        case .neon: String(localized: "Neón")
        case .pastels: String(localized: "Pasteles")
        case .grayscale: String(localized: "Escala de grises")
        case .earth: String(localized: "Tierra")
        case .retro: String(localized: "Retro 8 bits")
        case .greenMono: String(localized: "Verde 4 tonos")
        case .colorblind: String(localized: "Apta para daltonismo")
        case .web: String(localized: "Interfaz web")
        }
    }
}
