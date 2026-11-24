import XCTest

final class BookFilterUITests: XCTestCase {
    func testAlpha07ControlsCatalog() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        unique(app, "catalog", label: "Settings controls · alpha07")
        state(app, checkbox: "off / 0", toggle: "off / 0", actions: "0")
        let before = XCUIScreen.main.screenshot().pngRepresentation

        tap(app, "checkbox", label: "Include reminders")
        state(app, checkbox: "off / 1", toggle: "off / 0", actions: "0")
        tap(app, "checkbox", label: "Include reminders")
        state(app, checkbox: "on / 2", toggle: "off / 0", actions: "0")
        tap(app, "switch", label: "Sync changes")
        state(app, checkbox: "on / 2", toggle: "on / 1", actions: "0")
        tap(app, "switch", label: "Sync changes")
        state(app, checkbox: "on / 2", toggle: "off / 2", actions: "0")
        tap(app, "switch", label: "Sync changes")
        state(app, checkbox: "on / 2", toggle: "on / 3", actions: "0")
        tap(app, "add", label: "Add shortcut")
        state(app, checkbox: "on / 2", toggle: "on / 3", actions: "1")

        // Use physical taps: accessibility activation on disabled controls could
        // suppress the request before Compose receives a touch.
        disabledTap(app, "locked-checkbox")
        disabledTap(app, "locked-switch")
        disabledTap(app, "locked-add")
        // A later verified click drains the UI interaction sequence; blocked is
        // monotonic, so a transient disabled callback cannot go unnoticed.
        tap(app, "add", label: "Add shortcut")
        state(app, checkbox: "on / 2", toggle: "on / 3", actions: "2")
        retainScreen("S1-alpha07-controls-before", before)
        retainScreen("S1-alpha07-controls-after", XCUIScreen.main.screenshot().pngRepresentation)
    }

    private func state(_ app: XCUIApplication, checkbox: String, toggle: String, actions: String) {
        unique(app, "checkbox-status", label: "Checkbox: \(checkbox)")
        unique(app, "switch-status", label: "Switch: \(toggle)")
        unique(app, "actions-status", label: "Shortcuts: \(actions)")
        unique(app, "blocked-status", label: "Blocked callbacks: 0")
    }

    private func tap(_ app: XCUIApplication, _ tag: String, label: String) {
        let control = unique(app, tag, label: label)
        XCTAssertTrue(control.isHittable)
        control.tap()
    }

    private func disabledTap(_ app: XCUIApplication, _ tag: String) {
        let frame = unique(app, tag).frame
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY)).tap()
        unique(app, "blocked-status", label: "Blocked callbacks: 0")
    }

    @discardableResult
    private func unique(_ app: XCUIApplication, _ tag: String, label: String? = nil) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(query.count, 1)
        let element = query.element(boundBy: 0)
        XCTAssertEqual(element.identifier, tag)
        if let label = label {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed)
        }
        let frame = element.frame
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite)
        XCTAssertTrue(!frame.isEmpty && app.frame.contains(frame))
        return element
    }

    private func retainScreen(_ name: String, _ bytes: Data) {
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
