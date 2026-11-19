import XCTest

final class BookFilterUITests: XCTestCase {
    func testGeneratedBinding() {
        continueAfterFailure = false
        let enabled = EXPECT_ENABLED
        let app = XCUIApplication(bundleIdentifier: "dev.mad.adoption.ios")
        app.launch()
        XCTAssertTrue(app.staticTexts["Selection requests: 0"].waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["Selected: false"].exists)
        let label = app.staticTexts["Books"].firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 15))
        XCTAssertTrue(label.isHittable)
        retainScreen("Typed-before")
        // One physical tap, including for the disabled build. No accessibility action shortcut.
        label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if enabled {
            XCTAssertTrue(app.staticTexts["Selection requests: 1"].waitForExistence(timeout: 15))
            XCTAssertTrue(app.staticTexts["Selected: true"].exists)
        } else {
            XCTAssertFalse(app.staticTexts["Selection requests: 1"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.staticTexts["Selection requests: 0"].exists)
            XCTAssertTrue(app.staticTexts["Selected: false"].exists)
        }
        XCTAssertFalse(app.staticTexts["Selection requests: 2"].exists)
        retainScreen("Typed-after")
    }

    private func retainScreen(_ name: String) {
        let a = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation,
                              uniformTypeIdentifier: "public.png")
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
