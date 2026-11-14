// Genera el icono de la app (StaiN: un lienzo con manchas de pintura) en todos los tamaños de macOS.
// Uso: swift scripts/make-icon.swift <carpeta AppIcon.appiconset>
import AppKit

func drawIcon(side: CGFloat, in context: CGContext) {
    let s = side / 1024
    context.scaleBy(x: s, y: s)

    // Fondo: cuadrado redondeado con degradado índigo → turquesa (rejilla de iconos de macOS: 824 px de 1024).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(tilePath)
    context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(red: 0.20, green: 0.18, blue: 0.55, alpha: 1), CGColor(red: 0.10, green: 0.55, blue: 0.65, alpha: 1),
        ] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100), options: [])

    // Lienzo blanco ligeramente girado.
    context.saveGState()
    context.translateBy(x: 512, y: 500)
    context.rotate(by: -0.08)
    let sheet = CGRect(x: -270, y: -230, width: 540, height: 460)
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(CGPath(roundedRect: sheet, cornerWidth: 18, cornerHeight: 18, transform: nil))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    // Manchas de pintura (rojo, amarillo y azul) con gotas alrededor.
    func stain(_ center: CGPoint, _ radius: CGFloat, _ color: CGColor, drops: [(CGFloat, CGFloat, CGFloat)]) {
        context.setFillColor(color)
        let blob = CGMutablePath()
        let lobes = 9
        for i in 0...lobes {
            let angle = CGFloat(i) / CGFloat(lobes) * 2 * .pi
            // Ondulación periódica: el contorno cierra sin saltos.
            let wobble = radius * (0.88 + 0.12 * sin(3 * angle + radius))
            let point = CGPoint(x: center.x + cos(angle) * wobble, y: center.y + sin(angle) * wobble)
            if i == 0 { blob.move(to: point) } else {
                let mid = angle - .pi / CGFloat(lobes)
                let control = CGPoint(
                    x: center.x + cos(mid) * radius * 1.12, y: center.y + sin(mid) * radius * 1.12)
                blob.addQuadCurve(to: point, control: control)
            }
        }
        context.addPath(blob)
        context.fillPath()
        for (dx, dy, r) in drops {
            context.fillEllipse(in: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: 2 * r, height: 2 * r))
        }
    }
    stain(CGPoint(x: -95, y: 55), 120, CGColor(red: 0.93, green: 0.22, blue: 0.24, alpha: 1),
        drops: [(-150, 95, 18), (-165, 20, 10), (40, 150, 12)])
    stain(CGPoint(x: 110, y: 70), 95, CGColor(red: 0.99, green: 0.80, blue: 0.16, alpha: 0.95),
        drops: [(120, 70, 14), (95, -60, 9)])
    stain(CGPoint(x: 15, y: -95), 105, CGColor(red: 0.16, green: 0.45, blue: 0.92, alpha: 0.95),
        drops: [(-140, -60, 15), (130, -95, 11), (60, -118, 8)])
    context.restoreGState()

    // Pincel cruzando en diagonal.
    context.saveGState()
    context.translateBy(x: 660, y: 330)
    context.rotate(by: 0.75)
    context.setFillColor(CGColor(red: 0.55, green: 0.33, blue: 0.18, alpha: 1))
    context.addPath(CGPath(roundedRect: CGRect(x: -30, y: -40, width: 60, height: 330), cornerWidth: 30, cornerHeight: 30, transform: nil))
    context.fillPath()
    context.setFillColor(CGColor(gray: 0.78, alpha: 1))
    context.fill(CGRect(x: -36, y: -110, width: 72, height: 80))
    context.setFillColor(CGColor(gray: 0.12, alpha: 1))
    let tip = CGMutablePath()
    tip.move(to: CGPoint(x: -36, y: -110))
    tip.addQuadCurve(to: CGPoint(x: 0, y: -230), control: CGPoint(x: -40, y: -190))
    tip.addQuadCurve(to: CGPoint(x: 36, y: -110), control: CGPoint(x: 40, y: -190))
    tip.closeSubpath()
    context.addPath(tip)
    context.fillPath()
    context.restoreGState()
    context.restoreGState()
}

let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
var images: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(side: CGFloat(pixels), in: NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try! rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: folder.appendingPathComponent("Contents.json"))
print("Icono generado en \(folder.path)")
