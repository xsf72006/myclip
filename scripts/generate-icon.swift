#!/usr/bin/env swift
// Render the SF Symbol used in the menu bar into an .icns app icon so the
// app shows the same artwork in Finder / System Settings → Accessibility.
// Run with: swift scripts/generate-icon.swift
//
// Produces: Bundle/AppIcon.icns

import AppKit

func renderIcon(size: Int) -> Data? {
    let pt = CGFloat(size) * 0.7
    let config = NSImage.SymbolConfiguration(pointSize: pt, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor.controlAccentColor]))
    guard let symbol = NSImage(systemSymbolName: "doc.on.clipboard.fill",
                               accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    else { return nil }

    let target = NSImage(size: NSSize(width: size, height: size))
    target.lockFocus()
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let sSize = symbol.size
    let origin = NSPoint(x: (CGFloat(size) - sSize.width) / 2,
                         y: (CGFloat(size) - sSize.height) / 2)
    symbol.draw(at: origin,
                from: NSRect(origin: .zero, size: sSize),
                operation: .sourceOver,
                fraction: 1.0)
    target.unlockFocus()

    guard let tiff = target.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { return nil }
    return png
}

let iconset: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

let buildDir = "build"
let iconsetDir = "\(buildDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetDir)
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for entry in iconset {
    guard let png = renderIcon(size: entry.size) else {
        fputs("error: failed to render \(entry.name)\n", stderr)
        exit(1)
    }
    let path = "\(iconsetDir)/\(entry.name)"
    try? png.write(to: URL(fileURLWithPath: path))
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetDir, "-o", "Bundle/AppIcon.icns"]
try? task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    fputs("error: iconutil failed with status \(task.terminationStatus)\n", stderr)
    exit(1)
}

print("Wrote Bundle/AppIcon.icns")
