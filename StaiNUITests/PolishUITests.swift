import XCTest

/// Accesibilidad y apariencia (Fase 7).
final class PolishUITests: XCTestCase {
    @MainActor
    private func launch(appearance: String, language: String = "es") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(\(language))",
            "-canvasWidth", "320", "-canvasHeight", "200", "-appearance", appearance,
        ]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.images["canvas"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testAccessibilityAudit() throws {
        let app = launch(appearance: "system")
        var issues: [String] = []
        try app.performAccessibilityAudit { issue in
            // La Touch Bar la crea el sistema; los contenedores de SwiftUI/AppKit sin interacción
            // (grupo de la ventana, vista de desplazamiento del panel) no necesitan descripción.
            let type = issue.element?.elementType
            if type == .touchBar { return true }
            if issue.auditType == .sufficientElementDescription, type == .group || type == .other { return true }
            // El Picker de SwiftUI en estilo menú no expone AXPress (sí AXShowMenu): VoiceOver lo abre igual.
            if issue.auditType == .action, type == .popUpButton { return true }
            issues.append("\(issue.compactDescription) – \(issue.element?.debugDescription.prefix(160) ?? "")")
            return true
        }
        for issue in issues { print("AUDIT", issue) }
        XCTAssertTrue(issues.isEmpty, "Problemas de accesibilidad:\n" + issues.joined(separator: "\n"))
        app.terminate()
    }

    @MainActor
    func testLightAppearanceScreenshot() {
        let app = launch(appearance: "light")
        let canvas = app.images["canvas"]
        app.typeKey("r", modifierFlags: [])
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .click(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.8)))
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("phase7-light.png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: url)
        app.terminate()
    }

    @MainActor
    func testEnglishLocalization() {
        let app = launch(appearance: "system", language: "en")
        XCTAssertEqual(app.buttons["tool.pencil"].label, "Pencil")
        XCTAssertEqual(app.buttons["tool.freeFormSelect"].label, "Free-Form Selection")
        XCTAssertTrue(app.menuBars.menuBarItems["Image"].exists)
        XCTAssertTrue(app.menuBars.menuBarItems["Filters"].exists)
        XCTAssertEqual(app.staticTexts["imageSize"].value as? String, "320 × 200 px")
        app.typeKey("r", modifierFlags: [])
        app.images["canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .click(
                forDuration: 0.1,
                thenDragTo: app.images["canvas"].coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)))
        let undo = app.menuBars.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo")).firstMatch
        XCTAssertEqual(undo.title, "Undo Rectangle")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("phase7-english.png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: url)
        app.terminate()
    }
}
