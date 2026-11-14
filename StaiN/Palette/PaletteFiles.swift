import AppKit
import StainKit
import UniformTypeIdentifiers

/// Cargar y guardar paletas `.gpl` (GIMP) y `.hex` (Lospec).
@MainActor
enum PaletteFiles {
    private static let types: [UTType] = [
        UTType(filenameExtension: "gpl") ?? .plainText, UTType(filenameExtension: "hex") ?? .plainText, .plainText,
    ]

    static func load(into palette: PaletteStore) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.message = "Elige una paleta .gpl (GIMP) o .hex"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let colors = (try? String(contentsOf: url, encoding: .utf8)).map(PaletteFile.parse) ?? []
        guard !colors.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No se encontraron colores en el archivo"
            alert.runModal()
            return
        }
        palette.setColors(colors)
    }

    static func save(_ colors: [PaintColor]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = Array(types.prefix(2))
        panel.nameFieldStringValue = "Paleta.gpl"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text =
            url.pathExtension.lowercased() == "hex"
            ? PaletteFile.hex(colors: colors)
            : PaletteFile.gpl(name: url.deletingPathExtension().lastPathComponent, colors: colors)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
