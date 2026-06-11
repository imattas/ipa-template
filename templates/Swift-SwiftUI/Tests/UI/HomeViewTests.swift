//
//  HomeViewTests.swift
//  Swift-SwiftUI
//
//  Basic UI launch test. Extend with accessibility-identifier-driven
//  assertions as the UI grows.
//

import XCTest

final class HomeViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testHomeNavigationTitleAppears() throws {
        let app = XCUIApplication()
        app.launch()

        // The Home screen sets navigationTitle("Home").
        let title = app.navigationBars["Home"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 5),
            "Expected the Home navigation bar to appear on launch."
        )
    }
}
