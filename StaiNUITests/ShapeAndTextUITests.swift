import XCTest

/// Formas pendientes, polígono, texto y bomba (Fase 4).
final class ShapeAndTextUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(es)", "-paletteSource", "preset.classic",
            "-paletteColors", "()", "-customColors", "()", "-recentColors", "()", "-canvasWidth", "320",
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

    @MainActor private var canvas: XCUIElement { app.images["canvas"] }
    @MainActor private var undo: XCUIElement {
        app.menuBars.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Deshacer")).firstMatch
    }

    /// Los menús se revalidan de forma asíncrona: espera a que "Deshacer" cambie de estado.
    @MainActor
    private func expectUndo(enabled: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: undo)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 2), .completed, file: file, line: line)
    }

    @MainActor
    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        canvas.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    @MainActor
    func testPendingRectangleCountsAsChangeAndEscapeDiscards() {
        app.typeKey("r", modifierFlags: [])
        point(0.2, 0.2).click(forDuration: 0.1, thenDragTo: point(0.6, 0.7))
        // La forma sigue editable, pero ya cuenta como cambio (y se guardaría).
        expectUndo(enabled: true)
        XCTAssertTrue(undo.title.contains("Rectángulo"), "Menú: \(undo.title)")
        app.typeKey(.escape, modifierFlags: [])
        expectUndo(enabled: false)  // Escape la descarta, con su paso de deshacer
        point(0.2, 0.2).click(forDuration: 0.1, thenDragTo: point(0.6, 0.7))
        app.typeKey(.return, modifierFlags: [])
        expectUndo(enabled: true)
    }

    @MainActor
    func testPolygonClosesWithDoubleClick() {
        app.typeKey("g", modifierFlags: [])
        point(0.2, 0.2).click()
        point(0.8, 0.3).click()
        point(0.5, 0.8).doubleClick()
        expectUndo(enabled: true)
    }

    @MainActor
    func testTextIsRasterizedWhenClickingOutside() {
        app.typeKey("t", modifierFlags: [])
        XCTAssertTrue(app.popUpButtons["fontPicker"].waitForExistence(timeout: 2), "Aparece la barra de fuentes")
        point(0.1, 0.1).click()
        let box = app.textViews["textBox"]
        XCTAssertTrue(box.waitForExistence(timeout: 2))
        box.typeText("Hola")
        point(0.9, 0.9).click()
        XCTAssertFalse(box.exists)
        expectUndo(enabled: true)
    }

    @MainActor
    func testBombAsksForConfirmationAndReturnsToPreviousTool() {
        // Sobre un lienzo blanco, borrar con blanco no cambiaría nada: el secundario pasa a rojo.
        app.buttons["Paleta 17"].rightClick()
        expectUndo(enabled: false)
        app.buttons["tool.bomb"].click()
        point(0.5, 0.5).click()
        let erase = app.sheets.buttons["Borrar"].firstMatch
        XCTAssertTrue(erase.waitForExistence(timeout: 2))
        erase.click()
        expectUndo(enabled: true)
        XCTAssertTrue(app.buttons["tool.pencil"].isSelected)
    }

    @MainActor
    func testScreenshotOfShapes() {
        app.typeKey("o", modifierFlags: [])
        point(0.05, 0.1).click(forDuration: 0.1, thenDragTo: point(0.4, 0.6))
        app.typeKey(.return, modifierFlags: [])
        app.typeKey("u", modifierFlags: [])
        point(0.5, 0.2).click(forDuration: 0.1, thenDragTo: point(0.9, 0.8))
        let shot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("phase4.png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: shot)
    }
}
