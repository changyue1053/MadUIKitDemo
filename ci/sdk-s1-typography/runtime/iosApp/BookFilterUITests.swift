import XCTest

final class BookFilterUITests: XCTestCase {
    func testAlpha16AtlasDirectory() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        assertLabel(app, "atlas-title", "Team directory")
        assertLabel(app, "atlas-heading", "Search results")
        assertLabel(app, "atlas-matches", "3 matches")
        assertLabel(app, "atlas-row-1", "Mira Chen", contains: true)
        assertLabel(app, "atlas-row-2", "Jonah Reed", contains: true)
        assertLabel(app, "atlas-row-3", "Sofia Park", contains: true)
        assertLabel(app, "atlas-note-heading", "Note for Mira")
        tap(app, "atlas-row-2")
        assertLabel(app, "atlas-note-heading", "Note for Jonah")
        assertLabel(app, "atlas-count", "Searches: 0")
        let results = XCUIScreen.main.screenshot().pngRepresentation

        physicalTap(app, "atlas-search")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 12))
        XCTAssertFalse(keyboard.frame.isEmpty)
        // XCUITest ASCII injection. Do not infer native composition or Search-key dispatch.
        app.typeText("cartographer")
        assertLabel(app, "atlas-query", "Query: cartographer")
        assertLabel(app, "atlas-count", "Searches: 0")
        assertLabel(app, "atlas-heading", "Search results")
        // An explicit host button tests the search transition independently of IME actions.
        physicalTap(app, "atlas-submit")
        assertLabel(app, "atlas-heading", "No results")
        assertLabel(app, "atlas-empty", "Try a broader search")
        assertLabel(app, "atlas-count", "Searches: 1")
        assertLabel(app, "atlas-matches", "0 matches")
        assertLabel(app, "atlas-note-heading", "Note for Jonah")
        for id in 1...3 {
            XCTAssertFalse(query(app, "atlas-row-\(id)").firstMatch.exists)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: keyboard)], timeout: 10), .completed)
        retain("S2-alpha16-atlas-results", results)
        retain("S2-alpha16-atlas-empty", XCUIScreen.main.screenshot().pngRepresentation)
    }

    private func query(_ app: XCUIApplication, _ tag: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
    }

    private func unique(_ app: XCUIApplication, _ tag: String) -> XCUIElement {
        let matches = query(app, tag)
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 25))
        XCTAssertEqual(matches.count, 1)
        let node = matches.element(boundBy: 0)
        let frame = node.frame
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite)
        XCTAssertTrue(!frame.isEmpty && app.frame.contains(frame))
        return node
    }

    private func assertLabel(_ app: XCUIApplication, _ tag: String, _ value: String, contains: Bool = false) {
        let node = unique(app, tag)
        let predicate = contains ? NSPredicate(format: "label CONTAINS %@", value) :
            NSPredicate(format: "label == %@", value)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: node)], timeout: 15), .completed)
    }

    private func tap(_ app: XCUIApplication, _ tag: String) {
        let node = unique(app, tag)
        XCTAssertTrue(node.isHittable)
        node.tap()
    }

    private func physicalTap(_ app: XCUIApplication, _ tag: String) {
        let frame = unique(app, tag).frame
        let anchor = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        anchor.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY)).tap()
    }

    private func retain(_ name: String, _ bytes: Data) {
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
