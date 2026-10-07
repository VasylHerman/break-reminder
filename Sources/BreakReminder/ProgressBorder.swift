import AppKit
import QuartzCore

/// A thin rounded outline drawn around the status item's text that closes clockwise
/// as the work block approaches the limit.
final class ProgressBorder {
    private let shape = CAShapeLayer()
    private weak var button: NSStatusBarButton?

    init(button: NSStatusBarButton) {
        self.button = button
        button.wantsLayer = true
        shape.fillColor = nil
        shape.lineWidth = 1.5
        shape.lineCap = .round
        shape.strokeStart = 0
        shape.strokeEnd = 0
        button.layer?.addSublayer(shape)
        button.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(layout), name: NSView.frameDidChangeNotification, object: button
        )
    }

    /// `progress` is the block's share of the limit (may exceed 1); nil hides the border.
    func update(progress: Double?, style: OutlineStyle, color: NSColor) {
        // Past the limit every style shows a closed outline, so "over" never looks like "almost".
        let stroke: (anchor: OutlineStyle.Anchor, start: Double, end: Double)?
        if let progress, progress >= 1, style != .off {
            stroke = (.top, 0, 1)
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
        shape.lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 2.5 : 1.5
        shape.strokeColor = color.cgColor
        shape.strokeStart = CGFloat(stroke.start)
        shape.strokeEnd = CGFloat(stroke.end)
        anchor = stroke.anchor
        layout()
    }

    private var anchor: OutlineStyle.Anchor = .top

    /// Diameter of the ring drawn around the dot when the counter is hidden.
    static let ringDiameter: CGFloat = 14

    /// Fit the outline around the text, or draw a ring around the dot when there is no text.
    @objc private func layout() {
        guard let button, let title = button.attributedTitle as NSAttributedString? else { return }
        let rect: NSRect
        let radius: CGFloat
        if title.length == 0 {
            let d = Self.ringDiameter
            rect = NSRect(x: (button.bounds.width - d) / 2, y: (button.bounds.height - d) / 2, width: d, height: d)
                .insetBy(dx: shape.lineWidth / 2, dy: shape.lineWidth / 2)
            radius = rect.height / 2
        } else {
            let textSize = title.size()
            let width = ceil(textSize.width) + 8
            let height = ceil(textSize.height) + 2
            rect = NSRect(
                x: (button.bounds.width - width) / 2,
                y: (button.bounds.height - height) / 2,
                width: width,
                height: height
            ).insetBy(dx: shape.lineWidth / 2, dy: shape.lineWidth / 2)
            radius = min(6, rect.height / 2)
        }
        shape.frame = button.bounds
        shape.path = Self.clockwisePath(in: rect, radius: radius, anchor: anchor)
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
