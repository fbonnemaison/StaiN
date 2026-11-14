import StainKit
import SwiftUI

/// Barra de colores: primario/secundario, paleta de 28 colores y colores recientes.
///
/// - Clic izquierdo en una muestra: color primario. Clic derecho: secundario.
/// - Doble clic en la paleta: editar esa muestra. Clic en primario/secundario: abrir el selector de color.
struct PaletteBar: View {
    let primary: PaintColor
    let secondary: PaintColor
    let setColors: (_ primary: PaintColor?, _ secondary: PaintColor?) -> Void
    let swapColors: () -> Void
    @State private var palette = PaletteStore.shared

    private let swatch: CGFloat = 16

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            currentColors
            Divider().frame(height: 36)
            paletteGrid
            if !palette.recent.isEmpty {
                Divider().frame(height: 36)
                recentColors
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var currentColors: some View {
        HStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                SwatchView(color: secondary, accessibilityLabel: "Color secundario") {
                    ColorPanelController.shared.edit(secondary) { setColors(nil, $0) }
                }
                .frame(width: 22, height: 22)
                .offset(x: 12, y: 12)
                .help("Color secundario (clic para editar)")
                SwatchView(color: primary, accessibilityLabel: "Color primario") {
                    ColorPanelController.shared.edit(primary) { setColors($0, nil) }
                }
                .frame(width: 22, height: 22)
                .help("Color primario (clic para editar)")
            }
            .frame(width: 34, height: 34, alignment: .topLeading)

            Button("Intercambiar colores", systemImage: "arrow.left.arrow.right", action: swapColors)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .keyboardShortcut("x", modifiers: [])
                .help("Intercambiar primario y secundario (X)")
        }
    }

    private var paletteGrid: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<PaletteStore.columns, id: \.self) { column in
                        let index = row * PaletteStore.columns + column
                        let color = palette.colors[index]
                        SwatchView(
                            color: color, accessibilityLabel: "Paleta \(index + 1)",
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
                }
            }
        }
        .contextMenu {
            Button("Restaurar paleta original") { palette.resetColors() }
        }
    }

    private var recentColors: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Recientes").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 2) {
                ForEach(Array(palette.recent.enumerated()), id: \.offset) { _, color in
                    SwatchView(
                        color: color, accessibilityLabel: "Color reciente",
                        onPrimaryClick: { setColors(color, nil) },
                        onSecondaryClick: { setColors(nil, color) }
                    )
                    .frame(width: swatch, height: swatch)
                }
            }
        }
    }
}
