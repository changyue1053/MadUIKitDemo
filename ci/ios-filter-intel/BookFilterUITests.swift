import XCTest

final class BookFilterUITests: XCTestCase {
    func testSelectionAndDisabledTap() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.maduikit.demo")
        app.launch()
        XCTAssertTrue(app.staticTexts["Selected filter: All books"].waitForExistence(timeout: 35))
        XCTAssertTrue(app.staticTexts["Selection requests: 0"].exists)

        let byTag = app.descendants(matching: .any).matching(identifier: "books-favorites").firstMatch
        let favorites = byTag.exists && byTag.isHittable ? byTag : app.staticTexts["Favorites"].firstMatch
        XCTAssertTrue(favorites.waitForExistence(timeout: 15))
        XCTAssertTrue(favorites.isHittable)
        retainScreen("MadUIKit-iOS-Books-before")
        favorites.tap()
        XCTAssertTrue(app.staticTexts["Selected filter: Favorites"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Selection requests: 1"].exists)
        XCTAssertFalse(app.staticTexts["Selected filter: All books"].exists)
        retainScreen("MadUIKit-iOS-Books-after")
        let disabledByTag = app.descendants(matching: .any).matching(identifier: "books-unavailable").firstMatch
        let unavailable = disabledByTag.exists ? disabledByTag : app.staticTexts["Unavailable"].firstMatch
        XCTAssertTrue(unavailable.waitForExistence(timeout: 15))
        XCTAssertFalse(unavailable.isEnabled, "Disabled filter must expose disabled semantics")
        // Physical center tap deliberately bypasses XCTest's enabled-element guard.
        unavailable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let unexpected = app.staticTexts["Selected filter: Unavailable"]
        XCTAssertFalse(unexpected.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Selected filter: Favorites"].exists)
        XCTAssertTrue(app.staticTexts["Selection requests: 1"].exists)
        retainScreen("MadUIKit-iOS-Books-disabled")
    }

    private func retainScreen(_ name: String) {
        let attachment = XCTAttachment(
            data: XCUIScreen.main.screenshot().pngRepresentation,
            uniformTypeIdentifier: "public.png"
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
