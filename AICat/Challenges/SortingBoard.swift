import SwiftUI
import AICatCore

/// Panel of the Pattern Garden: the rule (stated or secret), progress, AI CAT's learning status and hints.
struct SortingBoard: View {
    let controller: PatternGardenController
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                Text(L10n.string("sorting.drag_tip"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ruleCard
                progressCard
                statusCard
                HStack(spacing: 12) {
                    hintButton
                    Spacer()
                    legend
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    private var ruleCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.string("sorting.rule_title"), systemImage: "list.bullet.rectangle")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if controller.challenge.ruleIsStated {
                ForEach(controller.ruleStatements, id: \.self) { sentence in
                    Text(sentence)
                }
            } else {
                Text(L10n.string("sorting.secret_rule"))
            }
            if !controller.learnedStatements.isEmpty {
                Divider()
                Label(L10n.string("sorting.learned_title"), systemImage: "brain")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.eyeGreen)
                ForEach(controller.learnedStatements, id: \.self) { sentence in
                    Text(sentence).font(.callout)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.format("sorting.progress_format", controller.sortedCount, controller.totalCount))
                .font(.subheadline.bold())
            ProgressView(value: Double(controller.sortedCount), total: Double(max(controller.totalCount, 1)))
                .tint(Theme.eyeGreen)
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusCard: some View {
        HStack(spacing: 10) {
            CatAvatarView(emotion: app.speech?.emotion ?? .happy, size: 44)
            Text(statusText)
                .font(.callout)
            Spacer()
        }
        .padding(12)
        .background(Theme.eyeGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusText: String {
        switch controller.status {
        case .watching: return L10n.string("sorting.status.watching")
        case .thinking: return L10n.string("sorting.status.thinking")
        case .learned: return L10n.string("sorting.status.learned")
        case .sorting: return L10n.string("sorting.status.sorting")
        case .done: return L10n.string("sorting.status.done")
        }
    }

    @ViewBuilder
    private var hintButton: some View {
        if app.profile.ageBand.autoHints {
            Label(L10n.string("sorting.hint_auto"), systemImage: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Button {
                controller.requestHint()
            } label: {
                Label(L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!controller.canRequestHint)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach(Array(controller.challenge.baskets.enumerated()), id: \.element.id) { pair in
                HStack(spacing: 4) {
                    Circle()
                        .fill(PatternGardenController.basketColors[pair.offset % PatternGardenController.basketColors.count])
                        .frame(width: 14, height: 14)
                    Text(L10n.format("sorting.basket_format", pair.element.index))
                        .font(.caption)
                }
            }
        }
    }
}
