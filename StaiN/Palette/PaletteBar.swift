import StainKit
import SwiftUI

/// Barra de colores, de izquierda a derecha: primario/secundario, colores personalizados (con su menú)
/// y la paleta elegida (con su menú desplegable al final).
///
/// - Clic izquierdo en una muestra: color primario. Clic derecho: secundario.
/// - Las paletas no se editan; se elige otra o se carga una de archivo.
/// - Clic en primario/secundario: panel con valores RGB y HEX.
/// - Casillas personalizadas: clic en una vacía guarda el color primario; clic derecho abre su menú;
///   doble clic edita una llena. Su menú desplegable cambia las columnas (1–14) y las guarda como JSON.
struct PaletteBar: View {
    let primary: PaintColor
    let secondary: PaintColor
    let setColors: (_ primary: PaintColor?, _ secondary: PaintColor?) -> Void
    let swapColors: () -> Void
    @State private var palette = PaletteStore.shared
    @State private var editing: ColorSlot?
    @AppStorage(PaletteStore.customColumnsKey) private var customColumns = PaletteStore.defaultCustomColumns

    enum ColorSlot: String, Identifiable {
        case primary, secondary
        var id: Self { self }
    }

    private let swatch: CGFloat = 16

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            currentColors
            Divider().frame(height: 36)
            HStack(spacing: 4) {
                customColors
                customMenu
            }
            Divider().frame(height: 36)
            HStack(spacing: 4) {
                paletteGrid
                paletteMenu
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

    /// Botón con flecha al final de la paleta: elegir la paleta y cargar/guardar/restaurar.
    private var paletteMenu: some View {
        Menu {
            Picker("Paleta", selection: Binding(get: { palette.source }, set: { palette.select($0) })) {
                ForEach(PalettePreset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(PaletteStore.Source.preset(preset))
                }
                if !palette.imported.isEmpty {
                    Divider()
                    ForEach(palette.imported) { item in
                        Text(item.name).tag(PaletteStore.Source.imported(item.id))
                    }
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            paletteActions
        } label: {
            chevron("Paleta de colores")
        }
        .modifier(BarMenuStyle())
        .help("Elegir o cargar una paleta de colores")
        .accessibilityLabel("Paleta de colores")
        .accessibilityIdentifier("palettePicker")
    }

    @ViewBuilder private var paletteActions: some View {
        Button("Cargar paleta…") { PaletteFiles.load(into: palette) }
        if case .imported(let id) = palette.source {
            Button("Quitar esta paleta del selector") { palette.removeImported(id) }
        }
    }

    /// Flecha de los menús desplegables de la barra, del alto de las dos filas de muestras.
    private func chevron(_ title: LocalizedStringKey) -> some View {
        Label(title, systemImage: "chevron.down")
            .labelStyle(.iconOnly)
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 18, height: 2 * swatch + 2)
            .contentShape(.rect)
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
        .contextMenu { paletteActions }
    }

    private func swatch(at index: Int) -> some View {
        let color = palette.colors[index]
        return SwatchView(
            color: color, accessibilityLabel: String(localized: "Paleta \(index + 1)"),
            onPrimaryClick: { setColors(color, nil) },
            onSecondaryClick: { setColors(nil, color) }
        )
        .frame(width: swatch, height: swatch)
    }

    // MARK: Colores personalizados

    /// Columnas visibles (2 filas), dentro del rango permitido.
    private var columns: Int {
        min(max(customColumns, PaletteStore.customColumnsRange.lowerBound), PaletteStore.customColumnsRange.upperBound)
    }

    private var customColors: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { column in
                        customSlot(row * columns + column)
                    }
                }
            }
        }
        .help("Colores personalizados: clic en una casilla vacía para guardar el color primario")
    }

    private var customMenu: some View {
        Menu {
            Button("Guardar como paleta…") { PaletteFiles.saveJSON(palette.filledCustomColors) }
                .disabled(palette.filledCustomColors.isEmpty)
            Divider()
            Picker("Columnas", selection: $customColumns) {
                ForEach(PaletteStore.customColumnsRange, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            Divider()
            Button("Vaciar todos") { palette.clearCustomColors() }
                .disabled(palette.filledCustomColors.isEmpty)
        } label: {
            chevron("Colores personalizados")
        }
        .modifier(BarMenuStyle())
        .help("Guardar los colores personalizados como paleta o cambiar sus columnas")
        .accessibilityIdentifier("customColorsMenu")
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
}

/// Botón de menú con solo la flecha, sobre un fondo suave.
private struct BarMenuStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.borderless)
            .background(.quaternary, in: .rect(cornerRadius: 4))
            .fixedSize()
    }
}
