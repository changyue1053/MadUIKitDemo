import XCTest
final class BookFilterUITests:XCTestCase {
 func testIndependentConsumer() {
  continueAfterFailure=false
  let app=XCUIApplication(bundleIdentifier:"dev.mad.adoption.ios")
  app.launch()
  XCTAssertTrue(app.staticTexts["Independent iOS SDK consumer"].waitForExistence(timeout:40))
  XCTAssertTrue(app.staticTexts["All books"].exists)
  XCTAssertTrue(app.staticTexts["Favorites"].exists)
  let a=XCTAttachment(data:XCUIScreen.main.screenshot().pngRepresentation,uniformTypeIdentifier:"public.png")
  a.name="Independent-iOS-Arm64Simulator-Books";a.lifetime = .keepAlways;add(a)
 }
}
