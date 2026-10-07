import AppKit

/// A monochrome heart whose fill rises with the score, drawn from SF Symbols.
enum ScoreHeart {
    static let pointSize: CGFloat = 11
    static let gap: CGFloat = 5
    /// The fill is lighter than the outline so the level stays readable at any score.
    static let fillOpacity: CGFloat = 0.45

    /// `fill` 0...1. Tinted with `color`; dynamic colors resolve at draw time, so call again on appearance changes.
    static func image(fill: Double, color: NSColor, pointSize: CGFloat = pointSize) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let outline = NSImage(systemSymbolName: "heart", accessibilityDescription: nil)?.withSymbolConfiguration(config),
              let filled = NSImage(systemSymbolName: "heart.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
        else { return nil }
        let size = outline.size
        let image = NSImage(size: size, flipped: false) { rect in
            // Fill from the bottom up to the score, then the outline on top.
            let fillHeight = rect.height * CGFloat(min(max(fill, 0), 1))
            NSGraphicsContext.saveGraphicsState()
            NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: fillHeight).clip()
            filled.draw(in: rect, from: .zero, operation: .sourceOver, fraction: fillOpacity)
            NSGraphicsContext.restoreGraphicsState()
            outline.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The heart centered on a square canvas, for the ring to wrap when the heart is the whole item.
    static func canvas(fill: Double, color: NSColor, canvas: CGFloat) -> NSImage? {
        guard let heart = image(fill: fill, color: color, pointSize: 11.5) else { return nil }
        let result = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
            heart.draw(in: NSRect(x: (canvas - heart.size.width) / 2, y: (canvas - heart.size.height) / 2,
                                  width: heart.size.width, height: heart.size.height))
            return true
        }
        result.isTemplate = false
        return result
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
