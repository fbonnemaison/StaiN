import Foundation
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

    @Test func jsonPaletteRoundTripKeepsName() throws {
        let colors = [PaintColor(red: 255, green: 0, blue: 0), PaintColor(red: 0, green: 128, blue: 255)]
        let data = try PaletteFile.json(name: "Mis colores", colors: colors)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"stain-palette\""))
        let read = PaletteFile.read(data)
        #expect(read.name == "Mis colores")
        #expect(read.colors == colors)
    }

    @Test func readAcceptsMinimalJSONAndOtherFormats() {
        let minimal = PaletteFile.read(Data(##"{"colors": ["#000000", "nope", "#FFFFFF"]}"##.utf8))
        #expect(minimal.name == nil && minimal.colors.count == 2)
        let gpl = PaletteFile.read(Data("GIMP Palette\nName: Retro\n#\n255 0 0\tRojo\n".utf8))
        #expect(gpl.name == "Retro" && gpl.colors == [PaintColor(red: 255, green: 0, blue: 0)])
        let hex = PaletteFile.read(Data("ff0000\n00ff00\n".utf8))
        #expect(hex.name == nil && hex.colors.count == 2)
    }
}
