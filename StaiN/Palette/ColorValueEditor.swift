import AppKit
import StainKit
import SwiftUI

/// Panel para escribir un color por sus valores: RGB (0–255), alfa y HEX.
/// Los cambios se aplican al momento. También abre el selector de color del sistema.
struct ColorValueEditor: View {
    let title: LocalizedStringKey
    let color: PaintColor
    let onChange: (PaintColor) -> Void

    @State private var hexText = ""
    @FocusState private var hexFocused: Bool

    private var hexIsValid: Bool { PaintColor(hex: hexText.trimmingCharacters(in: .whitespaces)) != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SwatchView(color: color, accessibilityLabel: String(localized: "Vista previa"), cornerRadius: 6) {}
                    .frame(width: 36, height: 36)
                Text(title).font(.headline)
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                channel("R", \.red, tint: .red, id: "red")
                channel("G", \.green, tint: .green, id: "green")
                channel("B", \.blue, tint: .blue, id: "blue")
                channel("A", \.alpha, tint: .gray, id: "alpha")
            }

            HStack(spacing: 6) {
                Text("HEX").font(.caption.monospaced()).frame(width: 30, alignment: .leading)
                TextField("#RRGGBB", text: $hexText)
                    .font(.body.monospaced())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 110)
                    .focused($hexFocused)
                    .onSubmit(applyHex)
                    .onChange(of: hexText) { if hexFocused, hexIsValid { applyHex() } }
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(hexIsValid ? Color.clear : .red, lineWidth: 1)
                    }
                    .accessibilityIdentifier("hexField")
                Button("Copiar HEX", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(color.hex, forType: .string)
                }
                .labelStyle(.iconOnly)
                .help("Copiar HEX")
                Button("Pegar HEX", systemImage: "doc.on.clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string),
                        let pasted = PaintColor(hex: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    {
                        onChange(pasted)
                    }
                }
                .labelStyle(.iconOnly)
                .help("Pegar HEX")
            }
            if !hexIsValid {
                Text("Escribe 6 u 8 dígitos hexadecimales, p. ej. #FF8800")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Selector de color del sistema…", systemImage: "eyedropper.halffull") {
                ColorPanelController.shared.edit(color) { onChange($0) }
            }
            .buttonStyle(.link)
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { hexText = color.hex }
        .onChange(of: color) { if !hexFocused { hexText = color.hex } }
    }

    private func applyHex() {
        guard let parsed = PaintColor(hex: hexText.trimmingCharacters(in: .whitespaces)), parsed != color else {
            return
        }
        onChange(parsed)
    }

    /// Fila de un canal: deslizador y campo numérico (0–255).
    private func channel(_ name: String, _ keyPath: WritableKeyPath<PaintColor, UInt8>, tint: Color, id: String)
        -> some View
    {
        let value = Binding<Double>(
            get: { Double(color[keyPath: keyPath]) },
            set: { newValue in
                var updated = color
                updated[keyPath: keyPath] = UInt8(min(max(newValue.rounded(), 0), 255))
                if updated != color { onChange(updated) }
            })
        return GridRow {
            Text(name).font(.caption.monospaced())
            Slider(value: value, in: 0...255)
                .tint(tint)
                .frame(width: 150)
                .accessibilityLabel(name)
            TextField(name, value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 52)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("\(id)Field")
        }
    }
}
