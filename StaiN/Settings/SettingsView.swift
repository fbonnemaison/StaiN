import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Key.canvasWidth) private var width = AppSettings.defaultCanvasWidth
    @AppStorage(AppSettings.Key.canvasHeight) private var height = AppSettings.defaultCanvasHeight
    @AppStorage(AppSettings.Key.jpegQuality) private var jpegQuality = AppSettings.defaultJPEGQuality

    var body: some View {
        Form {
            Section("Documentos nuevos") {
                TextField("Ancho (px)", value: $width, format: .number)
                TextField("Alto (px)", value: $height, format: .number)
            }
            Section("Guardar") {
                LabeledContent("Calidad JPEG / HEIC") {
                    HStack {
                        Slider(value: $jpegQuality, in: 0.05...1)
                        Text(jpegQuality, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: width) { width = min(max(width, 1), AppSettings.maxCanvasSide) }
        .onChange(of: height) { height = min(max(height, 1), AppSettings.maxCanvasSide) }
    }
}
