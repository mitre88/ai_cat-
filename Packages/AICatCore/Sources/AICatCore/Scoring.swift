import Foundation

/// Outcome of one played challenge.
public struct ChallengeResult: Codable, Hashable, Sendable {
    public let challengeID: String
    public let accuracy: Double
    public let hintsUsed: Int
    public let durationSeconds: Double
    public let date: Date

    public init(challengeID: String, accuracy: Double, hintsUsed: Int, durationSeconds: Double, date: Date = Date()) {
        self.challengeID = challengeID
        self.accuracy = GrowthModel.clamp(accuracy, 0, 1)
        self.hintsUsed = hintsUsed
        self.durationSeconds = durationSeconds
        self.date = date
    }
}

public enum Scoring {
    /// Minimum accuracy to count a challenge as passed.
    public static let passThreshold = 0.6

    /// xp = 100 · tier · clamp(accuracy, 0.5, 1), rounded half up.
    public static func xp(tier: Int, accuracy: Double) -> Int {
        let a = GrowthModel.clamp(accuracy, 0.5, 1.0)
        return Int((100.0 * Double(tier) * a + 0.5).rounded(.down))
    }

    public static func stars(accuracy: Double) -> Int {
        if accuracy >= 0.95 { return 3 }
        if accuracy >= 0.75 { return 2 }
        return 1
    }

    public static func isPassed(accuracy: Double) -> Bool {
        accuracy >= passThreshold
    }
}
