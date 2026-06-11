import XCTest

final class HomeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndShowsHomeTab() {
        let app = XCUIApplication()
        app.launch()

        // The Home screen sets its navigation title to "Home".
        let homeTitle = app.navigationBars["Home"]
        XCTAssertTrue(
            homeTitle.waitForExistence(timeout: 5),
            "Expected the Home navigation bar to appear on launch."
        )
    }

    @MainActor
    func testSettingsTabIsReachable() {
        let app = XCUIApplication()
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }
}
