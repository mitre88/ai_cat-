import SwiftUI

/// Lays out the 3D stage and the challenge board for a posture.
/// Division frames are in the coordinate space of the `PostureReader` container.
struct AdaptiveStage<Stage: View, Board: View>: View {
    let info: PostureInfo
    @ViewBuilder let stage: () -> Stage
    @ViewBuilder let board: () -> Board

    var body: some View {
        switch info.posture {
        case .pocket:
            VStack(spacing: 0) {
                stage()
                    .frame(height: max(info.containerSize.height * 0.42, 220))
                board()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .world:
            HStack(spacing: 0) {
                board()
                    .frame(width: boardWidth)
                stage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .lab(let division):
            VStack(spacing: 0) {
                stage()
                    .frame(height: max(division.minY, 120))
                Color.clear
                    .frame(height: division.height)
                board()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .book(let division):
            HStack(spacing: 0) {
                board()
                    .frame(width: max(division.minX, 200))
                Color.clear
                    .frame(width: division.width)
                stage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var boardWidth: CGFloat {
        min(max(info.containerSize.width * 0.40, 320), 480)
    }
}
