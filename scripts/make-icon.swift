// Kullanım: swift scripts/make-icon.swift <çıktı.png>
// Logo B: koyu zemin, üstte mor gradyan tuşta beyaz "+", altta gri tuşta sarı "−".
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

guard CommandLine.arguments.count == 2 else {
    print("usage: swift make-icon.swift <output.png>"); exit(1)
}

let pixels = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// SVG koordinatları (180x180, y aşağı) → 1024px
let scale = CGFloat(pixels) / 180
ctx.translateBy(x: 0, y: CGFloat(pixels))
ctx.scaleBy(x: scale, y: -scale)

ctx.setFillColor(color(0x0B0B0F))
ctx.fill(CGRect(x: 0, y: 0, width: 180, height: 180))

// Üst tuş (gradyan)
let topKey = CGRect(x: 22, y: 22, width: 136, height: 64)
ctx.saveGState()
ctx.addPath(rounded(topKey, 20))
ctx.clip()
let gradient = CGGradient(colorsSpace: space, colors: [color(0x6E6CF0), color(0xC76AF5)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: topKey.minX, y: topKey.minY),
                       end: CGPoint(x: topKey.maxX, y: topKey.maxY), options: [])
ctx.restoreGState()

// Alt tuş
ctx.setFillColor(color(0x26262E))
ctx.addPath(rounded(CGRect(x: 22, y: 94, width: 136, height: 64), 20))
ctx.fillPath()

// +
ctx.setFillColor(color(0xFFFFFF))
ctx.addPath(rounded(CGRect(x: 70, y: 48, width: 40, height: 12), 6))
ctx.addPath(rounded(CGRect(x: 84, y: 34, width: 12, height: 40), 6))
ctx.fillPath()

// −
ctx.setFillColor(color(0xFFD60A))
ctx.addPath(rounded(CGRect(x: 70, y: 120, width: 40, height: 12), 6))
ctx.fillPath()

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { print("write failed"); exit(1) }
print("wrote \(url.path)")
