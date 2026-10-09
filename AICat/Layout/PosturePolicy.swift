import SwiftUI

/// Pure decision: which posture a container is in, from its size, size class and the active fold.
/// Kept free of iPhone Duo APIs so it compiles everywhere and can be reasoned about on paper:
///   active division wider than tall  → tabletop ("lab"): stage above the fold, board below
///   active division taller than wide → book: board on one page, stage on the other
///   no active division               → regular width ? world : pocket
enum PosturePolicy {
    static func posture(size: CGSize, activeDivision: CGRect?, isRegularWidth: Bool) -> StagePosture {
        if let division = activeDivision, division.width > 0 || division.height > 0 {
            if division.width >= division.height {
                return .lab(division: division)
            }
            return .book(division: division)
        }
        return isRegularWidth ? .world : .pocket
    }

    static func info(size: CGSize, activeDivision: CGRect?, isRegularWidth: Bool, hingeAngleDegrees: Double?) -> PostureInfo {
        PostureInfo(
            posture: posture(size: size, activeDivision: activeDivision, isRegularWidth: isRegularWidth),
            hingeAngleDegrees: hingeAngleDegrees,
            containerSize: size
        )
    }
}
