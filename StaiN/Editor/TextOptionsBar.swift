import AppKit
import SwiftUI

/// Barra de fuentes que aparece sobre el lienzo con la herramienta Texto.
struct TextOptionsBar: View {
    @Bindable var editor: EditorState
    private static let families = NSFontManager.shared.availableFontFamilies

    var body: some View {
        HStack(spacing: 10) {
            Picker("Fuente", selection: $editor.fontFamily) {
                ForEach(Self.families, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .labelsHidden()
            .frame(width: 180)
            .accessibilityLabel("Fuente")
            .accessibilityIdentifier("fontPicker")

            Picker("Tamaño", selection: $editor.fontSize) {
                ForEach(EditorState.fontSizes, id: \.self) { size in
                    Text("\(Int(size)) pt").tag(size)
                }
            }
            .labelsHidden()
            .frame(width: 80)
            .accessibilityLabel("Tamaño de fuente")

            ControlGroup {
                Toggle("Negrita", systemImage: "bold", isOn: $editor.isBold)
                Toggle("Cursiva", systemImage: "italic", isOn: $editor.isItalic)
                Toggle("Subrayado", systemImage: "underline", isOn: $editor.isUnderlined)
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .fixedSize()

            Toggle("Fondo opaco", isOn: $editor.hasOpaqueTextBackground)
                .toggleStyle(.checkbox)
                .help("Rellenar el cuadro con el color secundario")

            Spacer()
            Text("Clic fuera del cuadro para fijar el texto")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}
