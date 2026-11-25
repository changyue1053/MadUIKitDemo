import XCTest

final class BookFilterUITests: XCTestCase {
    private enum Phase: String {
        case title, initial, field, keyboard, latin, overLimit = "over-limit"
        case clearFirst = "clear-first", retained, clearSecond = "clear-second"
        case cleared, keyboardAfterClear = "keyboard-after-clear", retype
    }
    private var phase = Phase.title
    private var mark: String { "MAD-XCT-ASSERT[\(phase.rawValue)]" }

    func testAlpha28SearchCounter() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        verify(app, "counter-title", "Search and field length")
        phase = .initial
        verify(app, "counter-value", "Typed: —")
        verify(app, "counter-length", "0 / 4 · Within limit")
        verify(app, "counter-events", "Clears: 0 / Searches: 0")
        XCTAssertFalse(clearButtons(app).firstMatch.exists, mark)
        phase = .field
        physicalTap(app, unique(app, app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "counter-query-input"))))
        phase = .keyboard
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 12), mark)
        XCTAssertTrue(!keyboard.frame.isEmpty && app.frame.intersects(keyboard.frame), mark)
        verify(app, "counter-focus", "Editor focused")
        phase = .latin
        for letter in ["a", "t", "l", "a", "s"] { tapKey(app, keyboard, letter) }
        verify(app, "counter-value", "Typed: atlas")
        phase = .overLimit
        verify(app, "counter-length", "5 / 4 · Over limit")
        verify(app, "counter-events", "Clears: 0 / Searches: 0")
        let over = XCUIScreen.main.screenshot().pngRepresentation

        phase = .clearFirst
        tapClear(app)
        phase = .retained
        verify(app, "counter-events", "Clears: 1 / Searches: 0")
        verify(app, "counter-value", "Typed: atlas")
        verify(app, "counter-length", "5 / 4 · Over limit")
        verify(app, "counter-focus", "Editor focused")
        XCTAssertTrue(keyboard.exists, mark)

        phase = .clearSecond
        tapClear(app)
        phase = .cleared
        verify(app, "counter-events", "Clears: 2 / Searches: 0")
        verify(app, "counter-value", "Typed: —")
        verify(app, "counter-length", "0 / 4 · Within limit")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: clearButtons(app).firstMatch)], timeout: 10), .completed, mark)
        phase = .keyboardAfterClear
        verify(app, "counter-focus", "Editor focused")
        XCTAssertTrue(keyboard.exists, mark)
        let cleared = XCUIScreen.main.screenshot().pngRepresentation
        phase = .retype
        tapKey(app, keyboard, "s")
        verify(app, "counter-value", "Typed: s")
        verify(app, "counter-length", "1 / 4 · Within limit")
        verify(app, "counter-events", "Clears: 2 / Searches: 0")
        _ = unique(app, clearButtons(app))
        retain("S2-alpha28-search-over-limit", over)
        retain("S2-alpha28-search-cleared", cleared)
    }

    private func clearButtons(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == %@", "Clear draft query"))
    }

    private func tapClear(_ app: XCUIApplication) {
        let node = unique(app, clearButtons(app))
        XCTAssertEqual(node.elementType, .button, mark)
        XCTAssertEqual(node.label, "Clear draft query", mark)
        XCTAssertTrue(node.isHittable, mark)
        physicalTap(app, node)
    }

    private func tapKey(_ app: XCUIApplication, _ keyboard: XCUIElement, _ letter: String) {
        let key = unique(app, keyboard.keys.matching(NSPredicate(format: "label ==[c] %@", letter)))
        XCTAssertTrue(key.isHittable && keyboard.frame.intersects(key.frame), mark)
        key.tap()
    }

    private func unique(_ app: XCUIApplication, _ query: XCUIElementQuery) -> XCUIElement {
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 20), mark)
        XCTAssertEqual(query.count, 1, mark)
        let node = query.element(boundBy: 0)
        let f = node.frame
        XCTAssertTrue(f.origin.x.isFinite && f.origin.y.isFinite && f.width.isFinite && f.height.isFinite, mark)
        XCTAssertTrue(!f.isEmpty && app.frame.contains(f), mark)
        return node
    }

    private func verify(_ app: XCUIApplication, _ tag: String, _ label: String) {
        let item = unique(app, app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag)))
        let check = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: item)
        XCTAssertEqual(XCTWaiter.wait(for: [check], timeout: 12), .completed, mark)
    }

    private func physicalTap(_ app: XCUIApplication, _ node: XCUIElement) {
        let frame = node.frame
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY)).tap()
    }

    private func retain(_ name: String, _ bytes: Data) {
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
