/// Paletas de colores incluidas en StaiN.
///
/// Los valores son propios salvo donde se indica (paletas publicadas para uso libre).
public enum PalettePreset: String, CaseIterable, Sendable, Hashable, Codable {
    /// Los 28 colores clásicos de Paint: fila de arriba oscuros, fila de abajo claros.
    case classic
    /// Tonos actuales, parecidos a los colores del sistema de macOS, con sus versiones claras.
    case modern
    /// Colores muy saturados y brillantes.
    case neon
    /// Tonos suaves y claros.
    case pastels
    /// Del negro al blanco en 16 pasos iguales.
    case grayscale
    /// Marrones, ocres, verdes oliva y arena.
    case earth
    /// 16 colores al estilo de los ordenadores y consolas de 8 bits (para pixel art).
    case retro
    /// 4 tonos de verde, al estilo de las pantallas portátiles antiguas.
    case greenMono
    /// Okabe–Ito (Okabe e Ito, 2008): distinguibles con cualquier tipo de daltonismo.
    case colorblind
    /// Colores habituales en diseño de interfaces web (inspirada en Material Design).
    case web

    public var colors: [PaintColor] { hexValues.compactMap(PaintColor.init(hex:)) }

    var hexValues: [String] {
        switch self {
        case .classic:
            [
                "000000", "808080", "800000", "808000", "008000", "008080", "000080",
                "800080", "808040", "004040", "0080FF", "004080", "8000FF", "804000",
                "FFFFFF", "C0C0C0", "FF0000", "FFFF00", "00FF00", "00FFFF", "0000FF",
                "FF00FF", "FFFF80", "00FF80", "80FFFF", "8080FF", "FF0080", "FF8040",
            ]
        case .modern:
            [
                "1C1C1E", "8E8E93", "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE",
                "30B0C7", "32ADE6", "007AFF", "5856D6", "AF52DE", "FF2D55", "A2845E",
                "FFFFFF", "D1D1D6", "FF8A80", "FFC27A", "FFE680", "8EE6A6", "7FE6DF",
                "8CD7E6", "99D6F2", "80BDFF", "ACAAEB", "D7A8EE", "FF96AA", "D1C1AE",
            ]
        case .neon:
            [
                "0D0D0D", "FF00FF", "FF1493", "FF073A", "FF5F1F", "FFAD00", "FFFF33",
                "CCFF00", "39FF14", "0FFF50", "00FFC8", "00FFFF", "1F51FF", "4D4DFF",
                "FFFFFF", "8F00FF", "BC13FE", "FF10F0", "FE019A", "FF6EC7", "FF9966",
                "FFF44F", "B3FF66", "66FFB2", "7DF9FF", "66B2FF", "B266FF", "2D2D44",
            ]
        case .pastels:
            [
                "FFFFFF", "FFB3BA", "FFDFBA", "FFFFBA", "BAFFC9", "BAE1FF", "D7BAFF",
                "FFC8DD", "FFAFCC", "CDB4DB", "BDE0FE", "A2D2FF", "C5DEDD", "FDE2E4",
                "F2F2F2", "FAD2E1", "E2ECE9", "DBE7E4", "F0EFEB", "D6E2E9", "FFE5B4",
                "E0BBE4", "957DAD", "D291BC", "FEC8D8", "B5EAD7", "C7CEEA", "FFDAC1",
            ]
        case .grayscale:
            (0..<16).map { String(repeating: String(format: "%02X", $0 * 0x11), count: 3) }
        case .earth:
            [
                "2B1D14", "4A3728", "6B4F3A", "8B6B4A", "A0522D", "B5651D", "C68E5A",
                "D2B48C", "E6CFA7", "F5E6CC", "3B4A2A", "556B2F", "6B8E23", "8F9779",
                "A9BA9D", "C2B280", "8E7F5A", "5C4E3A", "7A6A53", "BFA98A",
            ]
        case .retro:
            [
                "000000", "2E2E4F", "6B2D5C", "1E7F4C", "A65E2E", "5E5E5E", "BDBDBD", "F4F0E6",
                "E83B3B", "F7941D", "F9E04B", "4CC34B", "3A8FE8", "7A5FB0", "F06BA8", "F2C9A0",
            ]
        case .greenMono:
            ["0E2A12", "2F5A2A", "7FA23A", "C4D88A"]
        case .colorblind:
            ["000000", "E69F00", "56B4E9", "009E73", "F0E442", "0072B2", "D55E00", "CC79A7", "FFFFFF", "999999"]
        case .web:
            [
                "F44336", "E91E63", "9C27B0", "673AB7", "3F51B5", "2196F3", "03A9F4", "00BCD4", "009688", "4CAF50",
                "8BC34A", "CDDC39", "FFEB3B", "FFC107", "FF9800", "FF5722", "795548", "9E9E9E", "607D8B", "000000",
            ]
        }
    }
}
