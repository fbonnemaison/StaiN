import StainKit
import SwiftUI

/// Vista provisional de la Fase 0: muestra un lienzo vacío creado con StainKit.
/// Se reemplaza por `DocumentGroup` + `CanvasView` en la Fase 2.
struct ContentView: View {
    private let bitmap = Bitmap(width: 640, height: 480)

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Rectangle()
                .fill(.white)
                .frame(width: CGFloat(bitmap.width), height: CGFloat(bitmap.height))
                .shadow(radius: 2)
                .padding(24)
                .accessibilityIdentifier("canvas")
        }
        .background(.gray.opacity(0.25))
        .frame(minWidth: 480, minHeight: 360)
        .navigationTitle("Sin título")
        .navigationSubtitle("\(bitmap.width) × \(bitmap.height) px")
    }
}

#Preview {
    ContentView()
}
