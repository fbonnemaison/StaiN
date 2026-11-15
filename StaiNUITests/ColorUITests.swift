import XCTest

/// Paletas preconfiguradas, colores personalizados y valores RGB/HEX.
final class ColorUITests: XCTestCase {
    private var app: XCUIApplication!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-AppleLanguages", "(es)", "-paletteSource", "preset.classic",
            "-paletteColors", "()", "-customColors", "()", "-canvasWidth", "320",
            "-canvasHeight", "200",
        ]
        app.launch()
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.images["canvas"].waitForExistence(timeout: 5))
    }

    @MainActor
    override func tearDown() async throws {
        app.terminate()
    }

    @MainActor
    private func value(of label: String) -> String {
        app.buttons[label].firstMatch.value as? String ?? ""
    }

    @MainActor
    private func waitForValue(_ label: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.buttons[label].firstMatch)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 3), .completed, "\(label): \(value(of: label))", file: file,
            line: line)
    }

    @MainActor
    private func screenshot(_ name: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png")
        try? app.windows.firstMatch.screenshot().pngRepresentation.write(to: url)
    }

    @MainActor
    func testPalettePresetsSwitch() {
        XCTAssertEqual(value(of: "Paleta 17"), "#FF0000", "Empieza con la clásica")
        let picker = app.menuButtons["palettePicker"]
        picker.click()
        app.menuItems["Neón"].click()
        waitForValue("Paleta 2", "#FF00FF")
        XCTAssertTrue(app.buttons["Paleta 28"].exists)

        picker.click()
        app.menuItems["Verde 4 tonos"].click()
        waitForValue("Paleta 1", "#0E2A12")
        XCTAssertFalse(app.buttons["Paleta 5"].exists, "Esta paleta solo tiene 4 colores")

        picker.click()
        app.menuItems["Clásica"].click()
        waitForValue("Paleta 17", "#FF0000")
    }

    @MainActor
    func testCustomColorSlots() {
        XCTAssertEqual(value(of: "Personalizado 1"), "Vacío")
        app.buttons["Personalizado 1"].click()  // guarda el primario (negro)
        waitForValue("Personalizado 1", "#000000")

        app.buttons["Paleta 17"].click()  // primario rojo
        app.buttons["Personalizado 2"].click()
        waitForValue("Personalizado 2", "#FF0000")

        app.buttons["Paleta 1"].click()  // primario negro
        app.buttons["Personalizado 2"].click()  // casilla llena: la usa como primario
        waitForValue("Color primario", "#FF0000")

        app.buttons["Personalizado 2"].rightClick()
        app.menuItems["Vaciar"].click()
        waitForValue("Personalizado 2", "Vacío")
        screenshot("colors-custom")
    }

    @MainActor
    func testHexAndRGBFields() {
        app.buttons["Color primario"].click()
        let hex = app.popovers.textFields["hexField"]
        XCTAssertTrue(hex.waitForExistence(timeout: 3))
        XCTAssertEqual(hex.value as? String, "#000000")

        hex.click()
        hex.typeKey("a", modifierFlags: .command)
        hex.typeText("#00FF00\r")
        waitForValue("Color primario", "#00FF00")

        let red = app.popovers.textFields["redField"]
        red.click()
        red.typeKey("a", modifierFlags: .command)
        red.typeText("255\r")
        waitForValue("Color primario", "#FFFF00")
        XCTAssertEqual(hex.value as? String, "#FFFF00", "El HEX se actualiza con el RGB")

        hex.click()
        hex.typeKey("a", modifierFlags: .command)
        hex.typeText("#12345")
        XCTAssertTrue(app.popovers.staticTexts["Escribe 6 u 8 dígitos hexadecimales, p. ej. #FF8800"].exists)
        XCTAssertEqual(value(of: "Color primario"), "#FFFF00", "Un HEX incompleto no cambia el color")
        screenshot("colors-hex")
    }
}
