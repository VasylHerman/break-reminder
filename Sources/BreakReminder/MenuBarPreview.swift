import SwiftUI

/// Animated mock of the menu bar item: plays a whole work block in a loop so the chosen
/// outline style, unit, warning color and blink can be seen before they happen for real.
struct MenuBarPreview: View {
    let style: OutlineStyle
    let showUnit: Bool
    let blink: Bool
    let workLimit: Int
    let warnBefore: Int

    private let blockDuration = 7.0   // seconds for 0 -> limit
    private let overDuration = 2.5    // seconds shown in the over-limit state
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: blockDuration + overDuration)
            let progress = min(t / blockDuration, 1)
            let over = t >= blockDuration
            let minutesLeft = Double(workLimit) * (1 - progress)
            let warning = !over && warnBefore > 0 && minutesLeft <= Double(warnBefore)
            let elapsedSeconds = over ? Double(workLimit * 60) + (t - blockDuration) * 60 : progress * Double(workLimit) * 60

            let textColor: Color = over ? .red : (warning ? .orange : .primary)
            let outlineColor: Color = over ? .red : (warning ? .orange : Color.primary.opacity(0.3))
            let opacity = blinkOpacity(t: t, active: blink && (warning || over), fast: over)

            HStack(spacing: 14) {
                Text(TimeFormat.counter(elapsedSeconds, showUnit: showUnit))
                    .font(.system(size: 13, weight: .regular).monospacedDigit())
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .overlay {
                        Outline(range: outlineRange(progress: progress, over: over))
                            .stroke(outlineColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                    .opacity(opacity)
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

    private func outlineRange(progress: Double, over: Bool) -> (start: Double, end: Double)? {
        if style == .off { return nil }
        if over { return (0, 1) }
        return style.strokeRange(progress: progress)
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

/// Rounded outline starting at the top center and running clockwise, trimmed to `range`.
private struct Outline: Shape {
    let range: (start: Double, end: Double)?

    func path(in rect: CGRect) -> Path {
        guard let range else { return Path() }
        let r = rect.insetBy(dx: 0.75, dy: 0.75)
        let radius = min(6, r.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.midX, y: r.minY), radius: radius)
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        return p.trimmedPath(from: range.start, to: range.end)
    }
}
