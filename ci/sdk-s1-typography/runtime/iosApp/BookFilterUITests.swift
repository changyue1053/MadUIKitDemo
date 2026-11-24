import XCTest
import UIKit
import CoreGraphics

final class BookFilterUITests: XCTestCase {
    func testAlpha09FoundationGallery() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.mad.synthetic.typography.ios")
        app.launch()
        unique(app, "gallery-title", label: "Foundation gallery · alpha09")
        let light = unique(app, "gallery-light", label: "Light")
        let dark = unique(app, "gallery-dark", label: "Dark")
        let brand = unique(app, "gallery-brand", label: "Brand")
        let restored = unique(app, "gallery-restored", label: "Restored")
        tryColor(light, expected: [49, 83, 166])
        tryColor(dark, expected: [186, 200, 255])
        tryColor(brand, expected: [0, 107, 86])
        tryColor(restored, expected: [49, 83, 166])
        unique(app, "gallery-geometry", label: "Dividers: 3/9 px @ 3.0x / bounded")
        unique(app, "gallery-mode", label: "Mode: Online / 0")
        let before = XCUIScreen.main.screenshot().pngRepresentation
        let offline = unique(app, "gallery-offline", label: "Offline")
        XCTAssertTrue(offline.isHittable)
        offline.tap()
        unique(app, "gallery-mode", label: "Mode: Offline / 1")
        offline.tap()
        let online = unique(app, "gallery-online", label: "Online")
        XCTAssertTrue(online.isHittable)
        online.tap()
        unique(app, "gallery-mode", label: "Mode: Online / 2")
        offline.tap()
        unique(app, "gallery-mode", label: "Mode: Offline / 3")
        retainScreen("S1-alpha09-gallery-before", before)
        retainScreen("S1-alpha09-gallery-after", XCUIScreen.main.screenshot().pngRepresentation)
    }

    // Use rendered UIButton-region pixels, not colors reported by the same Kotlin fixture.
    // Interior patches avoid the rounded corner, border, and centered text.
    private func tryColor(_ button: XCUIElement, expected: [Int]) {
        guard let source = button.screenshot().image.cgImage, source.width >= 240,
              source.height >= 72, let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return XCTFail("No rendered color image")
        }
        for fraction in [0.20, 0.80] {
            let x = Int(Double(source.width) * fraction)
            let y = source.height / 2
            guard let crop = source.cropping(to: CGRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1)),
                  let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: colorSpace, bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue |
                        CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return XCTFail("No sRGB color sample")
            }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else {
                return XCTFail("No decoded sRGB color sample")
            }
            XCTAssertEqual(data[3], 255)
            for channel in 0..<3 {
                XCTAssertLessThanOrEqual(abs(Int(data[channel]) - expected[channel]), 4)
            }
        }
    }

    @discardableResult
    private func unique(_ app: XCUIApplication, _ tag: String, label: String) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", tag))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 30))
        XCTAssertEqual(query.count, 1)
        let element = query.element(boundBy: 0)
        XCTAssertEqual(element.identifier, tag)
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [matches], timeout: 15), .completed)
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
