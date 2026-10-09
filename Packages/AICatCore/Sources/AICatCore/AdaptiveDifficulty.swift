import Foundation

/// Zone-of-proximal-development controller: nudges difficulty so the child succeeds ~75 % of the time.
///   d_{n+1} = clamp(d_n + K · (s_n − τ), 0, 1)     K = 0.15, τ = 0.75
public struct AdaptiveDifficulty: Codable, Equatable, Sendable {
    public static let targetSuccess = 0.75
    public static let gain = 0.15

    public private(set) var value: Double

    public init(band: AgeBand) {
        value = band.initialDifficulty
    }

    public init(value: Double) {
        self.value = GrowthModel.clamp(value, 0, 1)
    }

    /// Feed the accuracy (0…1) of the challenge that just ended.
    public mutating func update(accuracy: Double) {
        value = GrowthModel.clamp(value + Self.gain * (accuracy - Self.targetSuccess), 0, 1)
    }

    /// n(d) = round(n_min + (n_max − n_min) · d), rounding half up.
    public func itemCount(in range: ClosedRange<Int>) -> Int {
        let lo = Double(range.lowerBound)
        let hi = Double(range.upperBound)
        return Int((lo + (hi - lo) * value + 0.5).rounded(.down))
    }

    /// How many distractors (0…max) to add.
    public func distractorCount(max: Int) -> Int {
        Int((Double(max) * value + 0.5).rounded(.down))
    }

    /// Coarse label for debugging / parent zone.
    public var tier: Int {
        if value < 0.34 { return 1 }
        if value < 0.67 { return 2 }
        return 3
    }
}
