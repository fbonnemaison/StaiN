import XCTest

final class EditorUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(es)",
            "-canvasWidth", "320",
            "-canvasHeight", "200",
            "-paletteColors", "()",
            "-recentColors", "()",
        ]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
    }

    @MainActor
    override func tearDown() async throws {
        app.terminate()
    }

    @MainActor
    private var canvas: XCUIElement { app.images["canvas"] }

    @MainActor
    func testNewDocumentShowsCanvasWithDefaultSize() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["320 × 200 px"].exists)
    }

    @MainActor
    func testDrawingRegistersUndo() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let undo = app.menuBars.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Deshacer")).firstMatch
        let redo = app.menuBars.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Rehacer")).firstMatch
        XCTAssertFalse(undo.isEnabled)

        // En macOS, el arrastre de XCUITest es `click(forDuration:thenDragTo:)` (no `press`).
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3))
            .click(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)))
        XCTAssertTrue(undo.isEnabled)

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(redo.isEnabled, "Tras deshacer debería poder rehacerse el trazo")
    }

    @MainActor
    func testZoomCommands() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let zoom = app.popUpButtons["zoomLevel"]
        XCTAssertTrue((zoom.value as? String ?? "").contains("100"))
        app.typeKey("+", modifierFlags: .command)
        XCTAssertTrue((zoom.value as? String ?? "").contains("200"), "Zoom tras ⌘+: \((zoom.value as? String ?? ""))")
        app.typeKey("0", modifierFlags: .command)
        XCTAssertTrue((zoom.value as? String ?? "").contains("100"))
    }

    @MainActor
    private func value(of label: String) -> String {
        app.buttons[label].value as? String ?? ""
    }

    @MainActor
    func testPaletteSetsColorsAndXSwaps() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(value(of: "Color primario"), "#000000")
        XCTAssertEqual(value(of: "Color secundario"), "#FFFFFF")

        app.buttons["Paleta 17"].click()  // rojo
        XCTAssertEqual(value(of: "Color primario"), "#FF0000")
        app.buttons["Paleta 19"].rightClick()  // verde lima
        XCTAssertEqual(value(of: "Color secundario"), "#00FF00")

        app.typeKey("x", modifierFlags: [])
        XCTAssertEqual(value(of: "Color primario"), "#00FF00")
        XCTAssertEqual(value(of: "Color secundario"), "#FF0000")
    }

    @MainActor
    func testToolShortcuts() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        for (key, tool) in [("b", "brush"), ("e", "eraser"), ("f", "fill"), ("l", "line"), ("p", "pencil")] {
            app.typeKey(key, modifierFlags: [])
            XCTAssertTrue(app.buttons["tool.\(tool)"].isSelected, "La tecla \(key) debería elegir \(tool)")
        }
    }

    @MainActor
    func testEyedropperPicksColorAndReturnsToPreviousTool() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let point = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        app.buttons["Paleta 21"].click()  // azul
        app.typeKey("b", modifierFlags: [])
        point.click()
        app.buttons["Paleta 1"].click()  // negro
        XCTAssertEqual(value(of: "Color primario"), "#000000")

        app.typeKey("i", modifierFlags: [])
        point.click()
        XCTAssertEqual(value(of: "Color primario"), "#0000FF")
        XCTAssertTrue(app.buttons["tool.brush"].isSelected, "El cuentagotas vuelve a la herramienta anterior")

        let shot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("phase3.png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: shot)
    }
}
