import Charts
import SwiftUI

/// Day, week and month: a headline, a visual, then the figures. Refreshes every few seconds while open.
struct StatsView: View {
    let history: History
    let liveProvider: () -> (ActivityTracker.Snapshot?, Date?)

    @State private var period: Stats.Period = .day
    @State private var summary = Stats.Summary()
    @State private var previous = Stats.Summary()
    @State private var rows: [Stats.DayRow] = []
    @State private var blocks: [History.Block] = []
    @State private var skippedAt: [Date] = []
    @State private var live: (ActivityTracker.Snapshot?, Date?) = (nil, nil)
    @State private var hoverText: String?
    private let refresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Period", selection: $period) {
                ForEach(Stats.Period.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .frame(maxWidth: .infinity)

            // Headline with the score heart, the same glyph as the menu bar.
            HStack(alignment: .top, spacing: 12) {
                ScoreHeartView(fill: summary.adherence ?? 0, size: 24)
                    .foregroundStyle(summary.adherence == nil ? Color.secondary : Color.primary)
                    .frame(width: 32, height: 32)
                    .help(summary.adherence.map { "On time \(Int(($0 * 100).rounded()))%" } ?? "No breaks due yet")
                Text(Stats.headline(period: period, summary: summary, previous: previous, longestStart: longestStart))
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            visual
                .frame(height: period == .month ? 150 : 110, alignment: .top)

            Text(hoverText ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, -8)

            figures
        }
        .padding(20)
        .frame(width: 460)
        .onAppear(perform: reload)
        .onChange(of: period) { _ in hoverText = nil; reload() }
        .onReceive(refresh) { _ in reload() }
    }

    // MARK: Visuals

    @ViewBuilder
    private var visual: some View {
        switch period {
        case .day:
            DayTimeline(blocks: blocks, live: live, skippedAt: skippedAt, hoverText: $hoverText)
        case .week:
            weekBars
        case .month:
            MonthGrid(rows: rows, hoverText: $hoverText)
        }
    }

    private var weekBars: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return Chart(rows) { row in
            BarMark(x: .value("Day", formatter.string(from: row.date)), y: .value("Focused", row.work / 60))
                .foregroundStyle(row.isToday ? Color.accentColor : Color.accentColor.opacity(0.5))
                .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) { Text(TimeFormat.minutes(minutes * 60)) }
                }
            }
        }
        .chartXAxis { AxisMarks { _ in AxisValueLabel() } }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            let x = point.x - geo[proxy.plotAreaFrame].origin.x
                            if let label: String = proxy.value(atX: x),
                               let row = rows.first(where: { formatter.string(from: $0.date) == label }) {
                                hoverText = Self.describe(row)
                            }
                        case .ended:
                            hoverText = nil
                        }
                    }
            }
        }
    }

    static func describe(_ row: Stats.DayRow) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM"
        var text = "\(f.string(from: row.date)): focused \(TimeFormat.minutes(row.day.work))"
        if row.day.due > 0 {
            text += ", \(row.day.taken) of \(row.day.due) breaks"
            if let a = row.day.adherence { text += ", \(Int((a * 100).rounded()))% on time" }
        } else if row.day.work == 0 {
            text = "\(f.string(from: row.date)): nothing recorded"
        }
        return text
    }

    // MARK: Figures

    private var figures: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                figure("Focused", TimeFormat.minutes(summary.work), delta: period == .month ? nil : deltaMinutes(summary.work - previous.work))
                figure("Breaks taken", summary.due > 0 ? "\(summary.taken) of \(summary.due)" : "–", delta: nil)
            }
            GridRow {
                figure("Resting", TimeFormat.minutes(summary.rest), delta: nil)
                figure("On time", summary.adherence.map { "\(Int(($0 * 100).rounded()))%" } ?? "–",
                       delta: deltaPercent, help: "On time: a rest starts within 5 minutes of the limit. Half credit within 15. Breaks held by Smart Pause are not counted against you.")
            }
            GridRow {
                figure("Longest block", TimeFormat.minutes(summary.longestWork), delta: nil)
                figure("Streak", summary.streak == 1 ? "1 day" : "\(summary.streak) days", delta: nil,
                       help: "Days in a row with at least one break and 75% or better on time.")
            }
        }
    }

    private func figure(_ label: String, _ value: String, delta: String?, help: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                if let help {
                    Image(systemName: "info.circle").font(.caption2).foregroundStyle(.tertiary).help(help)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.title3.weight(.medium)).monospacedDigit()
                if let delta { Text(delta).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deltaPercent: String? {
        guard let now = summary.adherence, let before = previous.adherence else { return nil }
        let delta = Int(((now - before) * 100).rounded())
        return delta == 0 ? "±0" : (delta > 0 ? "+\(delta)" : "\(delta)")
    }

    private func deltaMinutes(_ seconds: TimeInterval) -> String? {
        guard previous.work > 0 || summary.work > 0 else { return nil }
        let minutes = Int(seconds / 60)
        if minutes == 0 { return "±0" }
        return (minutes > 0 ? "+" : "−") + TimeFormat.minutes(TimeInterval(abs(minutes) * 60))
    }

    private var longestStart: Date? {
        var candidates = blocks.filter { $0.kind == .working }.map { ($0.start, $0.end.timeIntervalSince($0.start)) }
        if let snapshot = live.0, let start = live.1, snapshot.state == .working {
            candidates.append((start, snapshot.currentSeconds))
        }
        return candidates.max { $0.1 < $1.1 }?.0
    }

    // MARK: Data

    private func reload() {
        live = liveProvider()
        summary = Stats.summary(period: period, history: history, live: live.0, blockStart: live.1)
        previous = Stats.previousSummary(period: period, history: history)
        rows = Stats.dayRows(period: period, history: history, live: live.0, blockStart: live.1)
        let today = Stats.interval(for: .day)
        blocks = history.blocks(in: today)
        skippedAt = history.events(in: today).filter { $0.outcome == .skipped }.map(\.dueAt)
    }
}

/// Today as a strip: work blocks in the label color, rests in green, a red tick where a break was skipped.
private struct DayTimeline: View {
    let blocks: [History.Block]
    let live: (ActivityTracker.Snapshot?, Date?)
    let skippedAt: [Date]
    @Binding var hoverText: String?

    private var range: DateInterval? {
        let now = Date()
        var starts = blocks.map(\.start)
        if let start = live.1, live.0 != nil { starts.append(start) }
        guard let first = starts.min() else { return nil }
        return DateInterval(start: first, end: max(now, first.addingTimeInterval(60)))
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func x(_ date: Date, in range: DateInterval, width: CGFloat) -> CGFloat {
        width * CGFloat(date.timeIntervalSince(range.start) / range.duration)
    }

    var body: some View {
        GeometryReader { geo in
            if let range {
                let width = geo.size.width
                let trackY = geo.size.height * 0.45
                let trackHeight: CGFloat = 18
                let f = Self.timeFormatter
                ZStack(alignment: .topLeading) {
                    // Track.
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: width, height: trackHeight)
                        .offset(y: trackY)
                    // Finished blocks, 2 px of surface between them.
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        let x0 = x(max(block.start, range.start), in: range, width: width)
                        let x1 = x(block.end, in: range, width: width)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(block.kind == .working ? Color.primary.opacity(0.55) : Color.green.opacity(0.8))
                            .frame(width: max(2, x1 - x0 - 2), height: trackHeight)
                            .offset(x: x0 + 1, y: trackY)
                    }
                    // The running block.
                    if let snapshot = live.0, let start = live.1 {
                        let x0 = x(start, in: range, width: width)
                        let x1 = x(range.end, in: range, width: width)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(snapshot.state == .working ? Color.primary.opacity(0.55) : Color.green.opacity(0.8))
                            .frame(width: max(2, x1 - x0 - 2), height: trackHeight)
                            .offset(x: x0 + 1, y: trackY)
                    }
                    // Skipped breaks.
                    ForEach(Array(skippedAt.enumerated()), id: \.offset) { _, date in
                        Capsule().fill(Color.red)
                            .frame(width: 2, height: 8)
                            .offset(x: x(date, in: range, width: width) - 1, y: trackY - 12)
                    }
                    // Time labels.
                    Text(f.string(from: range.start)).font(.caption2).foregroundStyle(.secondary)
                        .offset(y: trackY + trackHeight + 6)
                    Text("now").font(.caption2).foregroundStyle(.secondary)
                        .frame(width: width, alignment: .trailing)
                        .offset(y: trackY + trackHeight + 6)
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        let date = range.start.addingTimeInterval(range.duration * Double(point.x / width))
                        hoverText = describe(at: date, formatter: f)
                    case .ended:
                        hoverText = nil
                    }
                }
            } else {
                Text("The timeline fills in as you work: focus in grey, rests in green, skipped breaks as red ticks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func describe(at date: Date, formatter: DateFormatter) -> String? {
        if let block = blocks.first(where: { $0.start <= date && date <= $0.end }) {
            let kind = block.kind == .working ? "Focus" : "Rest"
            return "\(kind) \(formatter.string(from: block.start)) to \(formatter.string(from: block.end)), \(TimeFormat.minutes(block.end.timeIntervalSince(block.start)))"
        }
        if let snapshot = live.0, let start = live.1, date >= start {
            let kind = snapshot.state == .working ? "Focus" : "Rest"
            return "\(kind) since \(formatter.string(from: start)), \(TimeFormat.minutes(snapshot.currentSeconds)) so far"
        }
        return nil
    }
}

/// The month as a calendar grid, each day tinted by its on-time share.
private struct MonthGrid: View {
    let rows: [Stats.DayRow]
    @Binding var hoverText: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let calendar = Calendar.current
        let leading = rows.first.map { (calendar.component(.weekday, from: $0.date) - calendar.firstWeekday + 7) % 7 } ?? 0
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Text(calendar.veryShortWeekdaySymbols[(calendar.firstWeekday - 1 + i) % 7])
                        .font(.caption2).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 18) }
                ForEach(rows) { row in
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(fill(for: row))
                        if row.isToday {
                            RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.5), lineWidth: 1)
                        }
                        Text("\(calendar.component(.day, from: row.date))")
                            .font(.caption2)
                            .foregroundStyle(row.date > Date() ? .quaternary : .secondary)
                    }
                    .frame(height: 18)
                    .onHover { inside in hoverText = inside ? StatsView.describe(row) : nil }
                }
            }
        }
    }

    /// Sequential: one hue, light to dark with the on-time share. No breaks due: a faint surface.
    private func fill(for row: Stats.DayRow) -> Color {
        if let adherence = row.day.adherence {
            return Color.green.opacity(0.18 + 0.62 * adherence)
        }
        return Color.primary.opacity(row.day.work > 0 ? 0.08 : 0.04)
    }
}
