extension Canvas {
    /// Recorre los píxeles de una línea (algoritmo de Bresenham), incluidos los dos extremos.
    static func forEachPixelOnLine(fromX x0: Int, y y0: Int, toX x1: Int, y y1: Int, _ body: (Int, Int) -> Void) {
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let stepX = x0 < x1 ? 1 : -1
        let stepY = y0 < y1 ? 1 : -1
        var error = dx + dy
        var x = x0
        var y = y0
        while true {
            body(x, y)
            if x == x1 && y == y1 { break }
            let doubled = 2 * error
            if doubled >= dy {
                error += dy
                x += stepX
            }
            if doubled <= dx {
                error += dx
                y += stepY
            }
        }
    }

    /// Línea de 1 píxel sin antialiasing. Los puntos fuera de la imagen se ignoran.
    public mutating func drawPixelLine(fromX x0: Int, y y0: Int, toX x1: Int, y y1: Int, color: PaintColor) {
        Self.forEachPixelOnLine(fromX: x0, y: y0, toX: x1, y: y1) { x, y in
            setPixel(x: x, y: y, to: color)
        }
    }

    /// Pinta un sello de pincel centrado en `(x, y)`.
    public mutating func stamp(_ mask: BrushMask, atX x: Int, y: Int, color: PaintColor) {
        markDirty(bitmapStamp(mask, x, y, color))
    }

    /// Pinta sellos en cada píxel de la línea, para que un movimiento rápido no deje huecos.
    public mutating func stampLine(
        _ mask: BrushMask, fromX x0: Int, y y0: Int, toX x1: Int, y y1: Int, color: PaintColor
    ) {
        var changed = PixelRect.zero
        Self.forEachPixelOnLine(fromX: x0, y: y0, toX: x1, y: y1) { x, y in
            changed = changed.union(bitmapStamp(mask, x, y, color))
        }
        markDirty(changed)
    }
}
