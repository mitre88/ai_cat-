#if AICAT_DUO
import SwiftUI

/// Debug overlay that outlines the fold and the camera cut-outs. Only compiled in debug builds.
#if DEBUG
@available(iOS 27.1, *)
struct ReservedRegionsOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let divisions = proxy.reservedRegions(kind: .division, options: [.includeInactive])
            let occlusions = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
            ZStack(alignment: .topLeading) {
                ForEach(divisions) { region in
                    Rectangle()
                        .stroke(region.isActive ? Color.orange : Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .frame(width: max(region.frame.width, 1), height: max(region.frame.height, 1))
                        .offset(x: region.frame.minX, y: region.frame.minY)
                }
                ForEach(occlusions) { region in
                    Rectangle()
                        .stroke(Color.purple.opacity(0.6), lineWidth: 1)
                        .frame(width: max(region.frame.width, 1), height: max(region.frame.height, 1))
                        .offset(x: region.frame.minX, y: region.frame.minY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
#endif
#endif
