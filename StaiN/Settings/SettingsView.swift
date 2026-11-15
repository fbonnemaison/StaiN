import StainKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(AppSettings.Key.canvasWidth) private var width = AppSettings.defaultCanvasWidth
    @AppStorage(AppSettings.Key.canvasHeight) private var height = AppSettings.defaultCanvasHeight
    @AppStorage(AppSettings.Key.jpegQuality) private var jpegQuality = AppSettings.defaultJPEGQuality
    @AppStorage(AppSettings.Key.gridSpacing) private var gridSpacing = AppSettings.defaultGridSpacing
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppSettings.Appearance.system
    @AppStorage(AppSettings.Key.saveFormat) private var saveFormat = UTType.png.identifier
    @AppStorage(AppSettings.Key.pixelModeByDefault) private var pixelModeByDefault = false
    @AppStorage(PaletteStore.customColumnsKey) private var customColumns = PaletteStore.defaultCustomColumns

    var body: some View {
        Form {
            Section("General") {
                Picker("Apariencia", selection: $appearance) {
                    Text("Como el sistema").tag(AppSettings.Appearance.system)
                    Text("Clara").tag(AppSettings.Appearance.light)
                    Text("Oscura").tag(AppSettings.Appearance.dark)
                }
                .accessibilityIdentifier("appearancePicker")
            }
            Section("Documentos nuevos") {
                TextField("Ancho (px)", value: $width, format: .number)
                TextField("Alto (px)", value: $height, format: .number)
                Toggle("Empezar en modo pixel (sin suavizado)", isOn: $pixelModeByDefault)
            }
            Section("Colores") {
                Stepper(value: $customColumns, in: PaletteStore.customColumnsRange) {
                    LabeledContent("Columnas de colores personalizados", value: "\(customColumns)")
                }
                .accessibilityIdentifier("customColumnsStepper")
            }
            Section("Cuadrícula") {
                Stepper(value: $gridSpacing, in: 2...512) {
                    LabeledContent("Separación", value: "\(gridSpacing) px")
                }
            }
            Section("Guardar") {
                Picker("Formato por defecto", selection: $saveFormat) {
                    ForEach(ImageCodec.supportedTypes, id: \.identifier) { type in
                        Text(type.preferredFilenameExtension?.uppercased() ?? type.identifier).tag(type.identifier)
                    }
                }
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
        .onChange(of: appearance) { AppSettings.applyAppearance() }
        .onChange(of: width) { width = min(max(width, 1), AppSettings.maxCanvasSide) }
        .onChange(of: height) { height = min(max(height, 1), AppSettings.maxCanvasSide) }
    }
}
