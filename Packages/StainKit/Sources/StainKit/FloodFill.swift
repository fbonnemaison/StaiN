extension Bitmap {
    /// Relleno de área (cubo de pintura) por scanlines.
    ///
    /// Rellena los píxeles conectados (4 vecinos) a `(x, y)` cuyo color se parece al del píxel inicial.
    /// `tolerance` es la diferencia máxima permitida en cualquier canal (0 = color exacto, 255 = todo).
    /// El relleno sustituye los píxeles (no mezcla), como en Paint.
    ///
    /// - Returns: El rectángulo que contiene los píxeles cambiados (vacío si no cambió nada).
    @discardableResult
    public mutating func floodFill(x startX: Int, y startY: Int, with color: PaintColor, tolerance: UInt8 = 0)
        -> PixelRect
    {
        guard contains(x: startX, y: startY) else { return .zero }
        let (fr, fg, fb, fa) = color.premultiplied
        let fill: [UInt8] = [fr, fg, fb, fa]
        let width = width, height = height
        let start = offset(x: startX, y: startY)
        let target = Array(storage[start..<start + 4])
        if tolerance == 0 && target == fill { return .zero }
        let tol = Int(tolerance)

        var minX = startX, maxX = startX, minY = startY, maxY = startY
        var visited = [Bool](repeating: false, count: width * height)
        var stack: [(Int, Int)] = [(startX, startY)]

        storage.withUnsafeMutableBufferPointer { px in
            @inline(__always) func matches(_ x: Int, _ y: Int) -> Bool {
                let p = y * width + x
                if visited[p] { return false }
                let i = p * 4
                return abs(Int(px[i]) - Int(target[0])) <= tol
                    && abs(Int(px[i + 1]) - Int(target[1])) <= tol
                    && abs(Int(px[i + 2]) - Int(target[2])) <= tol
                    && abs(Int(px[i + 3]) - Int(target[3])) <= tol
            }

            while let (seedX, y) = stack.popLast() {
                guard matches(seedX, y) else { continue }
                // Extiende el tramo hacia la izquierda y la derecha.
                var left = seedX
                while left > 0 && matches(left - 1, y) { left -= 1 }
                var right = seedX
                while right < width - 1 && matches(right + 1, y) { right += 1 }

                for x in left...right {
                    let p = y * width + x
                    visited[p] = true
                    let i = p * 4
                    px[i] = fill[0]
                    px[i + 1] = fill[1]
                    px[i + 2] = fill[2]
                    px[i + 3] = fill[3]
                }
                minX = min(minX, left)
                maxX = max(maxX, right)
                minY = min(minY, y)
                maxY = max(maxY, y)

                // Siembra un punto por cada tramo coincidente en las filas de arriba y de abajo.
                for neighborY in [y - 1, y + 1] where neighborY >= 0 && neighborY < height {
                    var x = left
                    while x <= right {
                        if matches(x, neighborY) {
                            stack.append((x, neighborY))
                            while x <= right && matches(x, neighborY) { x += 1 }
                        } else {
                            x += 1
                        }
                    }
                }
            }
        }
        return PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
