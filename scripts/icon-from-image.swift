// Genera el icono de la app a partir de una imagen cuadrada del diseño (Design/AppIcon-source.png).
// Uso: swift scripts/icon-from-image.swift Design/AppIcon-source.png StaiN/Resources/Assets.xcassets/AppIcon.appiconset
//
// La imagen se coloca en la rejilla de iconos de macOS (824 × 824 dentro de 1024, esquinas de 185),
// con una sombra suave, y se exporta en todos los tamaños que pide el catálogo.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3, let source = NSImage(contentsOfFile: arguments[1]),
    let sourceImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    print("Uso: swift scripts/icon-from-image.swift <imagen> <carpeta AppIcon.appiconset>")
    exit(1)
}
let folder = URL(fileURLWithPath: arguments[2])

func render(side: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    let scale = CGFloat(side) / 1024
    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(shape)
    context.setFillColor(CGColor(red: 0.25, green: 0.2, blue: 0.8, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.addPath(shape)
    context.clip()
    context.draw(sourceImage, in: tile)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

var images: [[String: String]] = []
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try! render(side: points * scale).representation(using: .png, properties: [:])!
        .write(to: folder.appendingPathComponent(name))
    images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("Contents.json"))
print("Icono generado en \(folder.path)")
