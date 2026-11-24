import XCTest

final class BookFilterUITests: XCTestCase {
    func testIndependentConsumer() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        let scoped = unique(app, "title-scoped", label: "Books")
        let outside = unique(app, "title-outside", label: "Books")
        XCTAssertFalse(scoped.frame.intersects(outside.frame))
        let button = unique(app, "select-book", label: "Select book")
        XCTAssertTrue(button.isHittable)
        unique(app, "selection-count", label: "Selections: 0")
        retainScreen("S1-typography-before")
        button.tap()
        unique(app, "selection-count", label: "Selections: 1")
        retainScreen("S1-typography-after")
    }

    @discardableResult
    private func unique(_ app: XCUIApplication, _ tag: String, label: String) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(query.count, 1)
        let element = query.element(boundBy: 0)
        XCTAssertEqual(element.identifier, tag)
        // Content updates are asynchronous even after a real tap.
        let expectedLabel = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectedLabel], timeout: 15), .completed)
        let frame = element.frame
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite)
        XCTAssertTrue(!frame.isEmpty && app.frame.contains(frame))
        return element
    }

    private func retainScreen(_ name: String) {
        let a = XCTAttachment(data: XCUIScreen.main.screenshot().pngRepresentation, uniformTypeIdentifier: "public.png")
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
