import AppKit
import Foundation

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func render(size px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let S = CGFloat(px)
    let inset = S * 0.055
    let rect = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let radius = rect.width * 0.232

    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.40, green: 0.56, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.58, green: 0.40, blue: 0.99, alpha: 1),
        NSColor(srgbRed: 0.36, green: 0.72, blue: 0.94, alpha: 1)
    ], atLocations: [0, 0.55, 1], colorSpace: .sRGB)
    gradient?.draw(in: rect, angle: -62)

    let glow = NSGradient(colors: [
        NSColor(white: 1, alpha: 0.55),
        NSColor(white: 1, alpha: 0)
    ])
    glow?.draw(in: NSBezierPath(ovalIn: NSRect(x: rect.minX - rect.width * 0.2,
                                               y: rect.midY,
                                               width: rect.width * 1.3,
                                               height: rect.height * 0.85)),
               relativeCenterPosition: .zero)

    if let symbol = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: S * 0.40, weight: .semibold)
        if let scaled = symbol.withSymbolConfiguration(config) {
            let tinted = NSImage(size: scaled.size)
            tinted.lockFocus()
            scaled.draw(in: NSRect(origin: .zero, size: scaled.size))
            NSColor(white: 1, alpha: 0.97).set()
            NSRect(origin: .zero, size: scaled.size).fill(using: .sourceAtop)
            tinted.unlockFocus()

            let w = tinted.size.width
            let h = tinted.size.height
            let target = NSRect(x: (S - w) / 2, y: (S - h) / 2 - S * 0.005, width: w, height: h)
            tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 0.96)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, size) in variants {
    guard let data = render(size: size) else { continue }
    try data.write(to: URL(fileURLWithPath: "\(outputDir)/\(name).png"))
}
print("icon set written to \(outputDir)")
