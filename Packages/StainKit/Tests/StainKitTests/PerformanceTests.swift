import Foundation
import Testing

@testable import StainKit

/// Mediciones con una imagen de 8000 × 8000 (256 MB). Solo se ejecutan si se pide:
/// `STAIN_PERF=1 swift test -c release --package-path Packages/StainKit --filter Performance`
@Suite(.enabled(if: ProcessInfo.processInfo.environment["STAIN_PERF"] != nil))
struct PerformanceTests {
    static let side = 8000

    func measure(_ name: String, _ body: () -> Void) -> Double {
        let start = ContinuousClock.now
        body()
        let elapsed = ContinuousClock.now - start
        let ms = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        print("PERF \(name): \(String(format: "%.1f", ms)) ms")
        return ms
    }

    @Test func strokeOnHugeImage() {
        var canvas = Canvas(width: Self.side, height: Self.side)
        _ = measure("primer trazo (copia al empezar la edición)") {
            canvas.beginEdit()
            canvas.stampLine(BrushMask(shape: .round, size: 8), fromX: 100, y: 100, toX: 600, y: 400, color: .black)
            _ = canvas.endEdit()
        }
        _ = measure("segundo trazo") {
            canvas.beginEdit()
            canvas.stampLine(BrushMask(shape: .round, size: 8), fromX: 100, y: 500, toX: 600, y: 900, color: .black)
            _ = canvas.endEdit()
        }
    }

    @Test func floodFillWholeImage() {
        var bitmap = Bitmap(width: Self.side, height: Self.side)
        _ = measure("relleno de toda la imagen") { bitmap.floodFill(x: 0, y: 0, with: .black) }
    }

    @Test func displayCrops() {
        let bitmap = Bitmap(width: Self.side, height: Self.side)
        _ = measure("recorte + CGImage de 1600×1000 (ventana al 100 %)") {
            _ = bitmap.cropped(to: PixelRect(x: 0, y: 0, width: 1600, height: 1000))?.makeCGImage()
        }
        _ = measure("recorte + CGImage de la imagen entera (alejado)") {
            _ = bitmap.cropped(to: bitmap.bounds)?.makeCGImage()
        }
        _ = measure("muestra 1 de cada 4 + CGImage de la imagen entera (alejado, nuevo)") {
            _ = bitmap.sampled(bitmap.bounds, step: 4)?.makeCGImage()
        }
    }

    @Test func transformsAndCodec() throws {
        let bitmap = Bitmap(width: Self.side, height: Self.side)
        _ = measure("girar 90°") { _ = bitmap.rotated(quarterTurns: 1) }
        _ = measure("invertir") { _ = bitmap.inverted() }
        _ = measure("codificar PNG") { _ = try? ImageCodec.encode(bitmap, as: .png) }
    }
}
