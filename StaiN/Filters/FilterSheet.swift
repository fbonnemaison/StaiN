import AppKit
import StainKit
import SwiftUI

/// Diálogo de un filtro: parámetros y vista previa en vivo (sobre una copia reducida).
struct FilterSheet: View {
    let kind: FilterKind
    let document: ImageDocument
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: Double] = [:]
    @State private var source: Bitmap?
    @State private var scale = 1.0
    @State private var preview: NSImage?

    private static let previewSide = 320.0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let preview {
                    Image(nsImage: preview)
                        .resizable()
                        .interpolation(kind == .pixelate ? .none : .medium)
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                }
            }
            .frame(width: Self.previewSide, height: Self.previewSide * 0.66)
            .background(Color(nsColor: Checkerboard.color))
            .padding()
            .accessibilityIdentifier("filterPreview")

            if !kind.parameters.isEmpty {
                Form {
                    ForEach(kind.parameters) { parameter in
                        LabeledContent(parameter.title) {
                            HStack {
                                Slider(value: binding(parameter), in: parameter.range)
                                Text(binding(parameter).wrappedValue, format: .number.precision(.fractionLength(0...2)))
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }

            HStack {
                Group {
                    if document.hasSelection {
                        Text("Se aplicará a la selección")
                    } else {
                        Text("Se aplicará a toda la imagen")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Aplicar") {
                    let filter = kind.filter(values)
                    document.transform(kind.title) { filter.apply(to: $0) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400)
        .navigationTitle(kind.title)
        .onAppear(perform: prepare)
        .onChange(of: values) { updatePreview() }
    }

    private func binding(_ parameter: FilterKind.Parameter) -> Binding<Double> {
        Binding(
            get: { values[parameter.id] ?? parameter.defaultValue },
            set: { values[parameter.id] = $0 })
    }

    /// Reduce la imagen (o la selección) para que la vista previa sea rápida.
    private func prepare() {
        let full = document.selectedPixels ?? document.canvas.bitmap
        let factor = min(1, Self.previewSide / Double(max(full.width, full.height)))
        scale = factor
        source = full.resized(
            width: max(1, Int(Double(full.width) * factor)), height: max(1, Int(Double(full.height) * factor)),
            smooth: true)
        updatePreview()
    }

    private func updatePreview() {
        guard let source else { return }
        let result = kind.filter(values, pixelScale: scale).apply(to: source)
        if let image = result.makeCGImage() {
            preview = NSImage(cgImage: image, size: NSSize(width: result.width, height: result.height))
        }
    }
}
