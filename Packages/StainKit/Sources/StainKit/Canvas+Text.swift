import CoreGraphics
import CoreText
import Foundation

/// Estilo uniforme de un cuadro de texto (como en Paint: una fuente para todo el cuadro).
public struct TextStyle: Sendable, Hashable {
    public var fontName: String
    public var size: Double
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var color: PaintColor
    /// Fondo opaco, o `nil` para fondo transparente.
    public var background: PaintColor?

    public init(
        fontName: String = "Helvetica", size: Double = 18, bold: Bool = false, italic: Bool = false,
        underline: Bool = false, color: PaintColor = .black, background: PaintColor? = nil
    ) {
        self.fontName = fontName
        self.size = size
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.color = color
        self.background = background
    }

    /// Fuente de Core Text con negrita/cursiva si la familia las tiene.
    /// `fontName` puede ser un nombre de familia ("Times New Roman") o un nombre PostScript.
    public var ctFont: CTFont {
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontFamilyNameAttribute: fontName] as CFDictionary)
        var base = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        if (CTFontCopyFamilyName(base) as String) != fontName {
            base = CTFontCreateWithName(fontName as CFString, size, nil)
        }
        var traits: CTFontSymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard !traits.isEmpty else { return base }
        return CTFontCreateCopyWithSymbolicTraits(base, size, nil, traits, traits) ?? base
    }

    func attributedString(_ text: String) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        if underline {
            attributes[NSAttributedString.Key(kCTUnderlineStyleAttributeName as String)] =
                CTUnderlineStyle.single.rawValue
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
}

extension Canvas {
    /// Escribe texto dentro de `rect`, ajustando las líneas a su ancho. Lo que no quepa se recorta.
    public mutating func drawText(_ text: String, style: TextStyle, in rect: PixelRect) {
        let rect = rect.intersection(bitmap.bounds)
        guard !rect.isEmpty else { return }
        if let background = style.background { fill(rect, with: background) }
        guard !text.isEmpty else { return }
        let framesetter = CTFramesetterCreateWithAttributedString(style.attributedString(text))
        let height = CGFloat(rect.height)
        draw(in: rect, antialiased: true) { context in
            // Core Text dibuja con la Y hacia arriba: se deshace el volteo dentro del rectángulo.
            context.translateBy(x: CGFloat(rect.x), y: CGFloat(rect.y) + height)
            context.scaleBy(x: 1, y: -1)
            let path = CGPath(rect: CGRect(x: 0, y: 0, width: CGFloat(rect.width), height: height), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, context)
        }
    }
}
