// Generates Support/Assets.car and Support/AppIcon.icns from a drawn heart gauge.
// Run: swiftc -O -o /tmp/make-icon Support/make-icon.swift && /tmp/make-icon Support   (needs Xcode's actool)
import AppKit

func symbol(_ name: String, _ size: CGFloat) -> NSImage {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: size, weight: .regular))!
}

/// The icon: a white heart gauge, three quarters full, on a deep teal gradient tile.
func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.08
    let tile = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: size * 0.185, yRadius: size * 0.185)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.62, blue: 0.56, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.38, blue: 0.37, alpha: 1),
    ])!.draw(in: tile, angle: -90)

    // Heart gauge: solid heart, interior cut by a scaled copy, inset level clipped to 75%.
    let heart = symbol("heart.fill", size * 0.52)
    let s = heart.size
    let glyph = NSImage(size: s, flipped: false) { r in
        heart.draw(in: r)
        let cut = r.insetBy(dx: r.width * 0.09, dy: r.height * 0.09)
        heart.draw(in: cut, from: .zero, operation: .destinationOut, fraction: 1)
        let inner = r.insetBy(dx: r.width * 0.155, dy: r.height * 0.155)
        NSGraphicsContext.saveGraphicsState()
        NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: inner.height * 0.75).clip()
        heart.draw(in: inner)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.set()
        r.fill(using: .sourceIn)
        return true
    }
    glyph.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2 - size * 0.015, width: s.width, height: s.height))
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let support = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let work = support.appendingPathComponent("IconWork")
let assets = work.appendingPathComponent("Assets.xcassets")
let set = assets.appendingPathComponent("AppIcon.appiconset")
try? FileManager.default.removeItem(at: work)
try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let name = "icon_\(base)x\(base)@\(scale)x.png"
        try! png(drawIcon(size: CGFloat(pixels)), pixels: pixels).write(to: set.appendingPathComponent(name))
        images.append(["size": "\(base)x\(base)", "idiom": "mac", "filename": name, "scale": "\(scale)x"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try! JSONSerialization.data(withJSONObject: contents, options: .prettyPrinted).write(to: set.appendingPathComponent("Contents.json"))
try! JSONSerialization.data(withJSONObject: ["info": ["version": 1, "author": "xcode"]], options: .prettyPrinted).write(to: assets.appendingPathComponent("Contents.json"))
try! png(drawIcon(size: 1024), pixels: 1024).write(to: support.appendingPathComponent("AppIcon-preview.png"))

let out = work.appendingPathComponent("out")
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
task.arguments = ["actool", "--compile", out.path, "--platform", "macosx", "--minimum-deployment-target", "13.0",
                  "--app-icon", "AppIcon", "--output-partial-info-plist", work.appendingPathComponent("partial.plist").path,
                  "--output-format", "human-readable-text", assets.path]
task.standardOutput = FileHandle.nullDevice
try! task.run()
task.waitUntilExit()
for file in ["Assets.car", "AppIcon.icns"] {
    let dst = support.appendingPathComponent(file)
    try? FileManager.default.removeItem(at: dst)
    try! FileManager.default.copyItem(at: out.appendingPathComponent(file), to: dst)
}
try? FileManager.default.removeItem(at: work)
print(task.terminationStatus == 0 ? "wrote Assets.car and AppIcon.icns" : "actool failed")
