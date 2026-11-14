import StainKit
import SwiftUI

/// Panel izquierdo: cuadrícula de herramientas y, debajo, las opciones de la herramienta activa.
struct ToolPanel: View {
    @Bindable var editor: EditorState

    private let columns = [GridItem(.fixed(30), spacing: 4), GridItem(.fixed(30), spacing: 4)]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(ToolKind.allCases) { tool in
                    ToolButton(tool: tool, isSelected: editor.tool == tool) { editor.tool = tool }
                }
            }
            Divider()
            ToolOptions(editor: editor)
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(width: 76)
    }
}

private struct ToolButton: View {
    let tool: ToolKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tool.systemImage)
                .font(.system(size: 14))
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
        .background(isSelected ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 6))
        .help("\(tool.title) (\(String(tool.shortcut).uppercased()))")
        .keyboardShortcut(KeyEquivalent(tool.shortcut), modifiers: [])
        .accessibilityLabel(tool.title)
        .accessibilityIdentifier("tool.\(tool.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Opciones de la herramienta activa (el recuadro bajo las herramientas de Paint).
private struct ToolOptions: View {
    @Bindable var editor: EditorState

    var body: some View {
        VStack(spacing: 6) {
            switch editor.tool {
            case .brush:
                ShapePicker(selection: $editor.brushShape)
                SizeList(sizes: EditorState.brushSizes, selection: $editor.brushSize, label: "Tamaño del pincel")
            case .eraser:
                SizeList(sizes: EditorState.eraserSizes, selection: $editor.eraserSize, square: true, label: "Tamaño")
                Toggle(isOn: $editor.erasesToTransparent) {
                    Text("Transparente").font(.caption2)
                }
                .toggleStyle(.checkbox)
                .help("Borrar dejando píxeles transparentes en vez del color secundario")
            case .fill:
                Text("Tolerancia").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $editor.fillTolerance, in: 0...1)
                    .controlSize(.mini)
                    .accessibilityLabel("Tolerancia del relleno")
                Text(editor.fillTolerance, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.monospacedDigit())
            case .line:
                SizeList(sizes: EditorState.lineWidths, selection: $editor.lineWidth, label: "Grosor de línea")
                Text("⇧ = 45°").font(.caption2).foregroundStyle(.secondary)
            case .eyedropper:
                Hint("Clic: primario\nClic der.: secundario")
            case .zoom:
                Hint("Clic: acercar\n⌥ o clic der.: alejar")
            case .pencil:
                Hint("Clic der.: color secundario")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Hint: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Lista de tamaños: cada fila muestra un punto del tamaño real (limitado para que quepa).
private struct SizeList: View {
    let sizes: [Int]
    @Binding var selection: Int
    var square = false
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            ForEach(sizes, id: \.self) { size in
                Button {
                    selection = size
                } label: {
                    HStack(spacing: 4) {
                        let side = CGFloat(min(size, 16))
                        Group {
                            if square { Rectangle() } else { Circle() }
                        }
                        .frame(width: side, height: side)
                        .frame(width: 18)
                        Text("\(size)").font(.caption2.monospacedDigit())
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(selection == size ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 4))
                .accessibilityLabel("\(label): \(size) px")
                .accessibilityAddTraits(selection == size ? .isSelected : [])
            }
        }
    }
}

/// Forma del pincel: redonda, cuadrada o caligráfica.
private struct ShapePicker: View {
    @Binding var selection: BrushShape

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BrushShape.allCases, id: \.self) { shape in
                Button {
                    selection = shape
                } label: {
                    icon(for: shape)
                        .frame(width: 14, height: 18)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(selection == shape ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 3))
                .help(name(for: shape))
                .accessibilityLabel(name(for: shape))
            }
        }
    }

    @ViewBuilder private func icon(for shape: BrushShape) -> some View {
        switch shape {
        case .round: Circle().frame(width: 8, height: 8)
        case .square: Rectangle().frame(width: 8, height: 8)
        case .forwardSlash: Text("/").font(.system(size: 13, weight: .heavy))
        case .backSlash: Text("\\").font(.system(size: 13, weight: .heavy))
        }
    }

    private func name(for shape: BrushShape) -> String {
        switch shape {
        case .round: "Redondo"
        case .square: "Cuadrado"
        case .forwardSlash: "Caligráfico /"
        case .backSlash: "Caligráfico \\"
        }
    }
}
