import XCTest

final class BookFilterUITests: XCTestCase {
    private enum Phase: String {
        case title, navigation, progress, modal, background, cancel, confirm, restored
    }
    private var phase = Phase.title
    private var mark: String { "MAD-XCT-ASSERT[\(phase.rawValue)]" }

    func testAlpha19AtlasTransfer() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        tagged(app, "transfer-title", label: "Transfer center")
        tagged(app, "transfer-progress-text", label: "Progress: Estimating")
        phase = .navigation
        tagged(app, "transfer-route", label: "Selected: Overview / Requests: 0")
        let target = exact(app, "Transfers")
        XCTAssertTrue(target.isHittable, mark)
        target.tap()
        tagged(app, "transfer-route", label: "Selected: Overview / Requests: 1")
        exact(app, "Transfers").tap()
        tagged(app, "transfer-route", label: "Selected: Transfers / Requests: 2")
        phase = .progress
        tap(app, "transfer-resolve")
        tagged(app, "transfer-progress-text", label: "Progress: 42%")

        let detail = tagged(app, "transfer-details", label: "Workspace details")
        XCTAssertTrue(detail.isHittable, mark)
        let backgroundFrame = detail.frame
        detail.tap()
        tagged(app, "transfer-events", label: "Details: 1 / Cancel: 0 / Confirm: 0 / Dismiss: 0")
        let progress = XCUIScreen.main.screenshot().pngRepresentation
        phase = .modal
        tap(app, "transfer-pause")
        let modalTitle = exact(app, "Pause this transfer?")
        XCTAssertLessThan(backgroundFrame.maxY, modalTitle.frame.minY, mark)
        let confirmation = XCUIScreen.main.screenshot().pngRepresentation
        // Touch the preflight background coordinate, not an accessibility
        // activation that could be suppressed before it visits the modal.
        phase = .background
        let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: backgroundFrame.midX - app.frame.minX,
                                   dy: backgroundFrame.midY - app.frame.minY)).tap()
        _ = exact(app, "Pause this transfer?")
        phase = .cancel
        exact(app, "Keep transferring").tap()
        waitClosed(app)
        tagged(app, "transfer-events", label: "Details: 1 / Cancel: 1 / Confirm: 0 / Dismiss: 0")
        tagged(app, "transfer-status", label: "Status: Running")
        tagged(app, "transfer-route", label: "Selected: Transfers / Requests: 2")
        tagged(app, "transfer-progress-text", label: "Progress: 42%")

        phase = .confirm
        tap(app, "transfer-pause")
        _ = exact(app, "Pause this transfer?")
        exact(app, "Pause now").tap()
        waitClosed(app)
        tagged(app, "transfer-events", label: "Details: 1 / Cancel: 1 / Confirm: 1 / Dismiss: 0")
        tagged(app, "transfer-status", label: "Status: Paused")
        tagged(app, "transfer-route", label: "Selected: Transfers / Requests: 2")
        tagged(app, "transfer-progress-text", label: "Progress: 42%")
        phase = .restored
        tap(app, "transfer-details")
        tagged(app, "transfer-events", label: "Details: 2 / Cancel: 1 / Confirm: 1 / Dismiss: 0")
        retain("S3-alpha19-transfer-progress", progress)
        retain("S3-alpha19-transfer-confirm", confirmation)
    }

    private func labels(_ app: XCUIApplication, _ label: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
    }

    private func waitClosed(_ app: XCUIApplication) {
        let title = labels(app, "Pause this transfer?").firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: title)], timeout: 10), .completed, mark)
    }

    private func exact(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        unique(app, labels(app, label))
    }

    private func unique(_ app: XCUIApplication, _ query: XCUIElementQuery) -> XCUIElement {
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 25), mark)
        XCTAssertEqual(query.count, 1, mark)
        let node = query.element(boundBy: 0)
        let frame = node.frame
        XCTAssertTrue(frame.origin.x.isFinite && frame.origin.y.isFinite && frame.width.isFinite && frame.height.isFinite, mark)
        XCTAssertTrue(!frame.isEmpty && app.frame.contains(frame), mark)
        return node
    }

    @discardableResult
    private func tagged(_ app: XCUIApplication, _ tag: String, label: String? = nil) -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
        let node = unique(app, matches)
        if let label = label {
            let check = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: node)
            XCTAssertEqual(XCTWaiter.wait(for: [check], timeout: 15), .completed, mark)
        }
        return node
    }

    private func tap(_ app: XCUIApplication, _ tag: String) {
        let node = tagged(app, tag)
        XCTAssertTrue(node.isHittable, mark)
        node.tap()
    }

    private func retain(_ name: String, _ bytes: Data) {
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
