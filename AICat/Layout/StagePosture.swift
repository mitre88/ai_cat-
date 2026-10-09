import SwiftUI

/// How the screen is being held. Drives where the 3D stage and the challenge board go.
enum StagePosture: Equatable, Sendable {
    /// Compact width: closed iPhone Duo or any iPhone in portrait. Stage on top, board below.
    case pocket
    /// Regular width, flat: open iPhone Duo (or a large iPhone in landscape). Board beside the stage.
    case world
    /// Partially folded with a horizontal fold ("tabletop"): stage above the fold, controls below it.
    case lab(division: CGRect)
    /// Partially folded with a vertical fold ("book"): board on one page, stage on the other.
    case book(division: CGRect)

    var isFolded: Bool {
        switch self {
        case .lab, .book: return true
        case .pocket, .world: return false
        }
    }

    var debugName: String {
        switch self {
        case .pocket: return "pocket"
        case .world: return "world"
        case .lab: return "lab"
        case .book: return "book"
        }
    }
}

struct PostureInfo: Equatable, Sendable {
    var posture: StagePosture
    /// Live hinge angle in degrees (180 = flat). nil without a hinge.
    var hingeAngleDegrees: Double?
    var containerSize: CGSize

    static let fallback = PostureInfo(posture: .pocket, hingeAngleDegrees: nil, containerSize: .zero)

    /// 0 = closed … 1 = flat. Used only for effects (sunrise, gaze), never for layout.
    var openness: Double {
        guard let angle = hingeAngleDegrees else { return 1 }
        return min(max((angle - 90) / 90, 0), 1)
    }
}

private struct PostureInfoKey: EnvironmentKey {
    static let defaultValue = PostureInfo.fallback
}

extension EnvironmentValues {
    var postureInfo: PostureInfo {
        get { self[PostureInfoKey.self] }
        set { self[PostureInfoKey.self] = newValue }
    }
}
