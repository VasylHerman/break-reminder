import AppKit

/// A monochrome heart whose fill rises with the score, drawn from SF Symbols.
enum ScoreHeart {
    static let pointSize: CGFloat = 11
    static let gap: CGFloat = 5
    /// Geometry in points, measured from the menu bar battery: a 1 pt body stroke and a 1 pt gap to the
    /// level, 2 device pixels each at 2x. Eroding anti-aliased masks widens each edge by about a quarter
    /// point, so the radii are set a little under the targets.
    static let strokeWidth: CGFloat = 0.75
    static let gapWidth: CGFloat = 0.9
    /// The battery draws its body lighter than its level. Tuned by eye against the menu bar battery:
    /// body at 40% ink, level at 85%. Both are fractions of the tint color opacity, and the same
    /// 40% body tone is used for the outline of the minutes pill and the dot ring.
    static let outlineOpacity: CGFloat = 0.40
    static let levelOpacity: CGFloat = 0.85
    /// Orange and red are lighter inks than the label color, so their outline needs more opacity to stay visible.
    static let coloredOutlineOpacity: CGFloat = 0.65

    /// `fill` 0...1. Tinted with `color`; dynamic colors resolve at draw time, so call again on appearance changes.
    /// Both the stroke and the level are derived from the solid heart by erosion, so the stroke is uniform and
    /// the level follows it at a constant gap, exactly like the battery's body and level. `weight` is unused.
    /// Which parts to draw; the menu bar draws body and level on separate layers so they can beat apart.
    struct Parts: OptionSet {
        let rawValue: Int
        static let body = Parts(rawValue: 1)
        static let level = Parts(rawValue: 2)
        static let all: Parts = [.body, .level]
    }

    static func image(fill: Double, color: NSColor, pointSize: CGFloat = pointSize, weight: NSFont.Weight = .regular,
                      outlineOpacity: CGFloat = outlineOpacity, parts: Parts = .all,
                      levelStyle: HeartLevelStyle = Settings.heartLevelStyle) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let solid = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        else { return nil }
        let size = solid.size
        let frame = NSRect(origin: .zero, size: size)
        let complement = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            rect.fill()
            solid.draw(in: rect, from: .zero, operation: .destinationOut, fraction: 1)
            return true
        }
        let inner = eroded(solid, complement: complement, by: strokeWidth)
        let level = eroded(solid, complement: complement, by: strokeWidth + gapWidth)

        // Opaque coverage masks; opacity is applied afterwards so it never interferes with the edges.
        let strokeMask = NSImage(size: size, flipped: false) { r in
            solid.draw(in: r)
            inner.draw(in: r, from: .zero, operation: .destinationOut, fraction: 1)
            return true
        }
        // The fill runs over the level's own ink, not the symbol's padded box, so 83% leaves a visible gap.
        let levelInk = inkBounds(of: level) ?? frame
        let levelMask = NSImage(size: size, flipped: false) { r in
            // Fading style: the level is always the whole heart and the tone carries the score.
            let shown = levelStyle == .fades ? 1 : min(max(fill, 0), 1)
            let levelTop = levelInk.minY + levelInk.height * CGFloat(shown)
            NSRect(x: r.minX, y: r.minY, width: r.width, height: max(0, levelTop - r.minY)).clip()
            level.draw(in: r)
            return true
        }

        let image = NSImage(size: size, flipped: false) { rect in
            let tintedLevel = NSImage(size: size, flipped: false) { r in
                levelMask.draw(in: r)
                color.withAlphaComponent(levelAlpha(fill: fill, style: levelStyle)).set()
                r.fill(using: .sourceIn)
                return true
            }
            let tintedStroke = NSImage(size: size, flipped: false) { r in
                strokeMask.draw(in: r)
                color.withAlphaComponent(outlineOpacity).set()
                r.fill(using: .sourceIn)
                return true
            }
            if parts.contains(.level) { tintedLevel.draw(in: frame) }
            if parts.contains(.body) { tintedStroke.draw(in: frame) }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Opacity of the level: fixed when it rises, dark at a full score and fading to gray at none when it fades.
    static let fadedLevelOpacity: CGFloat = 0.2
    static func levelAlpha(fill: Double, style: HeartLevelStyle) -> CGFloat {
        guard style == .fades else { return levelOpacity }
        let score = CGFloat(min(max(fill, 0), 1))
        return fadedLevelOpacity + (levelOpacity - fadedLevelOpacity) * score
    }

    /// The solid glyph shrunk inward by `radius` points on every side: the glyph minus its surroundings
    /// shifted in 36 directions.
    private static func eroded(_ solid: NSImage, complement: NSImage, by radius: CGFloat) -> NSImage {
        NSImage(size: solid.size, flipped: false) { rect in
            solid.draw(in: rect)
            for step in 0..<36 {
                let angle = CGFloat(step) / 36 * 2 * .pi
                complement.draw(in: rect.offsetBy(dx: radius * cos(angle), dy: radius * sin(angle)),
                                from: .zero, operation: .destinationOut, fraction: 1)
            }
            return true
        }
    }

    /// The heart centered on a square canvas, for the ring to wrap when the heart is the whole item.
    static let menuBarPointSize: CGFloat = 16
    static let menuBarWeight: NSFont.Weight = .regular

    static func canvas(fill: Double, color: NSColor, canvas: CGFloat, outlineOpacity: CGFloat = outlineOpacity,
                       parts: Parts = .all, levelStyle: HeartLevelStyle = Settings.heartLevelStyle) -> NSImage? {
        guard let heart = image(fill: fill, color: color, pointSize: menuBarPointSize, weight: menuBarWeight,
                                outlineOpacity: outlineOpacity, parts: parts, levelStyle: levelStyle),
              let whole = parts == .all ? heart : image(fill: 1, color: color, pointSize: menuBarPointSize, weight: menuBarWeight)
        else { return nil }
        // Center the whole glyph's ink, not its bounding box, so body and level canvases line up.
        let ink = inkBounds(of: whole) ?? NSRect(origin: .zero, size: heart.size)
        let result = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
            let x = (canvas / 2 - ink.midX).rounded(.toNearestOrEven)
            let y = (canvas / 2 - ink.midY).rounded(.toNearestOrEven)
            heart.draw(in: NSRect(origin: NSPoint(x: x, y: y), size: heart.size))
            return true
        }
        result.isTemplate = false
        return result
    }

    /// An empty canvas, used as the status item image so the layers have room.
    static func emptyCanvas(_ canvas: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in true }
        image.isTemplate = false
        return image
    }

    /// Bounding box of the non-transparent pixels, in points (y up), rasterized at 2x.
    private static func inkBounds(of image: NSImage) -> NSRect? {
        let w = Int(image.size.width * 2), h = Int(image.size.height * 2)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.bitmapData else { return nil }
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w where data[y * rep.bytesPerRow + x * 4 + 3] > 40 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        // Bitmap rows are top-down; convert to points with y up.
        return NSRect(x: CGFloat(minX) / 2, y: CGFloat(h - 1 - maxY) / 2,
                      width: CGFloat(maxX - minX + 1) / 2, height: CGFloat(maxY - minY + 1) / 2)
    }

    /// Heart on the left, another image on the right, with a gap.
    static func compose(heart: NSImage, with other: NSImage) -> NSImage {
        let height = max(heart.size.height, other.size.height)
        let size = NSSize(width: heart.size.width + gap + other.size.width, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            heart.draw(in: NSRect(x: 0, y: (height - heart.size.height) / 2, width: heart.size.width, height: heart.size.height))
            other.draw(in: NSRect(x: heart.size.width + gap, y: (height - other.size.height) / 2,
                                  width: other.size.width, height: other.size.height))
            return true
        }
        image.isTemplate = false
        return image
    }
}
