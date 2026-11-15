import XCTest

/// Filtros, anotaciones y pixel art (Fase 6).
final class ExtrasUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(es)", "-paletteSource", "preset.classic",
            "-paletteColors", "()", "-customColors", "()", "-canvasWidth", "320",
            "-canvasHeight",
            "200",
        ]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
    }

    @MainActor
    override func tearDown() async throws {
        app.terminate()
    }

    @MainActor private var canvas: XCUIElement { app.images["canvas"].firstMatch }
    @MainActor private var undo: XCUIElement {
        app.menuBars.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Deshacer")).firstMatch
    }

    @MainActor
    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        canvas.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    @MainActor
    private func waitFor(
        _ element: XCUIElement, _ format: String, _ value: Any, file: StaticString = #filePath, line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: format, argumentArray: [value]), object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 3), .completed, "\(format) \(value)", file: file, line: line)
    }

    @MainActor
    private func menu(_ bar: String, _ item: String) {
        app.menuBars.menuBarItems[bar].click()
        app.menuItems[item].click()
    }

    @MainActor
    private func screenshot(_ name: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: url)
    }

    @MainActor
    func testFilterWithoutParametersAppliesImmediately() {
        point(0.2, 0.5).click(forDuration: 0.1, thenDragTo: point(0.8, 0.5))
        app.typeKey("z", modifierFlags: .command)
        waitFor(undo, "isEnabled == %@", false)
        menu("Filtros", "Invertir")
        waitFor(undo, "isEnabled == %@", true)
    }

    @MainActor
    func testFilterSheetShowsPreviewAndApplies() {
        app.buttons["Paleta 17"].click()
        app.typeKey("b", modifierFlags: [])
        point(0.2, 0.5).click(forDuration: 0.1, thenDragTo: point(0.8, 0.5))
        app.typeKey("z", modifierFlags: .command)
        app.typeKey("z", modifierFlags: [.command, .shift])
        menu("Filtros", "Desenfoque…")
        XCTAssertTrue(app.sheets.images["filterPreview"].waitForExistence(timeout: 3))
        screenshot("phase6-filter")
        app.sheets.buttons["Aplicar"].click()
        XCTAssertFalse(app.sheets.firstMatch.exists)
    }

    @MainActor
    func testAnnotationTools() {
        app.buttons["Paleta 17"].click()  // rojo
        app.typeKey("h", modifierFlags: [])
        app.buttons["Paleta 18"].click()  // amarillo
        point(0.05, 0.15).click(forDuration: 0.1, thenDragTo: point(0.6, 0.15))
        app.buttons["Paleta 17"].click()
        app.typeKey("w", modifierFlags: [])
        point(0.15, 0.8).click(forDuration: 0.1, thenDragTo: point(0.45, 0.4))
        app.typeKey("n", modifierFlags: [])
        point(0.7, 0.3).click()
        point(0.85, 0.3).click()
        XCTAssertEqual(app.staticTexts["nextMarker"].value as? String, "Siguiente: 3")
        app.typeKey("t", modifierFlags: [])
        app.typeKey("p", modifierFlags: [])
        app.buttons["Paleta 1"].click()
        app.typeKey("b", modifierFlags: [])
        for row in stride(from: 0.62, through: 0.9, by: 0.07) {
            point(0.6, row).click(forDuration: 0.05, thenDragTo: point(0.95, row))
        }
        app.typeKey("k", modifierFlags: [])
        point(0.58, 0.58).click(forDuration: 0.1, thenDragTo: point(0.78, 0.95))
        waitFor(undo, "isEnabled == %@", true)
        screenshot("phase6-annotate")
    }

    @MainActor
    func testNewFromClipboard() {
        app.typeKey("c", modifierFlags: [.command, .shift])
        app.typeKey("n", modifierFlags: [.command, .shift])
        waitFor(app.windows.element(boundBy: 1), "exists == %@", true)
    }

    @MainActor
    func testPixelArtTemplateWithSymmetry() {
        app.menuBars.menuBarItems["Archivo"].click()
        app.menuItems["Nuevo pixel art"].hover()
        app.menuItems["16 × 16"].click()
        let size = app.staticTexts["imageSize"].firstMatch
        waitFor(size, "value == %@", "16 × 16 px")
        XCTAssertTrue(app.staticTexts["Modo pixel"].exists, "Las imágenes pequeñas activan el modo pixel")
        let zoom = app.windows.firstMatch.popUpButtons["zoomLevel"]
        XCTAssertEqual(
            (zoom.value as? String ?? "").filter(\.isNumber), "2400", "Zoom inicial: \((zoom.value as? String ?? ""))")

        app.menuBars.menuBarItems["Visualización"].click()
        app.menuItems["Simetría"].hover()
        app.menuItems["Horizontal (izquierda ↔ derecha)"].click()
        XCTAssertTrue(app.staticTexts["Modo pixel · Simetría ↔"].waitForExistence(timeout: 2))

        let pixelCanvas = app.windows.firstMatch.images["canvas"]
        pixelCanvas.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2))
            .click(
                forDuration: 0.1, thenDragTo: pixelCanvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.7)))
        waitFor(undo, "isEnabled == %@", true)
        screenshot("phase6-pixel")
    }
}
