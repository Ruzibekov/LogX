import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// LogX app ikonkasi — "Oqim-X": piksel-X, slate × amethyst, yashil jonli uchki.
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func draw(px: Int) -> CGImage? {
    let s = CGFloat(px)
    let w = CGFloat(px)
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // Slate kvadrat, macOS radiusi
    let radius = s * 0.2237
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(color(0x1A202B))
    ctx.fillPath()
    // Nozik chetka
    ctx.addPath(path)
    ctx.setStrokeColor(color(0x2E3745))
    ctx.setLineWidth(max(1, s / 128))
    ctx.strokePath()
    // 7×7 piksel-X
    let cell = s * 18.0 / 256.0, gap = s * 4.0 / 256.0, pad = s * 52.0 / 256.0
    var cells = Set<[Int]>()
    for i in 0..<7 { cells.insert([i, i]); cells.insert([i, 6 - i]) }
    let amethyst = color(0xA78BFA), green = color(0x57C98A)
    for cellIdx in cells {
        let r = cellIdx[0], c = cellIdx[1]
        let x = pad + CGFloat(c) * (cell + gap)
        let y = pad + CGFloat(6 - r) * (cell + gap) // CG y pastdan
        let cr = CGRect(x: x, y: y, width: cell, height: cell)
        ctx.addPath(CGPath(roundedRect: cr, cornerWidth: cell * 0.28, cornerHeight: cell * 0.28, transform: nil))
        ctx.setFillColor((r == 0 && c == 6) ? green : amethyst)
        ctx.fillPath()
    }
    _ = w
    return ctx.makeImage()
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".build/icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, px) in sizes {
    guard let img = draw(px: px) else { continue }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}
print("iconset: \(outDir)")
