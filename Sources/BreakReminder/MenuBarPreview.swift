import SwiftUI

/// Animated mock of the menu bar item: plays a whole work block in a loop so the chosen
/// outline style, unit, warning color and blink can be seen before they happen for real.
struct MenuBarPreview: View {
    let theme: Theme
    let style: OutlineStyle
    let counterStyle: CounterStyle
    /// Weekly score to show as a heart, nil hides it.
    let score: Double?
    let blink: Bool
    let workLimit: Int
    let warnBefore: Int

    private let blockDuration = 7.0   // seconds for 0 -> limit
    private let overDuration = 2.5    // seconds shown in the over-limit state
    private let restDuration = 2.5    // seconds shown resting
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: blockDuration + overDuration + restDuration)
            let progress = min(t / blockDuration, 1)
            let resting = t >= blockDuration + overDuration
            let over = t >= blockDuration && !resting
            let minutesLeft = Double(workLimit) * (1 - progress)
            let warning = !over && warnBefore > 0 && minutesLeft <= Double(warnBefore)
            let elapsedSeconds = resting ? (t - blockDuration - overDuration) * 120
                : (over ? Double(workLimit * 60) + (t - blockDuration) * 60 : progress * Double(workLimit) * 60)

            let phase: CounterPhase = resting ? .resting : (over ? .over : (warning ? .warning : .working))
            let highContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            let textColor = Color(nsColor: theme.textColor(for: phase))
            let outlineColor = Color(nsColor: theme.outlineColor(for: phase, highContrast: highContrast, glyph: counterStyle.isGlyph))
            let outlineWidth: CGFloat = highContrast ? 2 : 1
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let opacity = blinkOpacity(t: t, active: blink && !reduceMotion && (warning || over), fast: over)

            HStack(spacing: 14) {
                if let score, counterStyle != .heart {
                    ScoreHeartView(fill: score, color: theme.textColor(for: phase))
                        .padding(.trailing, -9)
                        .opacity(opacity)
                }
                if counterStyle == .heart {
                    // The same centered canvas the menu bar uses, so the ring sits on the heart's ink.
                    Image(nsImage: ScoreHeart.canvas(fill: score ?? 0, color: .labelColor, canvas: 22) ?? NSImage())
                        .frame(width: 22, height: 22)
                        .overlay {
                            if !resting {
                                Outline(stroke: outlineStroke(progress: progress, over: over), circular: true)
                                    .stroke(outlineColor, style: StrokeStyle(lineWidth: outlineWidth, lineCap: .round))
                            }
                        }
                        .opacity(opacity)
                } else if counterStyle == .hidden {
                    Circle()
                        .fill((phase == .working ? Color.primary : outlineColor).opacity(ScoreHeart.levelOpacity))
                        .frame(width: 7, height: 7)
                        .frame(width: 16, height: 16)
                        .overlay {
                            Outline(stroke: outlineStroke(progress: progress, over: over), circular: true)
                                .stroke(outlineColor, style: StrokeStyle(lineWidth: outlineWidth, lineCap: .round))
                        }
                        .opacity(opacity)
                } else {
                    Text(TimeFormat.counter(elapsedSeconds, showUnit: counterStyle == .numberWithUnit))
                        .font(.system(size: 13, weight: .regular).monospacedDigit())
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .overlay {
                            Outline(stroke: outlineStroke(progress: progress, over: over))
                                .stroke(outlineColor, style: StrokeStyle(lineWidth: outlineWidth, lineCap: .round))
                        }
                        .opacity(opacity)
                }
                Group {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75percent")
                    Text(context.date, format: .dateTime.hour().minute())
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(.bar, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
        }
    }

    private func outlineStroke(progress: Double, over: Bool) -> (anchor: OutlineStyle.Anchor, start: Double, end: Double)? {
        if style == .off || progress == 0 && !over { return nil }
        if over { return (.top, 0, 1) }
        return style.stroke(progress: progress)
    }

    /// Fade to 25% and back over 0.4 s, once per second in the warning and twice per second over the limit.
    private func blinkOpacity(t: Double, active: Bool, fast: Bool) -> Double {
        guard active else { return 1 }
        let period = fast ? 0.5 : 1.0
        let phase = t.truncatingRemainder(dividingBy: period)
        guard phase < 0.4 else { return 1 }
        let x = phase / 0.4                       // 0 -> 1 across the blink
        return 1 - 0.75 * sin(x * .pi)            // dip to 0.25 at the middle
    }
}

/// Rounded outline starting at the top or bottom center and running clockwise, trimmed to the stroke range.
private struct Outline: Shape {
    let stroke: (anchor: OutlineStyle.Anchor, start: Double, end: Double)?
    var circular = false

    func path(in rect: CGRect) -> Path {
        guard let stroke else { return Path() }
        let r = rect.insetBy(dx: 0.75, dy: 0.75)
        let radius = circular ? r.height / 2 : min(6, r.height / 2)
        var p = Path()
        if stroke.anchor == .top {
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
        return p.trimmedPath(from: stroke.start, to: stroke.end)
    }
}

/// The menu bar heart image, so the preview and the Stats headline show exactly what the bar shows.
struct ScoreHeartView: View {
    let fill: Double
    var size: CGFloat = 11
    var weight: NSFont.Weight = .regular
    var color: NSColor = .labelColor
    var outlineOpacity: CGFloat = ScoreHeart.outlineOpacity

    var body: some View {
        if let image = ScoreHeart.image(fill: fill, color: color, pointSize: size, weight: weight, outlineOpacity: outlineOpacity) {
            Image(nsImage: image)
        }
    }
}
