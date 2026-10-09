import SwiftUI

/// Resolves the current `PostureInfo` for its container and hands it to `content`.
/// Without the iPhone Duo SDK the posture comes from size classes only.
struct PostureReader<Content: View>: View {
    @ViewBuilder let content: (PostureInfo) -> Content

    var body: some View {
        SizeClassPostureProvider(content: content)
    }
}

/// Size-class based posture: compact width → pocket, regular width → world.
struct SizeClassPostureProvider<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let content: (PostureInfo) -> Content

    var body: some View {
        GeometryReader { proxy in
            let posture: StagePosture = (horizontalSizeClass == .regular) ? .world : .pocket
            let info = PostureInfo(posture: posture, hingeAngleDegrees: nil, containerSize: proxy.size)
            content(info)
                .environment(\.postureInfo, info)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
