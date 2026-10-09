import SwiftUI
import AICatCore

// `StagePosture`, `PostureInfo` and `PosturePolicy` live in AICatCore (tested on any platform).
// This file only exposes the posture to SwiftUI views.

private struct PostureInfoKey: EnvironmentKey {
    static let defaultValue = PostureInfo.fallback
}

extension EnvironmentValues {
    var postureInfo: PostureInfo {
        get { self[PostureInfoKey.self] }
        set { self[PostureInfoKey.self] = newValue }
    }
}
