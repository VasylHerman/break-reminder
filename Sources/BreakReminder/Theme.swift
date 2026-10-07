import AppKit

/// What the counter is signalling right now.
enum CounterPhase {
    case working, warning, over, resting
}

/// Curated looks for the menu bar item. Colors come from the system palette so they adapt
/// to light and dark menu bars and to the user's accent color.
enum Theme: String, CaseIterable, Identifiable {
    /// Monochrome number; only the outline carries the state. Red once over the limit.
    case quiet
    /// Traffic light: orange warning, red over, green resting, on number and outline.
    case signal
    /// The user's macOS accent color for the warning and the outline, red once over.
    case accent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quiet: return "Quiet"
        case .signal: return "Signal"
        case .accent: return "Accent"
        }
    }

    var summary: String {
        switch self {
        case .quiet: return "Monochrome number, the outline carries the state. Red only once you are over."
        case .signal: return "Orange warning, red over, green rest, on number and outline."
        case .accent: return "Your Mac's accent color for the warning and the outline, red once you are over."
        }
    }

    func textColor(for phase: CounterPhase) -> NSColor {
        switch (self, phase) {
        case (_, .over): return .systemRed
        case (.quiet, .working), (.quiet, .warning): return .labelColor
        case (.quiet, .resting): return .secondaryLabelColor
        case (.signal, .working): return .labelColor
        case (.signal, .warning): return .systemOrange
        case (.signal, .resting): return .systemGreen
        case (.accent, .working): return .labelColor
        case (.accent, .warning): return .controlAccentColor
        case (.accent, .resting): return .secondaryLabelColor
        }
    }

    /// Outline tones follow the heart: the body at 40% of the label color while working, colored states
    /// at 65%, like the battery's lighter body around its solid level. `glyph` is kept for callers.
    func outlineColor(for phase: CounterPhase, highContrast: Bool, glyph: Bool = false) -> NSColor {
        let idle = Self.faded(.labelColor, highContrast ? 0.7 : ScoreHeart.outlineOpacity)
        let colored = highContrast ? 1.0 : ScoreHeart.coloredOutlineOpacity
        switch (self, phase) {
        case (_, .over): return Self.faded(.systemRed, colored)
        case (.quiet, .working): return idle
        case (.quiet, .warning): return Self.faded(.systemOrange, colored)
        case (.signal, .working): return idle
        case (.signal, .warning): return Self.faded(.systemOrange, colored)
        case (.accent, .working): return Self.faded(.controlAccentColor, ScoreHeart.outlineOpacity)
        case (.accent, .warning): return Self.faded(.controlAccentColor, colored)
        case (_, .resting): return idle
        }
    }

    /// A dynamic color at reduced opacity. `withAlphaComponent` alone bakes the color under the
    /// appearance current at the call, which is the app's, not the menu bar's; a provider resolves
    /// it where it is drawn.
    static func faded(_ color: NSColor, _ alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { _ in color.withAlphaComponent(alpha) }
    }
}
