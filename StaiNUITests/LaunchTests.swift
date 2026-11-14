import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testAppLaunchesWithCanvas() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
    }
}
