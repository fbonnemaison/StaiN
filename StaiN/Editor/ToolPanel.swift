import AppKit
import StainKit
import SwiftUI

/// Panel izquierdo: cuadrícula de herramientas y, debajo, las opciones de la herramienta activa.
struct ToolPanel: View {
    @Bindable var editor: EditorState

    private static let columnCount = 2

    var body: some View {
        // Con ventanas bajas, el panel se desplaza en vez de salirse por arriba.
        ScrollView(.vertical) {
            VStack(spacing: 10) {
                // Grid (no LazyVGrid): en las cuadrículas perezosas los tooltips no siempre aparecen.
                let tools = ToolKind.allCases
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    ForEach(Array(stride(from: 0, to: tools.count, by: Self.columnCount)), id: \.self) { start in
                        GridRow {
                            ForEach(tools[start..<min(start + Self.columnCount, tools.count)]) { tool in
                                ToolButton(tool: tool, isSelected: editor.tool == tool) { editor.tool = tool }
                            }
                        }
                    }
                }
                Divider()
                ToolOptions(editor: editor)
            }
            .padding(6)
        }
        .scrollIndicators(.never)
        .frame(width: 76)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Herramientas")
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
        .background(ToolTip(text: tool.shortcut.map { "\(tool.title) (\(String($0).uppercased()))" } ?? tool.title))
        .modifier(OptionalShortcut(key: tool.shortcut))
        .accessibilityLabel(tool.title)
        .accessibilityIdentifier("tool.\(tool.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Tooltip de AppKit: aparece al detener el cursor sobre la herramienta, aunque el lienzo
/// tenga el foco o la ventana use cursores propios (donde `.help` a veces no se muestra).
private struct ToolTip: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> ToolTipView { ToolTipView() }

    func updateNSView(_ view: ToolTipView, context: Context) {
        view.toolTip = text
    }

    final class ToolTipView: NSView {
        /// No intercepta clics: solo aporta el tooltip.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

private struct OptionalShortcut: ViewModifier {
    let key: Character?

    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(KeyEquivalent(key), modifiers: [])
        } else {
            content
        }
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
                CheckboxOption(title: "Transparente", isOn: $editor.erasesToTransparent)
                    .help("Borrar dejando píxeles transparentes en vez del color secundario")
            case .fill:
                Text("Tolerancia").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $editor.fillTolerance, in: 0...1)
                    .controlSize(.mini)
                    .accessibilityLabel("Tolerancia del relleno")
                Text(editor.fillTolerance, format: .percent.precision(.fractionLength(0)))
                    .font(.caption2.monospacedDigit())
            case .line, .curve:
                SizeList(sizes: EditorState.lineWidths, selection: $editor.lineWidth, label: "Grosor de línea")
            case .rectangle, .roundedRectangle, .ellipse, .polygon:
                if editor.tool == .polygon {
                    PolygonShapePicker(selection: $editor.polygonShape)
                }
                FillModePicker(selection: $editor.shapeFillMode)
                SizeList(sizes: EditorState.lineWidths, selection: $editor.shapeLineWidth, label: "Grosor del borde")
            case .cloud:
                CloudArcSizePicker(selection: $editor.cloudArcSize)
                SizeList(sizes: EditorState.lineWidths, selection: $editor.shapeLineWidth, label: "Grosor del borde")
            case .airbrush:
                SizeList(sizes: EditorState.airbrushRadii, selection: $editor.airbrushRadius, label: "Radio")
            case .arrow:
                SizeList(sizes: EditorState.arrowWidths, selection: $editor.arrowWidth, label: "Grosor de la flecha")
            case .highlighter:
                SizeList(sizes: EditorState.highlighterSizes, selection: $editor.highlighterSize, label: "Tamaño")
            case .redact:
                RedactModePicker(selection: $editor.redactMode)
            case .marker:
                SizeList(sizes: EditorState.markerRadii, selection: $editor.markerRadius, label: "Radio")
                Text("Siguiente: \(editor.nextMarker)").font(.caption2.monospacedDigit())
                    .accessibilityIdentifier("nextMarker")
                Button("Reiniciar") { editor.nextMarker = 1 }
                    .controlSize(.mini)
            case .text, .bomb, .eyedropper, .zoom, .pencil:
                // Sin opciones: su ayuda se muestra en la barra de estado.
                EmptyView()
            case .select, .freeFormSelect:
                CheckboxOption(title: "Transparente", isOn: $editor.transparentSelection)
                    .help("Al mover o pegar, el color secundario no tapa lo de debajo")
                    .accessibilityIdentifier("transparentSelection")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Lista de tamaños: cada fila muestra un punto del tamaño real (limitado para que quepa).
private struct SizeList: View {
    let sizes: [Int]
    @Binding var selection: Int
    var square = false
    let label: LocalizedStringResource

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
                .accessibilityLabel("\(String(localized: label)): \(size) px")
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
        case .round: String(localized: "Redondo")
        case .square: String(localized: "Cuadrado")
        case .forwardSlash: String(localized: "Caligráfico /")
        case .backSlash: String(localized: "Caligráfico \\")
        }
    }
}

/// Galería de la herramienta Polígono: polígono libre o una forma predefinida (triángulos, rombo,
/// pentágono, hexágono y flechas).
private struct PolygonShapePicker: View {
    @Binding var selection: ShapeKind?

    private static let options: [ShapeKind?] = [nil] + ShapeKind.polygonPresets.map(Optional.some)
    private let columns = Array(repeating: GridItem(.fixed(18), spacing: 2), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Self.options, id: \.self) { kind in
                Button {
                    selection = kind
                } label: {
                    icon(kind)
                        .stroke(.primary, lineWidth: 1.2)
                        .frame(width: 12, height: 12)
                        .frame(width: 18, height: 18)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(selection == kind ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 3))
                .help(name(kind))
                .accessibilityLabel(name(kind))
                .accessibilityAddTraits(selection == kind ? .isSelected : [])
            }
        }
    }

    private func icon(_ kind: ShapeKind?) -> Path {
        let frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        guard let kind else {
            // Polígono irregular, como el del icono clásico.
            return Path { path in
                path.addLines([
                    CGPoint(x: 0, y: 12), CGPoint(x: 3, y: 2), CGPoint(x: 8, y: 0), CGPoint(x: 7, y: 5),
                    CGPoint(x: 12, y: 6), CGPoint(x: 9, y: 12),
                ])
                path.closeSubpath()
            }
        }
        return Path(kind.path(in: frame))
    }

    private func name(_ kind: ShapeKind?) -> String {
        switch kind {
        case nil: String(localized: "Polígono libre")
        case .rightTriangle: String(localized: "Triángulo rectángulo")
        case .isoscelesTriangle: String(localized: "Triángulo isósceles")
        case .diamond: String(localized: "Rombo")
        case .pentagon: String(localized: "Pentágono")
        case .hexagon: String(localized: "Hexágono")
        case .arrowRight: String(localized: "Flecha a la derecha")
        case .arrowLeft: String(localized: "Flecha a la izquierda")
        case .arrowUp: String(localized: "Flecha hacia arriba")
        case .arrowDown: String(localized: "Flecha hacia abajo")
        default: kind?.rawValue ?? ""
        }
    }
}

/// Tamaño de los arcos de la nube: pequeño, mediano o grande.
private struct CloudArcSizePicker: View {
    @Binding var selection: CloudArcSize

    var body: some View {
        VStack(spacing: 2) {
            ForEach(CloudArcSize.allCases, id: \.self) { size in
                Button {
                    selection = size
                } label: {
                    preview(size)
                        .stroke(.primary, lineWidth: 1.2)
                        .frame(width: 40, height: 10)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(selection == size ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 4))
                .help(name(size))
                .accessibilityLabel(name(size))
                .accessibilityAddTraits(selection == size ? .isSelected : [])
            }
        }
    }

    /// Fila de arcos del tamaño elegido.
    private func preview(_ size: CloudArcSize) -> Path {
        let count =
            switch size {
            case .small: 5
            case .medium: 3
            case .large: 2
            }
        let chord = 40.0 / Double(count)
        return Path { path in
            for index in 0..<count {
                let center = CGPoint(x: chord * (Double(index) + 0.5), y: 10)
                path.addArc(
                    center: center, radius: min(chord / 2, 9), startAngle: .degrees(180), endAngle: .degrees(0),
                    clockwise: false)
            }
        }
    }

    private func name(_ size: CloudArcSize) -> String {
        switch size {
        case .small: String(localized: "Arcos pequeños")
        case .medium: String(localized: "Arcos medianos")
        case .large: String(localized: "Arcos grandes")
        }
    }
}

/// Contorno, contorno y relleno, o solo relleno.
private struct FillModePicker: View {
    @Binding var selection: ShapeFillMode

    var body: some View {
        VStack(spacing: 2) {
            ForEach(ShapeFillMode.allCases, id: \.self) { mode in
                Button {
                    selection = mode
                } label: {
                    preview(mode)
                        .frame(width: 34, height: 14)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(selection == mode ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 4))
                .help(name(mode))
                .accessibilityLabel(name(mode))
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private func preview(_ mode: ShapeFillMode) -> some View {
        switch mode {
        case .outline: Rectangle().strokeBorder(.primary, lineWidth: 1.5)
        case .outlineAndFill: Rectangle().fill(.gray).overlay(Rectangle().strokeBorder(.primary, lineWidth: 1.5))
        case .fill: Rectangle().fill(.gray)
        }
    }

    private func name(_ mode: ShapeFillMode) -> String {
        switch mode {
        case .outline: String(localized: "Solo contorno")
        case .outlineAndFill: String(localized: "Contorno y relleno")
        case .fill: String(localized: "Solo relleno")
        }
    }
}

/// Casilla con el texto debajo, para que quepa en el panel estrecho.
private struct CheckboxOption: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 2) {
            Toggle(isOn: $isOn) { Text(title) }
                .labelsHidden()
                .toggleStyle(.checkbox)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .onTapGesture { isOn.toggle() }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Pixelar, desenfocar o tapar con un bloque del color del botón.
private struct RedactModePicker: View {
    @Binding var selection: RedactTool.Mode

    var body: some View {
        VStack(spacing: 2) {
            ForEach(RedactTool.Mode.allCases, id: \.self) { mode in
                Button {
                    selection = mode
                } label: {
                    Text(name(mode))
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .background(selection == mode ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 4))
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
    }

    private func name(_ mode: RedactTool.Mode) -> String {
        switch mode {
        case .pixelate: String(localized: "Pixelar")
        case .blur: String(localized: "Desenfocar")
        case .block: String(localized: "Bloque")
        }
    }
}
