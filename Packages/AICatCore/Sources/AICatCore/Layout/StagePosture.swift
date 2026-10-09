import Foundation

/// How the screen is being held. Drives where the 3D stage and the challenge board go.
public enum StagePosture: Equatable, Sendable {
    /// Compact width: closed iPhone Duo or any iPhone in portrait. Stage on top, board below.
    case pocket
    /// Regular width, flat: open iPhone Duo (or a large iPhone in landscape). Board beside the stage.
    case world
    /// Partially folded with a horizontal fold ("tabletop"): stage above the fold, controls below it.
    case lab(division: CGRect)
    /// Partially folded with a vertical fold ("book"): board on one page, stage on the other.
    case book(division: CGRect)

    public var isFolded: Bool {
        switch self {
        case .lab, .book: return true
        case .pocket, .world: return false
        }
    }

    public var debugName: String {
        switch self {
        case .pocket: return "pocket"
        case .world: return "world"
        case .lab: return "lab"
        case .book: return "book"
        }
    }
}

public struct PostureInfo: Equatable, Sendable {
    public var posture: StagePosture
    /// Live hinge angle in degrees (180 = flat). nil without a hinge.
    public var hingeAngleDegrees: Double?
    public var containerSize: CGSize

    public init(posture: StagePosture, hingeAngleDegrees: Double?, containerSize: CGSize) {
        self.posture = posture
        self.hingeAngleDegrees = hingeAngleDegrees
        self.containerSize = containerSize
    }

    public static let fallback = PostureInfo(posture: .pocket, hingeAngleDegrees: nil, containerSize: .zero)

    /// 0 = closed … 1 = flat. Used only for effects (sunrise, gaze), never for layout.
    public var openness: Double {
        guard let angle = hingeAngleDegrees else { return 1 }
        return min(max((angle - 90) / 90, 0), 1)
    }
}

/// Pure decision: which posture a container is in, from its size, size class and the active fold.
///   active division wider than tall  → tabletop ("lab"): stage above the fold, board below
///   active division taller than wide → book: board on one page, stage on the other
///   no active division               → regular width ? world : pocket
public enum PosturePolicy {
    public static func posture(size: CGSize, activeDivision: CGRect?, isRegularWidth: Bool) -> StagePosture {
        if let division = activeDivision, division.width > 0 || division.height > 0 {
            if division.width >= division.height {
                return .lab(division: division)
            }
            return .book(division: division)
        }
        return isRegularWidth ? .world : .pocket
    }

    public static func info(size: CGSize, activeDivision: CGRect?, isRegularWidth: Bool, hingeAngleDegrees: Double?) -> PostureInfo {
        PostureInfo(
            posture: posture(size: size, activeDivision: activeDivision, isRegularWidth: isRegularWidth),
            hingeAngleDegrees: hingeAngleDegrees,
            containerSize: size
        )
    }
}
