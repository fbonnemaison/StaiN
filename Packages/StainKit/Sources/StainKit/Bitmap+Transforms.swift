import CoreGraphics
import Foundation

/// Punto de anclaje al cambiar el tamaño del lienzo (3 × 3).
public enum CanvasAnchor: Int, CaseIterable, Sendable, Hashable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    /// 0 = izquierda/arriba, 1 = centro, 2 = derecha/abajo.
    var column: Int { rawValue % 3 }
    var row: Int { rawValue / 3 }
}

extension Bitmap {
    /// Construye un bitmap del tamaño dado copiando cada píxel de destino desde `source(x, y)` (índice de origen).
    private static func remapped(width: Int, height: Int, from source: Bitmap, _ sourceIndex: (Int, Int) -> Int)
        -> Bitmap
    {
        var result = Bitmap(width: width, height: height, fill: .clear)
        source.storage.withUnsafeBufferPointer { src in
            result.storage.withUnsafeMutableBufferPointer { dst in
                for y in 0..<height {
                    for x in 0..<width {
                        let s = sourceIndex(x, y) * 4
                        let d = (y * width + x) * 4
                        dst[d] = src[s]
                        dst[d + 1] = src[s + 1]
                        dst[d + 2] = src[s + 2]
                        dst[d + 3] = src[s + 3]
                    }
                }
            }
        }
        return result
    }

    public func flippedHorizontally() -> Bitmap {
        let w = width
        return Self.remapped(width: w, height: height, from: self) { x, y in y * w + (w - 1 - x) }
    }

    public func flippedVertically() -> Bitmap {
        let w = width, h = height
        return Self.remapped(width: w, height: h, from: self) { x, y in (h - 1 - y) * w + x }
    }

    /// Gira en cuartos de vuelta en el sentido de las agujas del reloj (negativo = al revés).
    public func rotated(quarterTurns: Int) -> Bitmap {
        let w = width, h = height
        switch ((quarterTurns % 4) + 4) % 4 {
        case 1:  // 90° horario: el destino (x, y) viene de (y, h - 1 - x)
            return Self.remapped(width: h, height: w, from: self) { x, y in (h - 1 - x) * w + y }
        case 2:
            return Self.remapped(width: w, height: h, from: self) { x, y in (h - 1 - y) * w + (w - 1 - x) }
        case 3:  // 90° antihorario: el destino (x, y) viene de (w - 1 - y, x)
            return Self.remapped(width: h, height: w, from: self) { x, y in x * w + (w - 1 - y) }
        default:
            return self
        }
    }

    /// Colores invertidos (la transparencia se conserva).
    public func inverted() -> Bitmap {
        var result = self
        result.storage.withUnsafeMutableBufferPointer { px in
            for i in stride(from: 0, to: px.count, by: 4) {
                // En premultiplicado, invertir c es a − c.
                let a = px[i + 3]
                px[i] = a &- min(px[i], a)
                px[i + 1] = a &- min(px[i + 1], a)
                px[i + 2] = a &- min(px[i + 2], a)
            }
        }
        return result
    }

    /// Escala la imagen. `smooth` interpola (fotos); si no, vecino más cercano (pixel art, sin colores nuevos).
    public func resized(width newWidth: Int, height newHeight: Int, smooth: Bool) -> Bitmap {
        let newWidth = max(1, newWidth), newHeight = max(1, newHeight)
        guard newWidth != width || newHeight != height else { return self }
        if !smooth {
            let w = width, h = height
            return Self.remapped(width: newWidth, height: newHeight, from: self) { x, y in
                let sx = min(w - 1, x * w / newWidth)
                let sy = min(h - 1, y * h / newHeight)
                return sy * w + sx
            }
        }
        guard let image = makeCGImage() else { return self }
        var result = Bitmap(width: newWidth, height: newHeight, fill: .clear)
        result.draw(antialiased: true) { context in
            context.interpolationQuality = .high
            context.translateBy(x: 0, y: CGFloat(newHeight))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        }
        return result
    }

    /// Inclina la imagen (grados, entre −89 y 89). El lienzo crece para que quepa y el hueco se rellena.
    public func skewed(horizontalDegrees: Double, verticalDegrees: Double, background: PaintColor) -> Bitmap {
        let tanX = tan(min(max(horizontalDegrees, -89), 89) * .pi / 180)
        let tanY = tan(min(max(verticalDegrees, -89), 89) * .pi / 180)
        guard tanX != 0 || tanY != 0, let image = makeCGImage() else { return self }
        let w = Double(width), h = Double(height)
        let newWidth = Int((w + abs(tanX) * h).rounded())
        let newHeight = Int((h + abs(tanY) * w).rounded())
        var result = Bitmap(width: newWidth, height: newHeight, fill: background)
        result.draw(antialiased: false) { context in
            context.interpolationQuality = .none
            // Coordenadas con origen arriba: x' = x + tanX·y, y' = tanY·x + y, desplazado para no salir negativo.
            context.concatenate(
                CGAffineTransform(a: 1, b: tanY, c: tanX, d: 1, tx: max(0, -tanX * h), ty: max(0, -tanY * w)))
            context.translateBy(x: 0, y: h)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return result
    }

    /// Cambia el tamaño del lienzo sin escalar la imagen, que queda en la posición del ancla.
    public func resizedCanvas(width newWidth: Int, height newHeight: Int, anchor: CanvasAnchor, fill: PaintColor)
        -> Bitmap
    {
        let newWidth = max(1, newWidth), newHeight = max(1, newHeight)
        var result = Bitmap(width: newWidth, height: newHeight, fill: fill)
        let x = (newWidth - width) * anchor.column / 2
        let y = (newHeight - height) * anchor.row / 2
        result.replace(with: self, atX: x, y: y)
        return result
    }
}
