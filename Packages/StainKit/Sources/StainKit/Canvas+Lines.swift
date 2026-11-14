extension Canvas {
    /// Línea de 1 píxel sin antialiasing (algoritmo de Bresenham), incluidos los dos extremos.
    /// Los puntos fuera de la imagen se ignoran.
    public mutating func drawPixelLine(fromX x0: Int, y y0: Int, toX x1: Int, y y1: Int, color: PaintColor) {
        let dx = abs(x1 - x0)
        let dy = -abs(y1 - y0)
        let stepX = x0 < x1 ? 1 : -1
        let stepY = y0 < y1 ? 1 : -1
        var error = dx + dy
        var x = x0
        var y = y0
        while true {
            setPixel(x: x, y: y, to: color)
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
}
