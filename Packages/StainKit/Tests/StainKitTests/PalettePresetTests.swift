import Testing

@testable import StainKit

@Suite struct PalettePresetTests {
    @Test(arguments: PalettePreset.allCases)
    func everyHexIsValidAndUnique(preset: PalettePreset) {
        #expect(preset.colors.count == preset.hexValues.count, "Todos los valores son HEX válidos")
        #expect(Set(preset.colors).count == preset.colors.count, "Sin colores repetidos")
        #expect(preset.colors.count >= 4)
    }

    @Test func classicIsPaintPalette() {
        let classic = PalettePreset.classic.colors
        #expect(classic.count == 28)
        #expect(classic.first == .black)
        #expect(classic[14] == .white)
    }

    @Test func grayscaleGoesFromBlackToWhite() {
        let grays = PalettePreset.grayscale.colors
        #expect(grays.count == 16)
        #expect(grays.first == .black && grays.last == .white)
        #expect(
            zip(grays, grays.dropFirst()).allSatisfy { $0.red < $1.red && $1.red == $1.green && $1.green == $1.blue })
    }

    @Test func colorblindIsOkabeIto() {
        #expect(PalettePreset.colorblind.colors[1] == PaintColor(hex: "E69F00"))
    }
}
