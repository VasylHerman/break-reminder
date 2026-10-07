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
        let idle = NSColor.labelColor.withAlphaComponent(highContrast ? 0.7 : ScoreHeart.outlineOpacity)
        let colored = highContrast ? 1.0 : ScoreHeart.coloredOutlineOpacity
        switch (self, phase) {
        case (_, .over): return .systemRed.withAlphaComponent(colored)
        case (.quiet, .working): return idle
        case (.quiet, .warning): return .systemOrange.withAlphaComponent(colored)
        case (.signal, .working): return idle
        case (.signal, .warning): return .systemOrange.withAlphaComponent(colored)
        case (.accent, .working): return .controlAccentColor.withAlphaComponent(ScoreHeart.outlineOpacity)
        case (.accent, .warning): return .controlAccentColor.withAlphaComponent(colored)
        case (_, .resting): return idle
        }
    }
}
