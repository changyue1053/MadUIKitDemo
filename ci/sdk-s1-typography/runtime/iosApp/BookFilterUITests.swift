import XCTest

final class BookFilterUITests: XCTestCase {
    func testAlpha12TrialForm() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        unique(app, "form-title", label: "Sample form · alpha12")
        unique(app, "form-badge", label: "Form is a draft")
        unique(app, "form-focus", label: "Focus: None")
        unique(app, "form-values", label: "Values: ab,")
        fieldMessage(app, "form-name", expected: "Use at least 4 characters", absent: "Use a public name")
        let invalid = XCUIScreen.main.screenshot().pngRepresentation
        physicalTap(app, "form-submit")
        unique(app, "form-count", label: "Submissions: 0 / None")

        physicalTap(app, "form-name")
        unique(app, "form-focus", label: "Focus: Name")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 12))
        XCTAssertFalse(keyboard.frame.isEmpty)
        // XCTest injection; does not prove real OS composition or keyboard action dispatch.
        app.typeText("cd")
        unique(app, "form-values", label: "Values: abcd,")
        fieldMessage(app, "form-name", expected: "Use a public name", absent: "Use at least 4 characters")
        physicalTap(app, "form-note")
        unique(app, "form-focus", label: "Focus: Note")
        XCTAssertTrue(keyboard.exists)
        app.typeText("ok")
        unique(app, "form-values", label: "Values: abcd,ok")
        let editing = XCUIScreen.main.screenshot().pngRepresentation
        physicalTap(app, "form-submit")
        unique(app, "form-focus", label: "Focus: None")
        unique(app, "form-count", label: "Submissions: 1 / abcd,ok")
        unique(app, "form-badge", label: "Form is saved")
        waitForKeyboardToClose(keyboard)
        physicalTap(app, "form-submit")
        unique(app, "form-count", label: "Submissions: 1 / abcd,ok")
        physicalTap(app, "form-readonly")
        unique(app, "form-focus", label: "Focus: Read-only")
        waitForKeyboardToClose(keyboard)
        physicalTap(app, "form-disabled")
        unique(app, "form-focus", label: "Focus: Read-only")
        waitForKeyboardToClose(keyboard)
        unique(app, "form-locked", label: "Locked: ABC,XYZ / Edits: 0")
        unique(app, "form-count", label: "Submissions: 1 / abcd,ok")
        retainScreen("S2-alpha12-form-invalid", invalid)
        retainScreen("S2-alpha12-form-editing", editing)
        retainScreen("S2-alpha12-form-saved", XCUIScreen.main.screenshot().pngRepresentation)
    }

    private func waitForKeyboardToClose(_ keyboard: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: keyboard)], timeout: 10), .completed)
    }

    private func fieldMessage(_ app: XCUIApplication, _ tag: String, expected: String, absent: String) {
        let field = unique(app, tag)
        let message = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", expected))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            field.label.contains(expected) || message.firstMatch.exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 12), .completed)
        XCTAssertFalse(field.label.contains(absent))
        XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", absent)).firstMatch.exists)
    }

    private func physicalTap(_ app: XCUIApplication, _ tag: String) {
        let frame = unique(app, tag).frame
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY)).tap()
    }

    @discardableResult
    private func unique(_ app: XCUIApplication, _ tag: String, label: String? = nil) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(query.count, 1)
        let node = query.element(boundBy: 0)
        if let label = label {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: node)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 15), .completed)
        }
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
