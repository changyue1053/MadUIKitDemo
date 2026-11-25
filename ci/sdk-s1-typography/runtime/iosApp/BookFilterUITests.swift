import XCTest

final class BookFilterUITests: XCTestCase {
    private enum Phase: String {
        case title, progress, modal, background, restored
        case cancelSelector = "cancel-selector"
        case cancelBounds = "cancel-bounds"
        case cancelHit = "cancel-hit"
        case cancelClosed = "cancel-closed"
        case cancelEvents = "cancel-events"
        case cancelRunning = "cancel-running"
        case cancelRoute = "cancel-route"
        case cancelProgress = "cancel-progress"
        case confirmOpen = "confirm-open"
        case confirmSelector = "confirm-selector"
        case confirmBounds = "confirm-bounds"
        case confirmHit = "confirm-hit"
        case confirmClosed = "confirm-closed"
        case confirmEvents = "confirm-events"
        case confirmPaused = "confirm-paused"
        case confirmRoute = "confirm-route"
        case confirmProgress = "confirm-progress"
        case navInitial = "nav-initial"
        case navFirstSelector = "nav-first-selector"
        case navFirstBounds = "nav-first-bounds"
        case navFirstHit = "nav-first-hit"
        case navHeld = "nav-held"
        case navSecondSelector = "nav-second-selector"
        case navSecondBounds = "nav-second-bounds"
        case navSecondHit = "nav-second-hit"
        case navAccepted = "nav-accepted"
    }
    private var phase = Phase.title
    private var mark: String { "MAD-XCT-ASSERT[\(phase.rawValue)]" }

    func testAlpha19AtlasTransfer() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        tagged(app, "transfer-title", label: "Transfer center")
        tagged(app, "transfer-progress-text", label: "Progress: Estimating")
        phase = .navInitial
        tagged(app, "transfer-route", label: "Selected: Overview / Requests: 0")
        tapTransfers(app, second: false)
        phase = .navHeld
        tagged(app, "transfer-route", label: "Selected: Overview / Requests: 1")
        tapTransfers(app, second: true)
        phase = .navAccepted
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
        tapModalAction(app, confirm: false)
        phase = .cancelClosed
        waitClosed(app)
        phase = .cancelEvents
        tagged(app, "transfer-events", label: "Details: 1 / Cancel: 1 / Confirm: 0 / Dismiss: 0")
        phase = .cancelRunning
        tagged(app, "transfer-status", label: "Status: Running")
        phase = .cancelRoute
        tagged(app, "transfer-route", label: "Selected: Transfers / Requests: 2")
        phase = .cancelProgress
        tagged(app, "transfer-progress-text", label: "Progress: 42%")

        phase = .confirmOpen
        tap(app, "transfer-pause")
        _ = exact(app, "Pause this transfer?")
        tapModalAction(app, confirm: true)
        phase = .confirmClosed
        waitClosed(app)
        phase = .confirmEvents
        tagged(app, "transfer-events", label: "Details: 1 / Cancel: 1 / Confirm: 1 / Dismiss: 0")
        phase = .confirmPaused
        tagged(app, "transfer-status", label: "Status: Paused")
        phase = .confirmRoute
        tagged(app, "transfer-route", label: "Selected: Transfers / Requests: 2")
        phase = .confirmProgress
        tagged(app, "transfer-progress-text", label: "Progress: 42%")
        phase = .restored
        tap(app, "transfer-details")
        tagged(app, "transfer-events", label: "Details: 2 / Cancel: 1 / Confirm: 1 / Dismiss: 0")
        retain("S3-alpha19-transfer-progress", progress)
        retain("S3-alpha19-transfer-confirm", confirmation)
    }

    private func tapTransfers(_ app: XCUIApplication, second: Bool) {
        phase = second ? .navSecondSelector : .navFirstSelector
        let fixedLabel = NSPredicate(format: "label == %@", "Transfers")
        let buttons = app.buttons.matching(fixedLabel)
        // CMP 1.9.3 maps OnClick to the iOS Button trait; it has no Role.Tab
        // specialization. A static-text sibling must not satisfy this gate.
        _ = buttons.firstMatch.waitForExistence(timeout: 25)
        let allExact = app.descendants(matching: .any).matching(fixedLabel).count
        let buttonExact = buttons.count
        func bucket(_ count: Int) -> String { count == 0 ? "zero" : count == 1 ? "one" : "multiple" }
        let shot = second ? "second" : "first"
        let census = "MAD-XCT-AX[\(shot):\(bucket(allExact)):\(bucket(buttonExact))]"
        XCTAssertTrue(allExact >= buttonExact, census)
        XCTAssertTrue(buttonExact == 1, census)
        let transfers = buttons
        let node = transfers.element(boundBy: 0)
        XCTAssertEqual(node.label, "Transfers", mark)
        XCTAssertEqual(node.elementType, .button, mark)
        phase = second ? .navSecondBounds : .navFirstBounds
        let f = node.frame
        XCTAssertTrue(f.origin.x.isFinite && f.origin.y.isFinite && f.width.isFinite && f.height.isFinite, mark)
        XCTAssertTrue(!f.isEmpty && app.frame.contains(f), mark)
        phase = second ? .navSecondHit : .navFirstHit
        XCTAssertTrue(node.isHittable, mark)
        node.tap()
    }

    private func tapModalAction(_ app: XCUIApplication, confirm: Bool) {
        phase = confirm ? .confirmSelector : .cancelSelector
        let expected = confirm ? "Pause now" : "Keep transferring"
        let predicate = NSPredicate(format: "label == %@", expected)
        let buttons = app.buttons.matching(predicate)
        _ = buttons.firstMatch.waitForExistence(timeout: 25)
        let allCount = app.descendants(matching: .any).matching(predicate).count
        let buttonCount = buttons.count
        func bucket(_ count: Int) -> String { count == 0 ? "zero" : count == 1 ? "one" : "multiple" }
        let action = confirm ? "confirm" : "cancel"
        let census = "MAD-XCT-MODAL[\(action):\(bucket(allCount)):\(bucket(buttonCount))]"
        XCTAssertTrue(allCount >= buttonCount, census)
        XCTAssertTrue(buttonCount == 1, census)
        let node = buttons.element(boundBy: 0)
        XCTAssertEqual(node.label, expected, mark)
        XCTAssertEqual(node.elementType, .button, mark)
        phase = confirm ? .confirmBounds : .cancelBounds
        let f = node.frame
        XCTAssertTrue(f.origin.x.isFinite && f.origin.y.isFinite && f.width.isFinite && f.height.isFinite, mark)
        XCTAssertTrue(!f.isEmpty && app.frame.contains(f), mark)
        phase = confirm ? .confirmHit : .cancelHit
        XCTAssertTrue(node.isHittable, mark)
        node.tap()
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
