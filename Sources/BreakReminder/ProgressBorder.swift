import AppKit
import QuartzCore

/// A thin rounded outline drawn around the status item's text that closes clockwise
/// as the work block approaches the limit.
final class ProgressBorder {
    /// The arc is drawn into a bitmap like the heart; a CAShapeLayer stroke did not render under the
    /// menu bar's vibrant dark appearance while bitmap layers did.
    private let shape = CALayer()
    /// Heart mode draws the glyph as two layers so each part can beat on its own.
    let bodyLayer = CALayer()
    let levelLayer = CALayer()
    var ringLayer: CALayer { shape }
    private weak var button: NSStatusBarButton?

    init(button: NSStatusBarButton) {
        self.button = button
        button.wantsLayer = true
        shape.contentsGravity = .center
        for layer in [levelLayer, bodyLayer] {
            layer.contentsGravity = .center
            layer.isHidden = true
            button.layer?.addSublayer(layer)
        }
        button.layer?.addSublayer(shape)
        button.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(layout), name: NSView.frameDidChangeNotification, object: button
        )
    }

    /// Shows the heart as body and level layers (nil hides them). The images are rasterized under the
    /// menu bar's appearance, so dynamic colors resolve for a dark bar as well as a light one.
    func setGlyph(body: NSImage?, level: NSImage?) {
        guard let button else { return }
        let scale = button.window?.backingScaleFactor ?? 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            for (layer, image) in [(bodyLayer, body), (levelLayer, level)] {
                layer.isHidden = image == nil
                layer.contentsScale = scale
                layer.contents = image.flatMap { Self.rasterize($0, scale: scale) }
            }
        }
        CATransaction.commit()
        layout()
    }

    private static func rasterize(_ image: NSImage, scale: CGFloat) -> CGImage? {
        let pixels = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    /// `progress` is the block's share of the limit (may exceed 1); nil hides the border.
    func update(progress: Double?, style: OutlineStyle, color: NSColor) {
        // Past the limit the arc stays at the covered span, in red; the ring never closes.
        let stroke: (anchor: OutlineStyle.Anchor, start: Double, end: Double)?
        if let progress, progress >= 1, style != .off {
            stroke = style.overStroke()
        } else if let progress {
            stroke = style.stroke(progress: progress)
        } else {
            stroke = nil
        }
        guard let stroke else {
            shape.isHidden = true
            return
        }
        shape.isHidden = false
        lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 2 : 1
        strokeColor = color
        strokeRange = (stroke.start, stroke.end)
        anchor = stroke.anchor
        layout()
    }

    private var anchor: OutlineStyle.Anchor = .top
    private var lineWidth: CGFloat = 1
    private var strokeColor: NSColor = .labelColor
    private var strokeRange: (start: Double, end: Double) = (0, 0)

    /// Diameter of the ring drawn around the glyph when there are no digits, and the glyph's canvas size. Set per glyph.
    var ringDiameter: CGFloat = 14
    var glyphCanvas: CGFloat = 16

    /// Fit the outline around the text, or draw a ring around the dot when there is no text.
    /// The cell reports where it places the title and the image, which accounts for a leading heart.
    @objc private func layout() {
        guard let button, let title = button.attributedTitle as NSAttributedString? else { return }
        let cell = button.cell as? NSButtonCell
        let rect: NSRect
        let radius: CGFloat
        if title.length == 0 {
            // Ring around the glyph: the glyph canvas sits at the right end of the image, centered in it.
            let d = ringDiameter
            let imageRect = cell?.imageRect(forBounds: button.bounds) ?? button.bounds
            let dotCenterX = imageRect.maxX - glyphCanvas / 2
            rect = NSRect(x: dotCenterX - d / 2, y: (button.bounds.height - d) / 2, width: d, height: d)
                .insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            radius = rect.height / 2
        } else {
            let textSize = title.size()
            let width = ceil(textSize.width) + 8
            let height = ceil(textSize.height) + 2
            let titleRect = cell?.titleRect(forBounds: button.bounds) ?? button.bounds
            rect = NSRect(
                x: titleRect.midX - width / 2,
                y: (button.bounds.height - height) / 2,
                width: width,
                height: height
            ).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            radius = min(6, rect.height / 2)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.frame = button.bounds
        shape.contentsScale = button.window?.backingScaleFactor ?? 2
        let path = Self.clockwisePath(in: rect, radius: radius, anchor: anchor)
        let image = NSImage(size: button.bounds.size, flipped: true) { [lineWidth, strokeColor, strokeRange] _ in
            guard let trimmed = Self.trimmed(path, from: strokeRange.start, to: strokeRange.end),
                  let context = NSGraphicsContext.current?.cgContext else { return true }
            context.addPath(trimmed)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setStrokeColor(strokeColor.cgColor)
            context.strokePath()
            return true
        }
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            shape.contents = Self.rasterize(image, scale: shape.contentsScale)
        }
        CATransaction.commit()

        // Glyph layers sit on the canvas at the right end of the image rect.
        if !bodyLayer.isHidden || !levelLayer.isHidden {
            let imageRect = cell?.imageRect(forBounds: button.bounds) ?? button.bounds
            let canvasRect = NSRect(x: imageRect.maxX - glyphCanvas, y: (button.bounds.height - glyphCanvas) / 2,
                                    width: glyphCanvas, height: glyphCanvas)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bodyLayer.frame = canvasRect
            levelLayer.frame = canvasRect
            CATransaction.commit()
        }
    }

    /// The part of a path between two fractions of its length, sampled finely enough for a 1 pt stroke.
    private static func trimmed(_ path: CGPath, from start: Double, to end: Double) -> CGPath? {
        guard end > start else { return nil }
        // Flatten the path into points, then keep the ones inside the length range.
        var points: [CGPoint] = []
        var current = CGPoint.zero
        path.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint: current = e.points[0]; points.append(current)
            case .addLineToPoint: current = e.points[0]; points.append(current)
            case .addQuadCurveToPoint, .addCurveToPoint:
                let c1 = e.points[0], c2 = e.type == .addCurveToPoint ? e.points[1] : e.points[0]
                let to = e.type == .addCurveToPoint ? e.points[2] : e.points[1]
                let from = current
                for i in 1...12 {
                    let t = CGFloat(i) / 12, u = 1 - t
                    let x = u*u*u*from.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*to.x
                    let y = u*u*u*from.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*to.y
                    points.append(CGPoint(x: x, y: y))
                }
                current = to
            case .closeSubpath:
                if let first = points.first { points.append(first) }
            @unknown default: break
            }
        }
        guard points.count > 1 else { return nil }
        var lengths: [CGFloat] = [0]
        for i in 1..<points.count { lengths.append(lengths[i - 1] + hypot(points[i].x - points[i-1].x, points[i].y - points[i-1].y)) }
        let total = lengths.last!
        let a = CGFloat(start) * total, b = CGFloat(end) * total
        func point(at length: CGFloat) -> CGPoint {
            var i = 1
            while i < lengths.count - 1, lengths[i] < length { i += 1 }
            let seg = max(lengths[i] - lengths[i - 1], 0.0001)
            let t = (length - lengths[i - 1]) / seg
            return CGPoint(x: points[i-1].x + (points[i].x - points[i-1].x) * t, y: points[i-1].y + (points[i].y - points[i-1].y) * t)
        }
        let out = CGMutablePath()
        out.move(to: point(at: a))
        for i in 1..<points.count where lengths[i] > a && lengths[i] < b { out.addLine(to: points[i]) }
        out.addLine(to: point(at: b))
        return out
    }

    /// Rounded rectangle starting at the top or bottom center, running clockwise as seen on screen.
    /// The status bar button's layer is flipped (origin top-left), so minY is the visual top.
    private static func clockwisePath(in r: NSRect, radius: CGFloat, anchor: OutlineStyle.Anchor) -> CGPath {
        let p = CGMutablePath()
        if anchor == .top {
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: radius)
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: radius)
            p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: radius)
            p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.midX, y: r.minY), radius: radius)
            p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        } else {
            p.move(to: CGPoint(x: r.midX, y: r.maxY))
            p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: radius)
            p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: radius)
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: radius)
            p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.midX, y: r.maxY), radius: radius)
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        }
        return p
    }
}
