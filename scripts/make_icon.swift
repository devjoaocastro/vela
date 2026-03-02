#!/usr/bin/env swift
// Generates Vela.icns from SF Symbol "sailboat.fill"
import AppKit

let sizes: [(Int, String)] = [
    (16,    "icon_16x16"),
    (32,    "icon_16x16@2x"),
    (32,    "icon_32x32"),
    (64,    "icon_32x32@2x"),
    (128,   "icon_128x128"),
    (256,   "icon_128x128@2x"),
    (256,   "icon_256x256"),
    (512,   "icon_256x256@2x"),
    (512,   "icon_512x512"),
    (1024,  "icon_512x512@2x"),
]

// Create iconset directory
let iconsetPath = "Vela.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let cgSize = CGSize(width: size, height: size)
    let image = NSImage(size: cgSize)

    image.lockFocus()

    // Background: deep navy-blue gradient
    let bgRect = CGRect(origin: .zero, size: cgSize)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.35, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.55, alpha: 1)
    ])!
    gradient.draw(in: NSBezierPath(roundedRect: bgRect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22), angle: -70)

    // SF Symbol sailboat.fill — force white via paletteColors
    let symbolSize = CGFloat(size) * 0.58
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "sailboat.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {

        let symW = symbolSize * 1.1
        let symH = symbolSize * 1.1
        let x = (CGFloat(size) - symW) / 2
        let y = (CGFloat(size) - symH) / 2 + CGFloat(size) * 0.02
        let symRect = CGRect(x: x, y: y, width: symW, height: symH)
        symbol.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()

    // Save as PNG
    if let tiff = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let outPath = "\(iconsetPath)/\(name).png"
        try? png.write(to: URL(fileURLWithPath: outPath))
        print("✓ \(outPath)")
    }
}

print("✓ Iconset ready. Run: iconutil -c icns \(iconsetPath)")
