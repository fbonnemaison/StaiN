import Foundation

/// Aerógrafo: rocía píxeles al azar dentro de un círculo y sigue rociando mientras se mantiene pulsado.
public struct AirbrushTool: Tool {
    public var radius: Int
    /// Píxeles por evento.
    public var density: Int
    private var random: SplitMix64
    private var color: PaintColor = .black

    public init(radius: Int = 8, density: Int? = nil, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.radius = max(1, radius)
        self.density = density ?? max(4, radius * 2)
        random = SplitMix64(seed: seed)
    }

    public var repeatsWhileHeld: Bool { true }

    public mutating func begin(_ event: PointerEvent, on canvas: inout Canvas) {
        color = canvas.color(for: event.button)
        spray(at: event.pixel, on: &canvas)
    }

    public mutating func drag(_ event: PointerEvent, on canvas: inout Canvas) {
        spray(at: event.pixel, on: &canvas)
    }

    private mutating func spray(at center: (x: Int, y: Int), on canvas: inout Canvas) {
        let r = radius
        var painted = 0
        while painted < density {
            let dx = Int(random.next() % UInt64(2 * r + 1)) - r
            let dy = Int(random.next() % UInt64(2 * r + 1)) - r
            guard dx * dx + dy * dy <= r * r else { continue }
            canvas.setPixel(x: center.x + dx, y: center.y + dy, to: color)
            painted += 1
        }
    }
}

/// Generador pseudoaleatorio pequeño y determinista (para poder repetir los tests).
struct SplitMix64: Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
