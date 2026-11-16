// Replica: pinta una imagen de referencia usando solo las herramientas de StaiN (StainKit).
//
// El script no copia píxeles: igual que una persona con el ratón, elige un color, pulsa, arrastra y suelta.
// Pinta por capas, de pincel grueso a fino (pintura por trazos de Hertzmann, 1998):
//   1. Cubo de pintura: color de fondo.
//   2. En cada capa, busca las zonas que aún se parecen poco a la referencia y da allí una pincelada
//      del color de la referencia que sigue la dirección de los bordes (perpendicular al gradiente).
//   3. Repite con pinceles cada vez más finos hasta que la diferencia es pequeña.
// Guarda la imagen tras cada capa, una animación del proceso y una comparación con la referencia.
//
// Uso: swift run -c release Replica [referencia] [carpeta de salida]

import CoreGraphics
import Foundation
import ImageIO
import StainKit
import UniformTypeIdentifiers

// MARK: - Imagen de trabajo en coma flotante

struct RGB {
    var r: Float, g: Float, b: Float
    static func - (a: RGB, b: RGB) -> Float {
        let dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
    var luminance: Float { 0.299 * r + 0.587 * g + 0.114 * b }
    var paint: PaintColor {
        func byte(_ v: Float) -> UInt8 { UInt8(min(max(v, 0), 255).rounded()) }
        return PaintColor(red: byte(r), green: byte(g), blue: byte(b))
    }
}

struct FloatImage {
    let width: Int, height: Int
    var pixels: [RGB]

    init(width: Int, height: Int, pixels: [RGB]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(_ bitmap: Bitmap) {
        width = bitmap.width
        height = bitmap.height
        pixels = []
        pixels.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                let c = bitmap[x, y]
                pixels.append(RGB(r: Float(c.red), g: Float(c.green), b: Float(c.blue)))
            }
        }
    }

    subscript(x: Int, y: Int) -> RGB { pixels[y * width + x] }

    func contains(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < width && y < height }

    /// Desenfoque aproximadamente gaussiano: tres pasadas de caja separables.
    func blurred(radius: Int) -> FloatImage {
        guard radius > 0 else { return self }
        var image = self
        for _ in 0..<3 {
            image = image.boxPass(radius: radius, horizontal: true).boxPass(radius: radius, horizontal: false)
        }
        return image
    }

    private func boxPass(radius: Int, horizontal: Bool) -> FloatImage {
        var out = self
        let lines = horizontal ? height : width
        let length = horizontal ? width : height
        let scale = 1 / Float(2 * radius + 1)
        for line in 0..<lines {
            func at(_ i: Int) -> RGB {
                let c = min(max(i, 0), length - 1)
                return horizontal ? self[c, line] : self[line, c]
            }
            var sum = RGB(r: 0, g: 0, b: 0)
            for i in -radius...radius {
                let p = at(i)
                sum.r += p.r; sum.g += p.g; sum.b += p.b
            }
            for i in 0..<length {
                let index = horizontal ? line * width + i : i * width + line
                out.pixels[index] = RGB(r: sum.r * scale, g: sum.g * scale, b: sum.b * scale)
                let add = at(i + radius + 1), remove = at(i - radius)
                sum.r += add.r - remove.r; sum.g += add.g - remove.g; sum.b += add.b - remove.b
            }
        }
        return out
    }

    /// Gradiente de luminancia (Sobel).
    func gradient(x: Int, y: Int) -> (gx: Float, gy: Float) {
        func l(_ dx: Int, _ dy: Int) -> Float {
            self[min(max(x + dx, 0), width - 1), min(max(y + dy, 0), height - 1)].luminance
        }
        let gx = (l(1, -1) + 2 * l(1, 0) + l(1, 1)) - (l(-1, -1) + 2 * l(-1, 0) + l(-1, 1))
        let gy = (l(-1, 1) + 2 * l(0, 1) + l(1, 1)) - (l(-1, -1) + 2 * l(0, -1) + l(1, -1))
        return (gx, gy)
    }
}

// MARK: - El "usuario" que maneja las herramientas

/// Maneja las herramientas de StaiN como lo haría la vista del lienzo: pulsar, arrastrar, soltar.
struct Painter {
    var canvas: Canvas
    private(set) var uses: [String: Int] = [:]

    init(width: Int, height: Int) {
        canvas = Canvas(width: width, height: height)
    }

    /// Un gesto completo con una herramienta: pulsa en el primer punto, arrastra por el resto y suelta.
    /// (Sin historial de deshacer, que en un script no hace falta y copiaría la imagen en cada trazo.)
    mutating func gesture<T: Tool>(_ name: String, _ tool: T, color: PaintColor, through points: [CGPoint]) {
        guard let first = points.first, let last = points.last else { return }
        var tool = tool
        canvas.primaryColor = color
        tool.begin(PointerEvent(location: first), on: &canvas)
        for point in points.dropFirst() { tool.drag(PointerEvent(location: point), on: &canvas) }
        tool.end(PointerEvent(location: last), on: &canvas)
        _ = canvas.takeDirtyRect()
        uses[name, default: 0] += 1
    }
}

// MARK: - Utilidades de archivo

func loadBitmap(_ url: URL) throws -> Bitmap {
    try ImageCodec.decode(Data(contentsOf: url))
}

func savePNG(_ bitmap: Bitmap, to url: URL) throws {
    try ImageCodec.encode(bitmap, as: .png).write(to: url)
}

func scaled(_ image: CGImage, width: Int) -> CGImage? {
    let height = Int((Double(image.height) * Double(width) / Double(image.width)).rounded())
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()
}

/// Referencia y réplica una al lado de la otra.
func sideBySide(_ a: Bitmap, _ b: Bitmap) -> Bitmap? {
    let gap = 24
    let width = a.width + b.width + gap
    guard let ca = a.makeCGImage(), let cb = b.makeCGImage(),
        let context = CGContext(
            data: nil, width: width, height: a.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: a.height))
    context.draw(ca, in: CGRect(x: 0, y: 0, width: a.width, height: a.height))
    context.draw(cb, in: CGRect(x: a.width + gap, y: 0, width: b.width, height: b.height))
    return context.makeImage().flatMap(Bitmap.init(cgImage:))
}

/// Animación GIF reducida del proceso.
final class Timelapse {
    private let destination: CGImageDestination
    private let width: Int

    init?(url: URL, width: Int) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 10_000, nil)
        else { return nil }
        self.destination = destination
        self.width = width
        CGImageDestinationSetProperties(
            destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    }

    func add(_ bitmap: Bitmap, delay: Double = 0.08) {
        guard let image = bitmap.makeCGImage(), let small = scaled(image, width: width) else { return }
        CGImageDestinationAddImage(
            destination, small,
            [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }

    func finish() { CGImageDestinationFinalize(destination) }
}

/// Generador pseudoaleatorio determinista: cada ejecución pinta exactamente lo mismo.
struct Random {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Parámetros

let arguments = CommandLine.arguments
let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
let referenceURL = arguments.count > 1 ? URL(fileURLWithPath: arguments[1]) : packageDir.appending(path: "referencia.webp")
let outputDir = arguments.count > 2 ? URL(fileURLWithPath: arguments[2]) : packageDir.appending(path: "out")
let stepsDir = outputDir.appending(path: "pasos")
try FileManager.default.createDirectory(at: stepsDir, withIntermediateDirectories: true)

/// Tamaños de pincel, de grueso a fino. El último (1 px) es el lápiz, para las líneas de tinta y los bigotes.
let brushSizes = [48, 24, 12, 6, 3, 2, 1]
/// Diferencia media (0–441) a partir de la cual una zona necesita otra pincelada.
let threshold: Float = 14
/// Longitud de las pinceladas, en pasos del radio del pincel.
let minStrokeLength = 2, maxStrokeLength = 14
/// Suavizado del cambio de dirección de una pincelada (1 = sigue el gradiente sin inercia).
let curvatureFilter: Float = 0.7

// MARK: - Pintar

let referenceBitmap = try loadBitmap(referenceURL)
let reference = FloatImage(referenceBitmap)
let width = reference.width, height = reference.height
print("Referencia: \(referenceURL.lastPathComponent) (\(width)×\(height))")

var painter = Painter(width: width, height: height)
var random = Random(state: 0x5741_494E)
let timelapse = Timelapse(url: outputDir.appending(path: "proceso.gif"), width: 520)
var stepIndex = 0

@MainActor func meanError() -> Double {
    let current = FloatImage(painter.canvas.bitmap)
    var total: Double = 0
    for i in 0..<current.pixels.count {
        let a = current.pixels[i], b = reference.pixels[i]
        total += Double(abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b)) / 3
    }
    return total / Double(current.pixels.count)
}

@MainActor func saveStep(_ name: String) throws {
    stepIndex += 1
    let error = meanError()
    let similarity = 100 * (1 - error / 255)
    try savePNG(painter.canvas.bitmap, to: stepsDir.appending(path: String(format: "%02d-%@.png", stepIndex, name)))
    print(String(format: "  %-22@ error medio %5.1f  parecido %5.1f %%", name as NSString, error, similarity))
}

// 1. Fondo: color más frecuente en el borde de la referencia, con el cubo de pintura.
let border = (0..<width).flatMap { [reference[$0, 0], reference[$0, height - 1]] }
let background = border.sorted { $0.luminance < $1.luminance }[border.count / 2]
painter.gesture("Cubo de pintura", FillTool(), color: background.paint, through: [CGPoint(x: 1, y: 1)])
timelapse?.add(painter.canvas.bitmap)
try saveStep("fondo")

// 2. Capas de pinceladas.
for size in brushSizes {
    let radius = max(1, size / 2)
    // Los pinceles gruesos copian una versión desenfocada; los finos, la referencia tal cual.
    let guide = size >= 6 ? reference.blurred(radius: size / 3) : reference
    let current = FloatImage(painter.canvas.bitmap)
    let grid = max(1, size * 3 / 4)

    var strokes: [(color: PaintColor, points: [CGPoint])] = []
    for gy in stride(from: 0, to: height, by: grid) {
        for gx in stride(from: 0, to: width, by: grid) {
            // Error de la celda y su peor píxel.
            var sum: Float = 0, worst: Float = -1, wx = gx, wy = gy, count = 0
            for y in gy..<min(gy + grid, height) {
                for x in gx..<min(gx + grid, width) {
                    let e = guide[x, y] - current[x, y]
                    sum += e
                    count += 1
                    if e > worst { worst = e; wx = x; wy = y }
                }
            }
            guard sum / Float(count) > threshold else { continue }

            // Pincelada que empieza en el peor píxel y sigue los bordes de la referencia.
            let color = guide[wx, wy]
            var points = [CGPoint(x: Double(wx) + 0.5, y: Double(wy) + 0.5)]
            var x = Float(wx) + 0.5, y = Float(wy) + 0.5
            var lastDx: Float = 0, lastDy: Float = 0
            for step in 1...maxStrokeLength {
                let ix = Int(x), iy = Int(y)
                if step > minStrokeLength && guide[ix, iy] - current[ix, iy] < guide[ix, iy] - color { break }
                let (gx, gy) = guide.gradient(x: ix, y: iy)
                let magnitude = (gx * gx + gy * gy).squareRoot()
                if magnitude < 1 { break }
                var dx = -gy / magnitude, dy = gx / magnitude
                if lastDx * dx + lastDy * dy < 0 { dx = -dx; dy = -dy }
                if step > 1 {
                    dx = curvatureFilter * dx + (1 - curvatureFilter) * lastDx
                    dy = curvatureFilter * dy + (1 - curvatureFilter) * lastDy
                    let length = (dx * dx + dy * dy).squareRoot()
                    dx /= length; dy /= length
                }
                x += Float(radius) * dx
                y += Float(radius) * dy
                guard reference.contains(Int(x), Int(y)) else { break }
                lastDx = dx; lastDy = dy
                points.append(CGPoint(x: Double(x), y: Double(y)))
            }
            strokes.append((color.paint, points))
        }
    }

    // En orden aleatorio, para que no se note la cuadrícula.
    for i in stride(from: strokes.count - 1, to: 0, by: -1) {
        strokes.swapAt(i, Int(random.next() % UInt64(i + 1)))
    }
    let brush = BrushTool(shape: .round, size: size)
    let framesPerLayer = 14
    let every = max(1, strokes.count / framesPerLayer)
    for (index, stroke) in strokes.enumerated() {
        if size == 1 {
            painter.gesture("Lápiz", PencilTool(), color: stroke.color, through: stroke.points)
        } else {
            painter.gesture("Pincel", brush, color: stroke.color, through: stroke.points)
        }
        if index % every == every - 1 { timelapse?.add(painter.canvas.bitmap) }
    }
    let layerName = size == 1 ? "lapiz" : "pincel-\(size)px"
    print("\(layerName): \(strokes.count) trazos")
    try saveStep(layerName)
}

// MARK: - Resultado

try savePNG(painter.canvas.bitmap, to: outputDir.appending(path: "replica.png"))
if let comparison = sideBySide(referenceBitmap, painter.canvas.bitmap) {
    try savePNG(comparison, to: outputDir.appending(path: "comparacion.png"))
}
timelapse?.add(painter.canvas.bitmap, delay: 3)
timelapse?.finish()

print("\nHerramientas usadas:")
for (name, count) in painter.uses.sorted(by: { $0.key < $1.key }) { print("  \(name): \(count) gestos") }
print("Salida en \(outputDir.path)")
