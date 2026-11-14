extension Canvas {
    /// Copia `content` en `(x, y)` sustituyendo píxeles (sin mezclar), como pega Paint.
    /// - `mask`: bitmap del mismo tamaño; solo se copian los píxeles con alfa > 0 en la máscara.
    /// - `transparentColor`: si se indica, los píxeles de ese color no se copian ("selección transparente").
    public mutating func composite(
        _ content: Bitmap, mask: Bitmap?, atX x: Int, y: Int, transparentColor: PaintColor? = nil
    ) {
        let target = PixelRect(x: x, y: y, width: content.width, height: content.height)
        let area = target.intersection(bitmap.bounds)
        guard !area.isEmpty else { return }
        let key = transparentColor.map { color -> [UInt8] in
            let (r, g, b, a) = color.premultiplied
            return [r, g, b, a]
        }
        let canvasWidth = bitmap.width
        bitmap.storage.withUnsafeMutableBufferPointer { dst in
            content.storage.withUnsafeBufferPointer { src in
                for py in area.minY..<area.maxY {
                    for px in area.minX..<area.maxX {
                        let s = ((py - y) * content.width + (px - x)) * 4
                        if let mask, mask.storage[s + 3] == 0 { continue }
                        if let key, src[s] == key[0], src[s + 1] == key[1], src[s + 2] == key[2], src[s + 3] == key[3] {
                            continue
                        }
                        let d = (py * canvasWidth + px) * 4
                        dst[d] = src[s]
                        dst[d + 1] = src[s + 1]
                        dst[d + 2] = src[s + 2]
                        dst[d + 3] = src[s + 3]
                    }
                }
            }
        }
        markDirty(area)
    }

    /// Rellena con un color la zona de la máscara colocada en `rect` (o todo `rect` si no hay máscara).
    public mutating func fill(_ rect: PixelRect, mask: Bitmap?, with color: PaintColor) {
        guard let mask else {
            fill(rect, with: color)
            return
        }
        composite(Bitmap(width: rect.width, height: rect.height, fill: color), mask: mask, atX: rect.x, y: rect.y)
    }
}

extension Bitmap {
    /// Copia con los píxeles fuera de la máscara puestos a transparente.
    func masked(by mask: Bitmap?) -> Bitmap {
        guard let mask else { return self }
        var result = self
        result.storage.withUnsafeMutableBufferPointer { px in
            for i in stride(from: 0, to: px.count, by: 4) where mask.storage[i + 3] == 0 {
                px[i] = 0
                px[i + 1] = 0
                px[i + 2] = 0
                px[i + 3] = 0
            }
        }
        return result
    }
}
