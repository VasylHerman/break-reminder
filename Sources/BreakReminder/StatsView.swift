import SwiftUI

/// Day, week and month figures. Refreshes every few seconds while open.
struct StatsView: View {
    let history: History
    let liveProvider: () -> (ActivityTracker.Snapshot?, Date?)

    @State private var period: Stats.Period = .day
    @State private var summary = Stats.Summary()
    private let refresh = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Picker("Period", selection: $period) {
                ForEach(Stats.Period.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                row("Focused", TimeFormat.minutes(summary.work))
                row("Resting", TimeFormat.minutes(summary.rest))
                row("Longest block", TimeFormat.minutes(summary.longestWork))
                Divider().gridCellUnsizedAxes(.horizontal)
                row("Breaks taken", summary.due > 0 ? "\(summary.taken) of \(summary.due)" : "–")
                row("On time", summary.adherence.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                if period != .day {
                    row("Good days", "\(summary.goodDays) of \(summary.activeDays)")
                }
                row("Streak", summary.streak == 1 ? "1 day" : "\(summary.streak) days")
            }
            .font(.body)

            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .padding(24)
        .frame(width: 400)
        .onAppear(perform: reload)
        .onChange(of: period) { _ in reload() }
        .onReceive(refresh) { _ in reload() }
    }

    private var explanation: String {
        switch period {
        case .day: return "A break counts as on time when a rest starts within 5 minutes of the limit, half when within 15. Breaks held by Smart Pause are not counted against you."
        case .week: return "Calendar week. A good day is one with at least one break and 75% or better on time. The streak counts good days in a row."
        case .month: return "Calendar month to date. Daily history is kept for about two months and then dropped."
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func reload() {
        let (snapshot, blockStart) = liveProvider()
        summary = Stats.summary(period: period, history: history, live: snapshot, blockStart: blockStart)
    }
}
