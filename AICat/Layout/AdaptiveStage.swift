import SwiftUI
import AICatCore

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
            #if AICAT_DUO
            if #available(iOS 27.1, *) {
                DuoStageArrangement(stage: stage, board: board)
            } else {
                worldSideBySide
            }
            #else
            worldSideBySide
            #endif
        case .lab(let division):
            VStack(spacing: 0) {
                stage()
                    .frame(height: max(division.minY, 120))
                foldGap(horizontal: true)
                    .frame(height: division.height)
                board()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .book(let division):
            HStack(spacing: 0) {
                board()
                    .frame(width: max(division.minX, 200))
                foldGap(horizontal: false)
                    .frame(width: division.width)
                stage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var worldSideBySide: some View {
        HStack(spacing: 0) {
            board()
                .frame(width: boardWidth)
            stage()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func foldGap(horizontal: Bool) -> some View {
        #if AICAT_DUO
        FoldGap(isHorizontal: horizontal)
        #else
        Color.clear
        #endif
    }

    private var boardWidth: CGFloat {
        min(max(info.containerSize.width * 0.40, 320), 480)
    }
}
