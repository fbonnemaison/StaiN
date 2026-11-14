import Foundation

/// Lectura y escritura de paletas: GIMP (`.gpl`) y lista hexadecimal (`.hex`, como Lospec).
public enum PaletteFile {
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
