import StainKit

/// Herramientas del panel. Cada una crea una herramienta nueva de StainKit al empezar un trazo.
enum ToolKind: String, CaseIterable, Identifiable {
    case pencil
    case zoom

    var id: Self { self }

    var title: String {
        switch self {
        case .pencil: "Lápiz"
        case .zoom: "Lupa"
        }
    }

    var systemImage: String {
        switch self {
        case .pencil: "pencil"
        case .zoom: "magnifyingglass"
        }
    }

    /// Atajo de una tecla, como en Paint.
    var shortcut: Character {
        switch self {
        case .pencil: "p"
        case .zoom: "z"
        }
    }

    /// Herramienta de dibujo, o `nil` si la herramienta solo actúa sobre la vista (lupa).
    func makeTool() -> (any Tool)? {
        switch self {
        case .pencil: PencilTool()
        case .zoom: nil
        }
    }
}
