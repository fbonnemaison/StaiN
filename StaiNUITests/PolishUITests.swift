import XCTest

/// Accesibilidad y apariencia (Fase 7).
final class PolishUITests: XCTestCase {
    @MainActor
    private func launch(appearance: String, language: String = "es") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(\(language))", "-paletteSource",
            "preset.classic", "-paletteColors", "()", "-customColors", "()",
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
            // El Picker y el Menu de SwiftUI no exponen AXPress (sí AXShowMenu): VoiceOver los abre igual.
            if issue.auditType == .action, type == .popUpButton || type == .menuButton { return true }
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

    /// Captura para el README: un dibujo sencillo con una selección activa (se ven sus puntos de control).
    /// Se guarda en el directorio temporal del ejecutor de tests como `readme-screenshot.png`.
    @MainActor
    func testReadmeScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(es)", "-paletteSource", "preset.classic",
            "-paletteColors", "()", "-customColors", "()", "-canvasWidth", "560", "-canvasHeight", "340",
            "-appearance", "light",
        ]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        let canvas = app.images["canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))

        func point(_ x: Double, _ y: Double) -> XCUICoordinate {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
        }
        func drag(_ from: (Double, Double), _ to: (Double, Double)) {
            point(from.0, from.1).click(forDuration: 0.1, thenDragTo: point(to.0, to.1))
            app.typeKey(.return, modifierFlags: [])
        }
        func colors(primary: Int, secondary: Int) {
            app.buttons["Paleta \(primary)"].click()
            app.buttons["Paleta \(secondary)"].rightClick()
        }

        // Cielo.
        colors(primary: 25, secondary: 15)
        app.buttons["tool.fill"].click()
        point(0.5, 0.3).click()

        // Suelo.
        colors(primary: 5, secondary: 19)
        app.buttons["tool.rectangle"].click()
        app.buttons["Contorno y relleno"].click()
        drag((0.0, 0.72), (1.0, 1.0))

        // Sol.
        colors(primary: 28, secondary: 18)
        app.buttons["tool.ellipse"].click()
        app.buttons["Contorno y relleno"].click()
        drag((0.72, 0.1), (0.9, 0.38))

        // Casa: paredes, tejado y puerta.
        colors(primary: 1, secondary: 23)
        app.buttons["tool.rectangle"].click()
        drag((0.18, 0.45), (0.42, 0.8))
        colors(primary: 1, secondary: 17)
        app.buttons["tool.polygon"].click()
        point(0.15, 0.46).click()
        point(0.3, 0.22).click()
        point(0.45, 0.46).click()
        point(0.15, 0.46).doubleClick()
        app.typeKey(.return, modifierFlags: [])
        colors(primary: 1, secondary: 14)
        app.buttons["tool.rectangle"].click()
        drag((0.27, 0.6), (0.33, 0.8))

        // Trazo de pincel.
        colors(primary: 22, secondary: 15)
        app.buttons["tool.brush"].click()
        point(0.55, 0.62).click(forDuration: 0.1, thenDragTo: point(0.82, 0.58))

        // Selección alrededor del sol, con sus puntos de control.
        app.buttons["tool.select"].click()
        point(0.68, 0.06).click(forDuration: 0.1, thenDragTo: point(0.94, 0.42))
        colors(primary: 1, secondary: 15)

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("readme-screenshot.png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: url)
        app.terminate()
    }
}
