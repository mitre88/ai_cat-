import SwiftUI
import AICatCore

/// Board of the Reward Maze: the grid the child edits (treat, puddles), the warmth of every tile,
/// the explore button and what happened in the last batch of episodes.
struct MazeBoard: View {
    let controller: RewardMazeController
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                Text(tipText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                toolsCard
                MazeGridView(controller: controller)
                    .frame(maxWidth: .infinity)
                Text(L10n.string("maze.heat_legend"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let notice = controller.notice {
                    Text(noticeText(notice))
                        .font(.callout.bold())
                        .foregroundStyle(Color.orange)
                }
                if controller.showsCuriosity {
                    curiosityCard
                }
                HStack(spacing: 12) {
                    Button(L10n.string(controller.isBusy ? (controller.phase == .exploring ? "maze.exploring" : "maze.testing") : "maze.explore")) {
                        controller.explore()
                    }
                    .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                    .disabled(!controller.canExplore)
                    hintButton
                }
                summaryCard
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    private var tipText: String {
        if controller.isDone { return L10n.string("maze.learned") }
        return L10n.string(controller.tool == .treat ? "maze.tip_place_treat" : "maze.tip_place_puddle")
    }

    private func noticeText(_ notice: RewardMazeController.Notice) -> String {
        switch notice {
        case .tooClose: return L10n.string("maze.notice.too_close")
        case .budget: return L10n.string("maze.notice.budget")
        case .unreachable: return L10n.string("maze.notice.unreachable")
        case .needTreat: return L10n.string("maze.notice.need_treat")
        case .wandered: return L10n.string("maze.notice.wandered")
        case .puddle: return L10n.string("maze.notice.puddle")
        case .straight: return L10n.string("maze.notice.straight")
        }
    }

    private var toolsCard: some View {
        HStack(spacing: 12) {
            if controller.showsToolPicker {
                Button {
                    controller.select(tool: .treat)
                } label: {
                    Text(L10n.string("maze.tool_treat"))
                }
                .buttonStyle(.bordered)
                .tint(controller.tool == .treat ? Color.orange : Color.gray)
                Button {
                    controller.select(tool: .puddle)
                } label: {
                    Text(L10n.string("maze.tool_puddle"))
                }
                .buttonStyle(.bordered)
                .tint(controller.tool == .puddle ? Color.blue : Color.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if controller.challenge.treatBudget > 0 {
                    Text(L10n.format("maze.treats_left_format", controller.challenge.treatsLeft)).font(.caption)
                }
                if controller.challenge.puddleBudget > 0 {
                    Text(L10n.format("maze.puddles_left_format", controller.challenge.puddlesLeft)).font(.caption)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var curiosityCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("maze.curiosity_label")).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array(controller.challenge.epsilonOptions.enumerated()), id: \.offset) { pair in
                    Button {
                        controller.selectCuriosity(pair.offset)
                    } label: {
                        Text(curiosityLabel(pair.offset))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(controller.epsilonIndex == pair.offset ? Theme.eyeGreen : Color.gray)
                    .disabled(!controller.canEdit)
                }
            }
            Text(L10n.format("maze.curiosity_value_format", Int((controller.challenge.epsilon * 100).rounded())))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func curiosityLabel(_ index: Int) -> String {
        switch index {
        case 0: return "🐢 " + L10n.string("maze.curiosity.careful")
        case 1: return "🐱 " + L10n.string("maze.curiosity.curious")
        default: return "🎲 " + L10n.string("maze.curiosity.wild")
        }
    }

    @ViewBuilder
    private var summaryCard: some View {
        if let batch = controller.lastBatch {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.format("maze.summary_format", batch.count(.treat), batch.count(.puddle), batch.count(.wandered)))
                    .font(.callout)
                Text(L10n.format("maze.batches_format", controller.batches))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder
    private var hintButton: some View {
        Button {
            controller.requestHint()
        } label: {
            Label(app.profile.ageBand.autoHints ? L10n.string("common.hint") : L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .disabled(!controller.canRequestHint)
    }
}

struct MazeGridView: View {
    let controller: RewardMazeController

    var body: some View {
        let size = controller.size
        VStack(spacing: 3) {
            ForEach(Array((0..<size).reversed()), id: \.self) { y in
                HStack(spacing: 3) {
                    ForEach(0..<size, id: \.self) { x in
                        cell(MazeCell(x, y))
                    }
                }
            }
        }
        .padding(8)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func cell(_ cell: MazeCell) -> some View {
        let tile = controller.tile(at: cell)
        let value = controller.heat(at: cell)
        let hasCat = controller.catCell == cell
        let isStart = controller.startCell == cell
        let side: CGFloat = controller.size >= 7 ? 36 : (controller.size >= 6 ? 40 : 46)
        return Button {
            controller.tap(cell)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tile == .wall ? RewardMazeController.wallColor : RewardMazeController.heatColor(value))
                if isStart && !hasCat {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.catBlack.opacity(0.5), lineWidth: 2)
                }
                Text(symbol(tile: tile, hasCat: hasCat))
                    .font(.system(size: side * 0.5))
            }
            .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        .disabled(tile == .wall || !controller.canEdit)
        .animation(.easeInOut(duration: 0.25), value: value)
    }

    private func symbol(tile: MazeTile, hasCat: Bool) -> String {
        if hasCat { return "🐾" }
        switch tile {
        case .treat: return "🐟"
        case .puddle: return "💧"
        case .wall: return "🌳"
        case .free: return ""
        }
    }
}
