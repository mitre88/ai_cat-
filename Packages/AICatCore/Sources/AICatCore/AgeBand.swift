import Foundation

/// Age bands chosen by the adult in the parent zone. They set the starting difficulty and the
/// pedagogical scaffolding (automatic hints, timers, amount of text).
public enum AgeBand: String, Codable, CaseIterable, Sendable, Identifiable {
    case explorer      // 6–7
    case apprentice    // 8–10
    case master        // 11–12

    public var id: String { rawValue }

    public var ageRange: ClosedRange<Int> {
        switch self {
        case .explorer: return 6...7
        case .apprentice: return 8...10
        case .master: return 11...12
        }
    }

    /// d₀ of the adaptive difficulty model.
    public var initialDifficulty: Double {
        switch self {
        case .explorer: return 0.20
        case .apprentice: return 0.45
        case .master: return 0.70
        }
    }

    /// Explorers always get a hint after the first mistake; others ask for it.
    public var autoHints: Bool { self == .explorer }

    /// Only masters see a (gentle) timer.
    public var usesTimer: Bool { self == .master }

    /// Maximum spoken sentence length AI CAT should use (words).
    public var maxSentenceWords: Int {
        switch self {
        case .explorer: return 8
        case .apprentice: return 14
        case .master: return 20
        }
    }

    public var titleKey: TextKey {
        switch self {
        case .explorer: return TextKey("ageband.explorer.title")
        case .apprentice: return TextKey("ageband.apprentice.title")
        case .master: return TextKey("ageband.master.title")
        }
    }

    public var descriptionKey: TextKey {
        switch self {
        case .explorer: return TextKey("ageband.explorer.description")
        case .apprentice: return TextKey("ageband.apprentice.description")
        case .master: return TextKey("ageband.master.description")
        }
    }

    public static func forAge(_ age: Int) -> AgeBand {
        if age <= 7 { return .explorer }
        if age <= 10 { return .apprentice }
        return .master
    }
}
