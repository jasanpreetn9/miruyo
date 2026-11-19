// Renders the app icon: the 見 mark from the top bar, in dark ink on the
// anime accent (Beni), full-bleed (iOS and Android mask the corners).
// Run: swift tool/make_icon.swift <out.png> [size] [mark]
// With "mark", the tile is rounded like the top bar's (transparent corners),
// for the launch screen. Without it the image is opaque, as the App Store
// requires, drawn straight onto an opaque canvas (no lossy flattening).

import AppKit
import CoreText

let args = CommandLine.arguments
guard args.count >= 2 else {
  FileHandle.standardError.write("usage: swift tool/make_icon.swift <out.png> [size] [mark]\n".data(using: .utf8)!)
  exit(1)
}
let size = args.count >= 3 ? Int(args[2]) ?? 1024 : 1024
let mark = args.count >= 4 && args[3] == "mark"
let s = CGFloat(size)

// Accent.beni and Accent.beniInk in lib/core/theme/tokens.dart
let beni = CGColor(srgbRed: 0xFF / 255, green: 0x6A / 255, blue: 0x55 / 255, alpha: 1)
let ink = CGColor(srgbRed: 0x1A / 255, green: 0x0B / 255, blue: 0x08 / 255, alpha: 1)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
// opaque for the app icon; with alpha only for the rounded launch mark
let info = mark ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
let ctx = CGContext(
  data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)!
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

ctx.setFillColor(beni)
let tile = CGRect(x: 0, y: 0, width: s, height: s)
if mark {
  // the top bar's corner: 29% of the size
  ctx.addPath(CGPath(roundedRect: tile, cornerWidth: s * 0.29, cornerHeight: s * 0.29, transform: nil))
  ctx.fillPath()
} else {
  ctx.fill(tile)
}

// the glyph at the top bar's proportion, in the heaviest Hiragino weight
let font = CTFontCreateWithName("HiraginoSans-W8" as CFString, s * 0.57, nil)
let line = CTLineCreateWithAttributedString(
  NSAttributedString(string: "見", attributes: [.font: font, .foregroundColor: ink]))
// centre the ink itself (its exact image bounds), not the line box
let bounds = CTLineGetImageBounds(line, ctx)
ctx.textPosition = CGPoint(x: (s - bounds.width) / 2 - bounds.minX, y: (s - bounds.height) / 2 - bounds.minY)
CTLineDraw(line, ctx)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
