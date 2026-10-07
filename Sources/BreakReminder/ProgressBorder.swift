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
        let range: (start: Double, end: Double)?
        if let progress, progress >= 1, style != .off {
            range = (0, 1)
        } else if let progress {
            range = style.strokeRange(progress: progress)
        } else {
            range = nil
        }
        guard let range else {
            shape.isHidden = true
            return
        }
        shape.isHidden = false
        shape.strokeColor = color.cgColor
        shape.strokeStart = CGFloat(range.start)
        shape.strokeEnd = CGFloat(range.end)
        layout()
    }

    /// Fit the outline around the text, centered in the button.
    @objc private func layout() {
        guard let button, let title = button.attributedTitle as NSAttributedString? else { return }
        let textSize = title.size()
        let width = ceil(textSize.width) + 8
        let height = ceil(textSize.height) + 2
        let rect = NSRect(
            x: (button.bounds.width - width) / 2,
            y: (button.bounds.height - height) / 2,
            width: width,
            height: height
        ).insetBy(dx: shape.lineWidth / 2, dy: shape.lineWidth / 2)
        shape.frame = button.bounds
        shape.path = Self.clockwisePath(in: rect, radius: min(6, rect.height / 2))
    }

    /// Rounded rectangle starting at the top center, running clockwise (layer coordinates are y-up).
    private static func clockwisePath(in r: NSRect, radius: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.maxY))
        p.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius,
                 startAngle: .pi / 2, endAngle: 0, clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + radius))
        p.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius,
                 startAngle: 0, endAngle: -.pi / 2, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius,
                 startAngle: -.pi / 2, endAngle: -.pi, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - radius))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius,
                 startAngle: .pi, endAngle: .pi / 2, clockwise: true)
        p.closeSubpath()
        return p
    }
}
