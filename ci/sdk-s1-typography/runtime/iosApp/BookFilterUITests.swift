import XCTest

final class BookFilterUITests: XCTestCase {
    func testAlpha10ActionGallery() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        unique(app, "actions-title", label: "Action buttons · alpha10")
        state(app, phase: "Ready", starts: 0, completions: 0)
        let ready = XCUIScreen.main.screenshot().pngRepresentation
        // Complete is disabled before starting. The danger button is always disabled.
        physicalTap(app, "complete-action", label: "Complete operation")
        physicalTap(app, "disabled-action", label: "Delete operation")
        liveTap(app, "start-action", label: "Start operation")
        state(app, phase: "In progress", starts: 1, completions: 0)
        physicalTap(app, "start-action", label: "Start operation")
        physicalTap(app, "start-action", label: "Start operation")
        physicalTap(app, "disabled-action", label: "Delete operation")
        state(app, phase: "In progress", starts: 1, completions: 0)
        let loading = XCUIScreen.main.screenshot().pngRepresentation
        // Resume with positive controls. Monotonic counters rule out late or
        // transient callbacks from earlier disabled/while-loading taps.
        liveTap(app, "complete-action", label: "Complete operation")
        state(app, phase: "Ready", starts: 1, completions: 1)
        liveTap(app, "start-action", label: "Start operation")
        state(app, phase: "In progress", starts: 2, completions: 1)
        liveTap(app, "complete-action", label: "Complete operation")
        state(app, phase: "Ready", starts: 2, completions: 2)
        retainScreen("S1-alpha10-actions-ready", ready)
        retainScreen("S1-alpha10-actions-loading", loading)
    }

    private func state(_ app: XCUIApplication, phase: String, starts: Int, completions: Int) {
        unique(app, "actions-phase", label: "State: \(phase)")
        unique(app, "actions-counters", label: "Starts: \(starts) / Completions: \(completions) / Disabled: 0")
    }

    private func physicalTap(_ app: XCUIApplication, _ tag: String, label: String) {
        let frame = unique(app, tag, label: label).frame
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY)).tap()
    }

    private func liveTap(_ app: XCUIApplication, _ tag: String, label: String) {
        let node = unique(app, tag, label: label)
        XCTAssertTrue(node.isHittable)
        node.tap()
    }

    @discardableResult
    private func unique(_ app: XCUIApplication, _ tag: String, label: String) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(query.count, 1)
        let node = query.element(boundBy: 0)
        XCTAssertEqual(node.identifier, tag)
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: node)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed)
        let frame = node.frame
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite)
        XCTAssertTrue(!frame.isEmpty && app.frame.contains(frame))
        return node
    }

    private func retainScreen(_ name: String, _ bytes: Data) {
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
