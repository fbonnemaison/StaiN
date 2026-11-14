import StainKit

/// Filtros del menú, con sus parámetros ajustables en el diálogo.
enum FilterKind: String, CaseIterable, Identifiable, Hashable {
    case grayscale
    case sepia
    case invert
    case adjustments
    case blur
    case sharpen
    case pixelate
    case posterize
    case threshold

    var id: Self { self }

    var title: String {
        switch self {
        case .grayscale: "Escala de grises"
        case .sepia: "Sepia"
        case .invert: "Invertir"
        case .adjustments: "Brillo, contraste y saturación"
        case .blur: "Desenfoque"
        case .sharpen: "Enfocar"
        case .pixelate: "Pixelar"
        case .posterize: "Posterizar"
        case .threshold: "Umbral (blanco y negro)"
        }
    }

    struct Parameter: Identifiable {
        let id: String
        let title: String
        let range: ClosedRange<Double>
        let defaultValue: Double
        /// Se escala con la imagen en la vista previa (radios y tamaños en píxeles).
        var isPixelSize = false
    }

    var parameters: [Parameter] {
        switch self {
        case .grayscale, .invert: []
        case .sepia: [Parameter(id: "intensity", title: "Intensidad", range: 0...1, defaultValue: 1)]
        case .adjustments:
            [
                Parameter(id: "brightness", title: "Brillo", range: -0.5...0.5, defaultValue: 0),
                Parameter(id: "contrast", title: "Contraste", range: 0.25...2, defaultValue: 1),
                Parameter(id: "saturation", title: "Saturación", range: 0...2, defaultValue: 1),
            ]
        case .blur: [Parameter(id: "radius", title: "Radio (px)", range: 0.5...40, defaultValue: 4, isPixelSize: true)]
        case .sharpen: [Parameter(id: "amount", title: "Intensidad", range: 0...2, defaultValue: 0.6)]
        case .pixelate:
            [Parameter(id: "block", title: "Tamaño del bloque (px)", range: 2...64, defaultValue: 8, isPixelSize: true)]
        case .posterize: [Parameter(id: "levels", title: "Niveles", range: 2...16, defaultValue: 4)]
        case .threshold: [Parameter(id: "level", title: "Umbral", range: 0...1, defaultValue: 0.5)]
        }
    }

    /// Filtro con los valores dados. `pixelScale` reduce los tamaños en píxeles para la vista previa.
    func filter(_ values: [String: Double], pixelScale: Double = 1) -> ImageFilter {
        func value(_ id: String) -> Double {
            let parameter = parameters.first { $0.id == id }
            let raw = values[id] ?? parameter?.defaultValue ?? 0
            return parameter?.isPixelSize == true ? raw * pixelScale : raw
        }
        return switch self {
        case .grayscale: .grayscale
        case .sepia: .sepia(intensity: value("intensity"))
        case .invert: .invert
        case .adjustments:
            .colorControls(
                brightness: value("brightness"), contrast: value("contrast"), saturation: value("saturation"))
        case .blur: .blur(radius: value("radius"))
        case .sharpen: .sharpen(amount: value("amount"))
        case .pixelate: .pixelate(blockSize: max(1, Int(value("block").rounded())))
        case .posterize: .posterize(levels: Int(value("levels").rounded()))
        case .threshold: .threshold(level: value("level"))
        }
    }
}
