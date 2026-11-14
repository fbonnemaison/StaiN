/// Rectángulo en coordenadas de píxel enteras, con origen arriba a la izquierda.
public struct PixelRect: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public static let zero = PixelRect(x: 0, y: 0, width: 0, height: 0)

    public var minX: Int { x }
    public var minY: Int { y }
    public var maxX: Int { x + width }
    public var maxY: Int { y + height }
    public var isEmpty: Bool { width == 0 || height == 0 }
    public var area: Int { width * height }

    public func contains(x px: Int, y py: Int) -> Bool {
        px >= minX && px < maxX && py >= minY && py < maxY
    }

    /// Intersección; vacía (`.zero`) si no se solapan.
    public func intersection(_ other: PixelRect) -> PixelRect {
        let left = max(minX, other.minX)
        let top = max(minY, other.minY)
        let right = min(maxX, other.maxX)
        let bottom = min(maxY, other.maxY)
        guard right > left, bottom > top else { return .zero }
        return PixelRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// Unión (bounding box). Un rectángulo vacío no cuenta.
    public func union(_ other: PixelRect) -> PixelRect {
        if isEmpty { return other }
        if other.isEmpty { return self }
        let left = min(minX, other.minX)
        let top = min(minY, other.minY)
        return PixelRect(x: left, y: top, width: max(maxX, other.maxX) - left, height: max(maxY, other.maxY) - top)
    }

    /// Agranda el rectángulo `amount` píxeles por cada lado.
    public func insetBy(_ amount: Int) -> PixelRect {
        PixelRect(x: x + amount, y: y + amount, width: width - 2 * amount, height: height - 2 * amount)
    }

    public var description: String { "(\(x), \(y), \(width)×\(height))" }
}
