import XCTest

/// Selección, portapapeles y menú Imagen (Fase 5).
/// Nota: estos tests usan el portapapeles del sistema.
final class SelectionUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-canvasWidth", "320", "-canvasHeight", "200"]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
    }

    @MainActor
    override func tearDown() async throws {
        app.terminate()
    }

    @MainActor private var canvas: XCUIElement { app.images["canvas"] }
    @MainActor private var undo: XCUIElement { app.menuItems["undo:"] }
    @MainActor private var imageSize: String { app.staticTexts["imageSize"].value as? String ?? "" }

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
            XCTWaiter.wait(for: [expectation], timeout: 3), .completed, "\(element) \(format) \(value)", file: file,
            line: line)
    }

    @MainActor
    func testSelectCutAndPaste() {
        // Algo que cortar: un trazo de lápiz.
        point(0.4, 0.4).click(forDuration: 0.1, thenDragTo: point(0.6, 0.6))
        app.typeKey("s", modifierFlags: [])
        point(0.25, 0.25).click(forDuration: 0.1, thenDragTo: point(0.75, 0.75))
        XCTAssertTrue(
            app.staticTexts["selectionSize"].waitForExistence(timeout: 2), "La barra de estado muestra la selección")

        app.typeKey("x", modifierFlags: .command)
        XCTAssertFalse(app.staticTexts["selectionSize"].exists, "Cortar quita la selección")

        app.typeKey("v", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["selectionSize"].waitForExistence(timeout: 2), "Lo pegado queda seleccionado")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertFalse(app.staticTexts["selectionSize"].exists)
        waitFor(undo, "isEnabled == %@", true)
    }

    @MainActor
    func testSelectAllAndCrop() {
        app.typeKey("a", modifierFlags: .command)
        let selection = app.staticTexts["selectionSize"]
        XCTAssertTrue(selection.waitForExistence(timeout: 2))
        XCTAssertEqual(selection.value as? String, "320 × 200 px")
        app.typeKey(.escape, modifierFlags: [])

        app.typeKey("s", modifierFlags: [])
        point(0.0, 0.0).click(forDuration: 0.1, thenDragTo: point(0.5, 0.5))
        XCTAssertTrue(selection.waitForExistence(timeout: 2))
        let selected = selection.value as? String ?? ""
        app.typeKey("k", modifierFlags: .command)
        waitFor(app.staticTexts["imageSize"], "value == %@", selected)
    }

    @MainActor
    func testRotateAndUndo() {
        app.typeKey("r", modifierFlags: [.command, .option])
        waitFor(app.staticTexts["imageSize"], "value == %@", "200 × 320 px")
        app.typeKey("z", modifierFlags: .command)
        waitFor(app.staticTexts["imageSize"], "value == %@", "320 × 200 px")
    }

    @MainActor
    func testCanvasSizeSheet() {
        app.typeKey("e", modifierFlags: .command)
        let field = app.sheets.textFields["canvasWidth"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("400\t")
        app.sheets.buttons["Aceptar"].click()
        waitFor(app.staticTexts["imageSize"], "value == %@", "400 × 200 px")
    }

    @MainActor
    func testResizeByPercent() {
        app.typeKey("r", modifierFlags: .command)
        let field = app.sheets.textFields["resizeHorizontal"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("50\t")
        app.sheets.buttons["Aceptar"].click()
        waitFor(app.staticTexts["imageSize"], "value == %@", "160 × 100 px")
    }

    @MainActor
    func testPasteAsNewDocument() {
        app.typeKey("c", modifierFlags: .command)  // sin selección copia toda la imagen
        app.typeKey("v", modifierFlags: [.command, .shift])
        let windows = app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Untitled'"))
        waitFor(windows.element(boundBy: 1), "exists == %@", true)
    }

    @MainActor
    func testScreenshotWithGridAndSelection() {
        app.typeKey("b", modifierFlags: [])
        point(0.1, 0.5).click(forDuration: 0.1, thenDragTo: point(0.9, 0.5))
        app.typeKey("g", modifierFlags: .command)
        XCTAssertTrue(app.menuItems["Ocultar cuadrícula"].exists, "⌘G activa la cuadrícula")
        app.typeKey("+", modifierFlags: .command)
        app.typeKey("q", modifierFlags: [])
        point(0.3, 0.2).click(forDuration: 0.3, thenDragTo: point(0.6, 0.8))
        let shot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("phase5.png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: shot)
    }
}
