import AppKit
import StainKit
import UniformTypeIdentifiers

/// Cargar paletas (`.json` de StaiN, `.gpl` de GIMP y `.hex` de Lospec) y guardar los colores
/// personalizados como paleta `.json` con nombre.
@MainActor
enum PaletteFiles {
    private static let types: [UTType] = [
        .json, UTType(filenameExtension: "gpl") ?? .plainText, UTType(filenameExtension: "hex") ?? .plainText,
        .plainText,
    ]

    /// Añade la paleta del archivo al selector y la elige. El nombre sale del archivo (JSON o `.gpl`)
    /// o, si no tiene, del nombre del archivo.
    static func load(into palette: PaletteStore) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.message = String(localized: "Elige una paleta .json (StaiN), .gpl (GIMP) o .hex")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let file: (name: String?, colors: [PaintColor]) =
            (try? Data(contentsOf: url)).map(PaletteFile.read) ?? (nil, [])
        guard !file.colors.isEmpty else {
            let alert = NSAlert()
            alert.messageText = String(localized: "No se encontraron colores en el archivo")
            alert.runModal()
            return
        }
        palette.importPalette(
            named: file.name ?? url.deletingPathExtension().lastPathComponent, colors: file.colors)
    }

    /// Guarda colores como paleta JSON; pide el nombre de la paleta junto al del archivo.
    static func saveJSON(_ colors: [PaintColor]) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = String(localized: "Mis colores") + ".json"
        panel.message = String(localized: "Guarda los colores personalizados como paleta")

        let nameField = NSTextField(string: String(localized: "Mis colores"))
        nameField.placeholderString = String(localized: "Nombre de la paleta")
        nameField.setAccessibilityLabel(String(localized: "Nombre de la paleta"))
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 240).isActive = true
        let label = NSTextField(labelWithString: String(localized: "Nombre de la paleta:"))
        let row = NSStackView(views: [label, nameField])
        row.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        panel.accessoryView = row

        guard panel.runModal() == .OK, let url = panel.url else { return }
        var name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        do {
            try PaletteFile.json(name: name, colors: colors).write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
