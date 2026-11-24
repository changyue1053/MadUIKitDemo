import Foundation
import CoreGraphics
import ImageIO
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

final class TypographyMetricsUITests: XCTestCase {
    private struct MetricFailure: Error {}
    private struct Mask: Equatable {
        let w: Int
        let h: Int
        let ink: Set<Int>
        func matches(_ other: Mask) -> Bool {
            // Fail closed on different glyph extents; allow minimal antialias boundary noise.
            guard w == other.w, h == other.h else { return false }
            return Double(ink.symmetricDifference(other.ink).count) /
                Double(max(1, ink.union(other.ink).count)) <= 0.03
        }
    }

    func testSyntheticNativeMetrics() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launchArguments += ["--s1-metrics"]
        app.launch()

        func tagged(_ id: String) throws -> XCUIElement {
            let q = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id))
            XCTAssertTrue(q.firstMatch.waitForExistence(timeout: 30))
            XCTAssertEqual(q.count, 1)
            guard q.count == 1 else { throw MetricFailure() }
            return q.element(boundBy: 0)
        }

        let geometry = try tagged("metric-geometry")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "density="), object: geometry)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        let fields = geometry.label.split(separator: " ")
        guard fields.count == 3, fields[0].hasPrefix("density="),
              fields[1].hasPrefix("tokenPx="), fields[2].hasPrefix("gaps="),
              let density = Double(fields[0].dropFirst(8)),
              let token = Int(fields[1].dropFirst(8)) else { throw MetricFailure() }
        let gaps = fields[2].dropFirst(5).split(separator: ",").compactMap { Int($0) }
        XCTAssertEqual(density, 3, accuracy: 0.01)
        XCTAssertEqual(token, 24)
        XCTAssertEqual(gaps, [token, 21, 8])
        XCTAssertFalse(gaps.dropFirst().contains(token), "7dp and raw 8px controls cannot pass the 8dp assertion")

        let ids = ["metric-scoped", "metric-raw-scoped", "metric-outside",
                   "metric-raw-outside", "metric-no-provider", "metric-raw-repeat"]
        var rects: [CGRect] = []
        for id in ids {
            let node = try tagged(id)
            XCTAssertEqual(node.label, "Books")
            XCTAssertTrue(!node.frame.isEmpty && app.frame.contains(node.frame))
            rects.append(node.frame)
        }
        for i in 1..<rects.count {
            XCTAssertFalse(rects[i-1].intersects(rects[i]))
        }
        let photo = XCUIScreen.main.screenshot().pngRepresentation
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(photo as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        XCTAssertEqual(image.width, 1206)
        XCTAssertEqual(image.height, 2622)
        XCTAssertEqual(app.frame.origin.x, 0, accuracy: 0.01)
        XCTAssertEqual(app.frame.origin.y, 0, accuracy: 0.01)
        XCTAssertEqual(Double(image.width) / Double(app.frame.width), 3, accuracy: 0.01)
        XCTAssertEqual(Double(image.height) / Double(app.frame.height), 3, accuracy: 0.01)
        let masks = try rects.map { frame -> Mask in
            let px = frame.applying(CGAffineTransform(scaleX: 3, y: 3)).integral
            return try inkMask(try XCTUnwrap(image.cropping(to: px)))
        }
        XCTAssertTrue(masks[0].matches(masks[1]), "Scoped MadText must match independent 28sp/SemiBold Material Text")
        XCTAssertTrue(masks[2].matches(masks[3]), "Outside MadText must match the original Material title")
        XCTAssertTrue(masks[3].matches(masks[5]), "Repeated unchanged reference must be stable")
        XCTAssertTrue(masks[4].matches(masks[3]), "Provider-disabled control must match baseline")
        XCTAssertFalse(masks[4].matches(masks[1]), "Provider-disabled control must fail scoped comparison")
        XCTAssertGreaterThanOrEqual(masks[0].h - masks[2].h, 3, "Scoped glyphs must differ visibly from baseline")
        let values: [String: Any] = [
            "density": density, "tokenPx": token, "gapsPx": gaps,
            "scopedGlyphPx": [masks[0].w, masks[0].h], "outsideGlyphPx": [masks[2].w, masks[2].h],
            "scopedMatchesRaw": masks[0].matches(masks[1]),
            "outsideMatchesRaw": masks[2].matches(masks[3]),
            "unchangedReferenceMatches": masks[3].matches(masks[5]),
            "providerDisabledMatchesBaseline": masks[4].matches(masks[3]),
            "wrongProviderRejected": !masks[4].matches(masks[1])
        ]
        let typed = XCTAttachment(data: try JSONSerialization.data(withJSONObject: values), uniformTypeIdentifier: "public.json")
        typed.name = "S1-typography-metric-values"
        typed.lifetime = .keepAlways
        add(typed)
        let a = XCTAttachment(data: photo, uniformTypeIdentifier: "public.png")
        a.name = "S1-typography-metrics-original"
        a.lifetime = .keepAlways
        add(a)
    }

    private func inkMask(_ image: CGImage) throws -> Mask {
        let w = image.width, h = image.height
        guard w > 0, h > 0, w <= 1206, h <= 2622 else { throw MetricFailure() }
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let ok = rgba.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h)))
            return true
        }
        guard ok else { throw MetricFailure() }
        let dark = (0..<(w*h)).filter { i in
            let k = i*4
            return rgba[k+3] > 240 && Int(rgba[k])+Int(rgba[k+1])+Int(rgba[k+2]) < 300
        }
        let xs = dark.map { $0 % w }, ys = dark.map { $0 / w }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max(),
              dark.count > 20, x1 > x0, y1 > y0 else { throw MetricFailure() }
        let iw = x1-x0+1, ih = y1-y0+1
        return Mask(w: iw, h: ih, ink: Set(zip(xs, ys).map { ($0.1-y0)*iw+($0.0-x0) }))
    }
}
