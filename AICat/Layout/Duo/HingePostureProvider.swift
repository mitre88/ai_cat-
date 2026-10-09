#if AICAT_DUO
import SwiftUI
import AICatCore

/// iPhone Duo posture: reads the fold (an active `division` reserved region) for layout and the live
/// hinge angle for effects only, as Apple recommends. Requires the iOS 27.1 SDK (Xcode 27.1).
@available(iOS 27.1, *)
struct DuoPostureProvider<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hinge: DeviceHinge?
    let content: (PostureInfo) -> Content

    var body: some View {
        GeometryReader { proxy in
            let divisions = proxy.reservedRegions(kind: .division)
            let active = divisions.first { $0.isActive }
            let info = PosturePolicy.info(
                size: proxy.size,
                activeDivision: active?.frame,
                isRegularWidth: horizontalSizeClass == .regular,
                hingeAngleDegrees: hinge.map { $0.angle.degrees }
            )
            content(info)
                .environment(\.postureInfo, info)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .animation(.smooth, value: active?.frame)
        }
        .onHingeChange { _, newContext in
            hinge = newContext.hinge
        }
    }
}
#endif
