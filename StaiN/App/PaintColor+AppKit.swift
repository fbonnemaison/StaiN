import AppKit
import StainKit

extension PaintColor {
    /// Color de AppKit equivalente (sRGB).
    var nsColor: NSColor {
        NSColor(cgColor: cgColor) ?? .black
    }

    /// Convierte un `NSColor` (por ejemplo, de `NSColorPanel`) a sRGB. `nil` si no tiene componentes RGB.
    init?(nsColor: NSColor) {
        guard let srgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(cgColor: srgb.cgColor)
    }
}
