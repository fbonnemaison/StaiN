import Foundation

/// Lectura y escritura de paletas: JSON propio de StaiN, GIMP (`.gpl`) y lista hexadecimal (`.hex`, como Lospec).
public enum PaletteFile {
    /// Paleta con nombre, tal como se guarda en JSON:
    /// `{"format": "stain-palette", "version": 1, "name": "…", "colors": ["#RRGGBB", …]}`.
    public struct Named: Codable, Sendable, Equatable {
        public var format = "stain-palette"
        public var version = 1
        public var name: String
        public var colors: [String]

        public init(name: String, colors: [PaintColor]) {
            self.name = name
            self.colors = colors.map(\.hex)
        }

        public var paintColors: [PaintColor] { colors.compactMap(PaintColor.init(hex:)) }

        private enum CodingKeys: String, CodingKey { case format, version, name, colors }

        /// Solo exige `colors`; el resto es opcional para aceptar JSON escritos a mano.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try container.decodeIfPresent(String.self, forKey: .format) ?? "stain-palette"
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            colors = try container.decode([String].self, forKey: .colors)
        }
    }

    public static func json(name: String, colors: [PaintColor]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Named(name: name, colors: colors))
    }

    /// Lee un archivo de paleta de cualquier formato admitido. El nombre sale del JSON o de la línea
    /// `Name:` del `.gpl`; si no hay, es `nil`.
    public static func read(_ data: Data) -> (name: String?, colors: [PaintColor]) {
        if let named = try? JSONDecoder().decode(Named.self, from: data) {
            let name = named.name.trimmingCharacters(in: .whitespaces)
            return (name.isEmpty ? nil : name, named.paintColors)
        }
        guard let text = String(data: data, encoding: .utf8) else { return (nil, []) }
        let name = text.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("Name:") }
            .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }
        return (name?.isEmpty == false ? name : nil, parse(text))
    }

    /// Lee cualquiera de los dos formatos. Ignora comentarios y líneas que no son colores.
    public static func parse(_ text: String) -> [PaintColor] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        if lines.first == "GIMP Palette" {
            return lines.dropFirst().compactMap { line -> PaintColor? in
                guard !line.hasPrefix("#"), !line.contains(":") else { return nil }
                let parts = line.split(whereSeparator: \.isWhitespace).prefix(3).compactMap { Int($0) }
                guard parts.count == 3, parts.allSatisfy((0...255).contains) else { return nil }
                return PaintColor(red: UInt8(parts[0]), green: UInt8(parts[1]), blue: UInt8(parts[2]))
            }
        }
        return lines.compactMap { line in
            guard !line.hasPrefix(";"), !line.hasPrefix("//") else { return nil }
            return PaintColor(hex: line)
        }
    }

    public static func gpl(name: String, colors: [PaintColor]) -> String {
        var text = "GIMP Palette\nName: \(name)\nColumns: 14\n#\n"
        for color in colors {
            text += String(format: "%3d %3d %3d\t%@\n", color.red, color.green, color.blue, color.hex)
        }
        return text
    }

    public static func hex(colors: [PaintColor]) -> String {
        colors.map { String($0.hex.dropFirst().prefix(6)).lowercased() }.joined(separator: "\n") + "\n"
    }
}
