#if AICAT_DUO
import SwiftUI

/// Open, flat iPhone Duo (regular/regular): the system `ArrangementView` splits board and stage along
/// the best axis for the current size, and keeps interactive content away from the fold.
@available(iOS 27.1, *)
struct DuoStageArrangement<Stage: View, Board: View>: View {
    @ViewBuilder let stage: () -> Stage
    @ViewBuilder let board: () -> Board

    var body: some View {
        ArrangementView {
            board()
        } secondary: {
            stage()
        }
        .arrangementViewStyle(.split.axes([.horizontal, .vertical]))
    }
}
#endif
