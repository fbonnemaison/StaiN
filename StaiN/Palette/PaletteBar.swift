import StainKit
import SwiftUI

/// Barra de colores: primario/secundario, paleta elegida, 8 colores personalizados y recientes.
///
/// - Clic izquierdo en una muestra: color primario. Clic derecho: secundario.
/// - Doble clic en la paleta: editar esa muestra.
/// - Clic en primario/secundario: panel con valores RGB y HEX.
/// - Casillas personalizadas: clic en una vacía guarda el color primario; clic derecho abre su menú.
struct PaletteBar: View {
    let primary: PaintColor
    let secondary: PaintColor
    let setColors: (_ primary: PaintColor?, _ secondary: PaintColor?) -> Void
    let swapColors: () -> Void
    @State private var palette = PaletteStore.shared
    @State private var editing: ColorSlot?

    enum ColorSlot: String, Identifiable {
        case primary, secondary
        var id: Self { self }
    }

    private let swatch: CGFloat = 16

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            currentColors
            Divider().frame(height: 36)
            palettePicker
            paletteGrid
            Divider().frame(height: 36)
            customColors
            if !palette.recent.isEmpty {
                Divider().frame(height: 36)
                recentColors
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: Primario y secundario

    private var currentColors: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                SwatchView(
                    color: secondary, accessibilityLabel: String(localized: "Color secundario"), cornerRadius: 4
                ) { editing = .secondary }
                .frame(width: 22, height: 22)
                .offset(x: 12, y: 12)
                .help("Color secundario (clic para editar)")
                SwatchView(color: primary, accessibilityLabel: String(localized: "Color primario"), cornerRadius: 4) {
                    editing = .primary
                }
                .frame(width: 22, height: 22)
                .help("Color primario (clic para editar)")
            }
            .frame(width: 34, height: 34, alignment: .topLeading)
            .popover(item: $editing, arrowEdge: .top) { slot in
                ColorValueEditor(
                    title: slot == .primary ? "Color primario" : "Color secundario",
                    color: slot == .primary ? primary : secondary
                ) { newColor in
                    if slot == .primary { setColors(newColor, nil) } else { setColors(nil, newColor) }
                }
            }

            Button("Intercambiar colores", systemImage: "arrow.left.arrow.right", action: swapColors)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut("x", modifiers: [])
                .help("Intercambiar primario y secundario (X)")
        }
    }

    // MARK: Paleta

    private var palettePicker: some View {
        Picker("Paleta", selection: Binding(get: { palette.source }, set: { palette.select($0) })) {
            ForEach(PalettePreset.allCases, id: \.self) { preset in
                Text(title(for: .preset(preset), name: preset.title)).tag(PaletteStore.Source.preset(preset))
            }
            if !palette.imported.isEmpty {
                Divider()
                ForEach(palette.imported) { item in
                    Text(title(for: .imported(item.id), name: item.name)).tag(PaletteStore.Source.imported(item.id))
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .fixedSize()
        .help("Paleta de colores")
        .accessibilityIdentifier("palettePicker")
    }

    /// Nombre de la paleta, con "•" si es la elegida y tiene muestras editadas.
    private func title(for source: PaletteStore.Source, name: String) -> String {
        source == palette.source && palette.isModified ? "\(name) •" : name
    }

    private var paletteGrid: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(0..<palette.columns, id: \.self) { column in
                            let index = row * palette.columns + column
                            if index < palette.colors.count {
                                swatch(at: index)
                            } else {
                                Color.clear.frame(width: swatch, height: swatch)
                            }
                        }
                    }
                }
            }
        }
        .scrollIndicators(.never)
        .frame(maxWidth: CGFloat(palette.columns) * (swatch + 2))
        .contextMenu {
            Button("Cargar paleta…") { PaletteFiles.load(into: palette) }
            Button("Guardar paleta…") { PaletteFiles.save(palette.colors) }
            Divider()
            Button("Restaurar paleta original") { palette.resetColors() }
                .disabled(!palette.isModified)
            if case .imported(let id) = palette.source {
                Button("Quitar esta paleta del selector") { palette.removeImported(id) }
            }
        }
    }

    private func swatch(at index: Int) -> some View {
        let color = palette.colors[index]
        return SwatchView(
            color: color, accessibilityLabel: String(localized: "Paleta \(index + 1)"),
            onPrimaryClick: { setColors(color, nil) },
            onSecondaryClick: { setColors(nil, color) },
            onDoubleClick: {
                ColorPanelController.shared.edit(color) { newColor in
                    palette.setColor(newColor, at: index)
                    setColors(newColor, nil)
                }
            }
        )
        .frame(width: swatch, height: swatch)
    }

    // MARK: Colores personalizados

    private var customColors: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<PaletteStore.customSlotCount / 2, id: \.self) { column in
                        customSlot(row * PaletteStore.customSlotCount / 2 + column)
                    }
                }
            }
        }
        .help("Colores personalizados: clic en una casilla vacía para guardar el color primario")
    }

    private func customSlot(_ index: Int) -> some View {
        let color = palette.customColors[index]
        let save = { palette.setCustomColor(primary, at: index) }
        var items = [SwatchView.MenuItem(title: String(localized: "Guardar el color primario aquí"), action: save)]
        if let color {
            items.insert(
                SwatchView.MenuItem(title: String(localized: "Usar como color secundario")) { setColors(nil, color) },
                at: 0)
            items.append(
                SwatchView.MenuItem(title: String(localized: "Editar…")) {
                    ColorPanelController.shared.edit(color) { palette.setCustomColor($0, at: index) }
                })
            items.append(
                SwatchView.MenuItem(title: String(localized: "Vaciar")) { palette.setCustomColor(nil, at: index) })
        }
        return SwatchView(
            color: color, accessibilityLabel: String(localized: "Personalizado \(index + 1)"),
            onPrimaryClick: { if let color { setColors(color, nil) } else { save() } },
            onDoubleClick: color.map { color in
                { ColorPanelController.shared.edit(color) { palette.setCustomColor($0, at: index) } }
            },
            menuItems: items
        )
        .frame(width: swatch, height: swatch)
    }

    // MARK: Recientes

    private var recentColors: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Recientes").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(Array(palette.recent.enumerated()), id: \.offset) { _, color in
                    SwatchView(
                        color: color, accessibilityLabel: String(localized: "Color reciente"),
                        onPrimaryClick: { setColors(color, nil) },
                        onSecondaryClick: { setColors(nil, color) }
                    )
                    .frame(width: swatch, height: swatch)
                }
            }
        }
    }
}
