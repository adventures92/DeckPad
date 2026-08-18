//
//  DeckPadUITests.swift
//  DeckPadUITests
//

import XCTest

final class DeckPadUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMainWindow() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["DeckPad"].waitForExistence(timeout: 10))
    }
}
