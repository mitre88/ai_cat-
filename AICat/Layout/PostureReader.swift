import SwiftUI
import AICatCore

/// Resolves the current `PostureInfo` for its container and hands it to `content`.
/// Without the iPhone Duo SDK the posture comes from size classes only.
struct PostureReader<Content: View>: View {
    @ViewBuilder let content: (PostureInfo) -> Content

    var body: some View {
        #if AICAT_DUO
        if #available(iOS 27.1, *) {
            DuoPostureProvider(content: content)
        } else {
            SizeClassPostureProvider(content: content)
        }
        #else
        SizeClassPostureProvider(content: content)
        #endif
    }
}

/// Size-class based posture: compact width → pocket, regular width → world.
struct SizeClassPostureProvider<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let content: (PostureInfo) -> Content

    var body: some View {
        GeometryReader { proxy in
            let info = PosturePolicy.info(size: proxy.size, activeDivision: nil, isRegularWidth: horizontalSizeClass == .regular, hingeAngleDegrees: nil)
            content(info)
                .environment(\.postureInfo, info)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
