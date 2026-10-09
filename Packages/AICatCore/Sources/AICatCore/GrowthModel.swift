import Foundation

/// How accumulated XP turns into AI CAT's growth.
///
/// Growth is linear in XP, normalised to 80 % of the theoretical maximum (10 scenarios × 900 XP),
/// so a child who plays imperfectly still reaches adulthood. Each 720 XP is one visible stage;
/// finishing a scenario (≈ 720–900 XP) is designed to land exactly one stage up.
/// Mirrors `Tools/reference_model.py` (golden-tested).
public enum GrowthModel {
    public static let maxXP: Double = 9000
    public static let normalizationXP: Double = 7200
    public static let stageCount = 10

    /// ĝ ∈ [0, 1]
    public static func normalizedGrowth(xp: Double) -> Double {
        clamp(xp / normalizationXP, 0, 1)
    }

    /// 0 (newborn) … 10 (expert).
    public static func stage(xp: Double) -> Int {
        let raw = (normalizedGrowth(xp: xp) * Double(stageCount) + 1e-9).rounded(.down)
        return min(stageCount, Int(raw))
    }

    /// Smallest XP that reaches `stage`.
    public static func xpForStage(_ stage: Int) -> Double {
        Double(clamp(stage, 0, stageCount)) * normalizationXP / Double(stageCount)
    }

    /// Fraction of the way from the current stage to the next (for progress bars).
    public static func progressWithinStage(xp: Double) -> Double {
        if xp >= normalizationXP { return 1 }
        let width = normalizationXP / Double(stageCount)
        return clamp((xp - xpForStage(stage(xp: xp))) / width, 0, 1)
    }

    /// Hermite smoothstep, used to ease morphology changes.
    public static func smoothstep(_ t: Double) -> Double {
        let x = clamp(t, 0, 1)
        return x * x * (3 - 2 * x)
    }

    @inlinable
    public static func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }
}
