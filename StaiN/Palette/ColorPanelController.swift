import AppKit
import StainKit

/// Abre el selector de color del sistema (con transparencia) y avisa de cada cambio.
@MainActor
final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var onChange: ((PaintColor) -> Void)?

    func edit(_ color: PaintColor, onChange: @escaping (PaintColor) -> Void) {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        self.onChange = nil  // asignar el color puede disparar la acción
        panel.color = color.nsColor
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        guard let color = PaintColor(nsColor: sender.color) else { return }
        onChange?(color)
    }
}
