#if AICAT_DUO
import SwiftUI
import AICatCore

/// Soft shadow drawn along the fold so the two halves read as one scene.
struct FoldGap: View {
    let isHorizontal: Bool

    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0), .black.opacity(0.10), .black.opacity(0)],
            startPoint: isHorizontal ? .top : .leading,
            endPoint: isHorizontal ? .bottom : .trailing
        )
        .allowsHitTesting(false)
    }
}

#if DEBUG
/// Small badge with the current posture and hinge angle (debug builds only).
struct HingeDebugBadge: View {
    let info: PostureInfo

    var body: some View {
        let angle = info.hingeAngleDegrees.map { String(format: "%.0f°", $0) } ?? "–"
        Text("\(info.posture.debugName) · \(angle)")
            .font(.caption2.monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .allowsHitTesting(false)
    }
}
#endif
#endif
