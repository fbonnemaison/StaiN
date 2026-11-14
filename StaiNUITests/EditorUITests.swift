import XCTest

final class EditorUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES",
            "-canvasWidth", "320",
            "-canvasHeight", "200",
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
        let undo = app.menuItems["undo:"]
        let redo = app.menuItems["redo:"]
        XCTAssertFalse(undo.isEnabled)

        // Nota: en macOS 27 el arrastre sintético de XCUITest no llega a la vista; se dibuja con clics.
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).click()
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)).click()
        XCTAssertTrue(undo.isEnabled)

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(redo.isEnabled, "Tras deshacer debería poder rehacerse el trazo")
    }

    @MainActor
    func testZoomCommands() {
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let zoom = app.menuButtons["zoomLevel"]
        XCTAssertTrue(zoom.title.contains("100"))
        app.typeKey("+", modifierFlags: .command)
        XCTAssertTrue(zoom.title.contains("200"), "Zoom tras ⌘+: \(zoom.title)")
        app.typeKey("0", modifierFlags: .command)
        XCTAssertTrue(zoom.title.contains("100"))
    }
}
