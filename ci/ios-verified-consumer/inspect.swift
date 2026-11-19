import CoreGraphics
import Foundation
import ImageIO
let u = URL(fileURLWithPath: CommandLine.arguments[1])
guard let s = CGImageSourceCreateWithURL(u as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(s, 0, nil),
      let srgb = CGColorSpace(name: CGColorSpace.sRGB),
      let c = CGContext(data: nil, width: 180, height: 360, bitsPerComponent: 8, bytesPerRow: 720,
                        space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                        CGBitmapInfo.byteOrder32Big.rawValue),
      let data = c.data?.assumingMemoryBound(to: UInt8.self) else { exit(2) }
c.draw(image, in: CGRect(x: 0, y: 0, width: 180, height: 360))
var rows = 0
for y in 0..<360 {
    var violet = 0
    var teal = 0
    for x in 68..<112 {
        let i = (y * 180 + x) * 4
        let r = Int(data[i]), g = Int(data[i+1]), b = Int(data[i+2])
        if abs(r-84) < 27 && abs(g-38) < 27 && abs(b-145) < 27 { violet += 1 }
    }
    for x in 129..<172 {
        let i = (y * 180 + x) * 4
        let r = Int(data[i]), g = Int(data[i+1]), b = Int(data[i+2])
        if abs(r-13) < 30 && abs(g-107) < 30 && abs(b-107) < 30 { teal += 1 }
    }
    if violet >= 8 && teal >= 6 { rows += 1 }
}
print("image=\(image.width)x\(image.height) gradient_marker_rows=\(rows)")
exit(rows >= 8 ? 0 : 1)
