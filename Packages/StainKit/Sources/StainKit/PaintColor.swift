import CoreGraphics

/// Color RGBA de 8 bits por canal, no premultiplicado, en el espacio sRGB.
public struct PaintColor: Hashable, Sendable, CustomStringConvertible {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = PaintColor(red: 0, green: 0, blue: 0)
    public static let white = PaintColor(red: 255, green: 255, blue: 255)
    public static let clear = PaintColor(red: 0, green: 0, blue: 0, alpha: 0)

    public var isOpaque: Bool { alpha == 255 }

    public var description: String {
        alpha == 255
            ? String(format: "#%02X%02X%02X", red, green, blue)
            : String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
    }

    // MARK: Hexadecimal

    /// Lee `#RRGGBB` o `#RRGGBBAA` (con o sin `#`).
    public init?(hex: String) {
        var text = Substring(hex)
        if text.hasPrefix("#") { text = text.dropFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt32(text, radix: 16) else { return nil }
        if text.count == 6 {
            self.init(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
        } else {
            self.init(
                red: UInt8(value >> 24 & 0xFF), green: UInt8(value >> 16 & 0xFF), blue: UInt8(value >> 8 & 0xFF),
                alpha: UInt8(value & 0xFF))
        }
    }

    /// `#RRGGBB`, o `#RRGGBBAA` si no es opaco.
    public var hex: String { description }

    // MARK: Core Graphics

    public var cgColor: CGColor {
        CGColor(
            srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255)
    }

    /// Convierte cualquier `CGColor` a sRGB. Devuelve `nil` si no se puede convertir (p. ej. patrones).
    public init?(cgColor: CGColor) {
        guard
            let srgb = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
            let c = converted.components, c.count >= 4
        else { return nil }
        func byte(_ value: CGFloat) -> UInt8 { UInt8((min(max(value, 0), 1) * 255).rounded()) }
        self.init(red: byte(c[0]), green: byte(c[1]), blue: byte(c[2]), alpha: byte(c[3]))
    }

    // MARK: Premultiplicación (formato interno del Bitmap)

    /// Bytes RGBA premultiplicados por alfa.
    var premultiplied: (UInt8, UInt8, UInt8, UInt8) {
        guard alpha < 255 else { return (red, green, blue, 255) }
        let a = UInt32(alpha)
        func mul(_ c: UInt8) -> UInt8 { UInt8((UInt32(c) * a + 127) / 255) }
        return (mul(red), mul(green), mul(blue), alpha)
    }

    /// Construye un color a partir de bytes RGBA premultiplicados.
    init(premultipliedRed r: UInt8, green g: UInt8, blue b: UInt8, alpha a: UInt8) {
        switch a {
        case 255:
            self.init(red: r, green: g, blue: b, alpha: 255)
        case 0:
            self = .clear
        default:
            let alpha = UInt32(a)
            func div(_ c: UInt8) -> UInt8 { UInt8(min(255, (UInt32(c) * 255 + alpha / 2) / alpha)) }
            self.init(red: div(r), green: div(g), blue: div(b), alpha: a)
        }
    }
}
