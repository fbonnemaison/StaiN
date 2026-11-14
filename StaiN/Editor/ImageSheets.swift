import StainKit
import SwiftUI

/// "Cambiar tamaño e inclinar" (⌘R): en porcentaje o píxeles, con o sin proporción, y grados de inclinación.
struct ResizeSheet: View {
    let document: ImageDocument
    @Environment(\.dismiss) private var dismiss

    enum Unit: String, CaseIterable, Identifiable {
        case percent = "Porcentaje"
        case pixels = "Píxeles"
        var id: Self { self }
    }

    @State private var unit: Unit = .percent
    @State private var horizontal = 100.0
    @State private var vertical = 100.0
    @State private var keepsRatio = true
    @State private var smooth = true
    @State private var skewX = 0.0
    @State private var skewY = 0.0

    private var original: (width: Int, height: Int) { (document.width, document.height) }

    private var target: (width: Int, height: Int) {
        switch unit {
        case .percent:
            (
                Int((Double(original.width) * horizontal / 100).rounded()),
                Int((Double(original.height) * vertical / 100).rounded())
            )
        case .pixels:
            (Int(horizontal.rounded()), Int(vertical.rounded()))
        }
    }

    private var isValid: Bool {
        (1...AppSettings.maxCanvasSide).contains(target.width)
            && (1...AppSettings.maxCanvasSide).contains(target.height)
            && abs(skewX) < 90 && abs(skewY) < 90
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Cambiar tamaño") {
                    Picker("Unidad", selection: $unit) {
                        ForEach(Unit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Horizontal", value: $horizontal, format: .number.precision(.fractionLength(0...1)))
                        .accessibilityIdentifier("resizeHorizontal")
                    TextField("Vertical", value: $vertical, format: .number.precision(.fractionLength(0...1)))
                        .disabled(keepsRatio)
                        .accessibilityIdentifier("resizeVertical")
                    Toggle("Mantener proporción", isOn: $keepsRatio)
                    Picker("Calidad", selection: $smooth) {
                        Text("Suave (fotos)").tag(true)
                        Text("Píxeles nítidos").tag(false)
                    }
                    LabeledContent("Resultado", value: "\(target.width) × \(target.height) px")
                }
                Section("Inclinar (grados)") {
                    TextField("Horizontal", value: $skewX, format: .number)
                    TextField("Vertical", value: $skewY, format: .number)
                }
            }
            .formStyle(.grouped)
            .onChange(of: unit) { _, newUnit in
                horizontal = newUnit == .percent ? 100 : Double(original.width)
                vertical = newUnit == .percent ? 100 : Double(original.height)
            }
            .onChange(of: horizontal) { syncVertical() }
            .onChange(of: keepsRatio) { syncVertical() }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Aceptar") {
                    apply()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 380)
    }

    private func syncVertical() {
        guard keepsRatio else { return }
        vertical =
            unit == .percent
            ? horizontal : (horizontal * Double(original.height) / Double(original.width)).rounded()
    }

    private func apply() {
        let size = target
        let skewH = skewX, skewV = skewY, isSmooth = smooth
        let background = document.secondaryColor
        document.transform("Cambiar tamaño") { bitmap in
            var result = bitmap
            if document.hasSelection {
                // A la selección se le aplica el porcentaje (en píxeles, respecto a la imagen).
                let scaleX = Double(size.width) / Double(max(1, document.width))
                let scaleY = Double(size.height) / Double(max(1, document.height))
                result = result.resized(
                    width: Int((Double(bitmap.width) * scaleX).rounded()),
                    height: Int((Double(bitmap.height) * scaleY).rounded()), smooth: isSmooth)
            } else {
                result = result.resized(width: size.width, height: size.height, smooth: isSmooth)
            }
            return result.skewed(horizontalDegrees: skewH, verticalDegrees: skewV, background: background)
        }
    }
}

/// "Tamaño del lienzo" (⌘E): cambia el lienzo sin escalar, con ancla 3 × 3.
struct CanvasSizeSheet: View {
    let document: ImageDocument
    @Environment(\.dismiss) private var dismiss
    @State private var width = 0
    @State private var height = 0
    @State private var anchor: CanvasAnchor = .topLeft

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Tamaño del lienzo") {
                    TextField("Ancho (px)", value: $width, format: .number)
                        .accessibilityIdentifier("canvasWidth")
                    TextField("Alto (px)", value: $height, format: .number)
                        .accessibilityIdentifier("canvasHeight")
                    LabeledContent("Actual", value: "\(document.width) × \(document.height) px")
                }
                Section("Posición de la imagen") {
                    AnchorPicker(selection: $anchor)
                        .frame(maxWidth: .infinity)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Aceptar") {
                    let resized = document.canvas.bitmap.resizedCanvas(
                        width: width, height: height, anchor: anchor, fill: document.secondaryColor)
                    document.replaceImage(with: resized, actionName: "Tamaño del lienzo")
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    !(1...AppSettings.maxCanvasSide).contains(width)
                        || !(1...AppSettings.maxCanvasSide).contains(height))
            }
            .padding()
        }
        .frame(width: 340)
        .onAppear {
            width = document.width
            height = document.height
        }
    }
}

private struct AnchorPicker: View {
    @Binding var selection: CanvasAnchor

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        let anchor = CanvasAnchor(rawValue: row * 3 + column) ?? .topLeft
                        Button {
                            selection = anchor
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(selection == anchor ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ancla \(row * 3 + column + 1)")
                        .accessibilityAddTraits(selection == anchor ? .isSelected : [])
                    }
                }
            }
        }
    }
}
