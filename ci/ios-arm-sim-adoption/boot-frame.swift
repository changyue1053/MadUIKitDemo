// Standard Apple SDK only. Screen validation, not app execution or recognition.
import CoreGraphics
import Foundation
import ImageIO

enum FrameError: Error { case invalid, unexpectedSize, blank, unreadable }
guard CommandLine.arguments.count == 3, ["boot","books"].contains(CommandLine.arguments[2]) else {
    throw FrameError.invalid
}
let mode = CommandLine.arguments[2]
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: url)
guard data.starts(with: [137,80,78,71,13,10,26,10]),
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) == 1,
      CGImageSourceGetStatus(source) == .statusComplete,
      CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw FrameError.invalid }
// iPhone 17 Pro pixel dimensions; fail closed on unknown simulator frame.
guard image.width == 1206, image.height == 2622 else { throw FrameError.unexpectedSize }
var pixels = [UInt8](repeating: 0, count: 32 * 64 * 4)
let inspected = pixels.withUnsafeMutableBytes { bytes -> Bool in
    guard let context = CGContext(data: bytes.baseAddress, width: 32, height: 64,
        bitsPerComponent: 8, bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
    context.interpolationQuality = .medium
    context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 64))
    return true
}
guard inspected else { throw FrameError.unreadable }
var luma: [Int] = []
luma.reserveCapacity(pixels.count / 4)
for i in stride(from: 0, to: pixels.count, by: 4) {
    let red: Int = Int(pixels[i])
    let green: Int = Int(pixels[i + 1])
    let blue: Int = Int(pixels[i + 2])
    let redWeight: Int = 54 * red
    let greenWeight: Int = 183 * green
    let blueWeight: Int = 19 * blue
    let weightedSum: Int = redWeight + greenWeight + blueWeight
    luma.append(weightedSum / 256)
}
guard let dark = luma.min(), let bright = luma.max() else { throw FrameError.blank }
if mode == "boot" {
    guard Set(luma).count >= 30, bright-dark >= 40,
          luma.filter({$0 > 30}).count >= 300 else { throw FrameError.blank }
} else {
    // A sparse static light app can have less luminance diversity than the Home Screen.
    guard Set(luma).count >= 6, bright-dark >= 15 else { throw FrameError.blank }
}
print("{\"width\":1206,\"height\":2622,\"decodedPNG\":true,\"nonblankCheck\":true,\"profile\":\"\(mode)\"}")
