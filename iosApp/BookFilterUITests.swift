import XCTest

final class BookFilterUITests: XCTestCase {
    func testFavoritesViaNativeTap() {
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
