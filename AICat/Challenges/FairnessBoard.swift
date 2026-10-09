import SwiftUI
import AICatCore

/// Board of the Fair Scale: four small games about bias, balance, privacy and judging AI decisions.
struct FairnessBoard: View {
    let controller: FairScaleController
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                switch controller.level {
                case .hunt:
                    if let hunt = controller.hunt { huntView(hunt) }
                case .balance:
                    if let balance = controller.balance { balanceView(balance) }
                case .privacy:
                    if let privacy = controller.privacy { privacyView(privacy) }
                case .judge:
                    if let judge = controller.judge { judgeView(judge) }
                }
                HStack(spacing: 12) {
                    if controller.level != .hunt {
                        Button(confirmTitle) { controller.confirm() }
                            .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                            .disabled(!controller.canConfirm)
                    }
                    hintButton
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    private var confirmTitle: String {
        switch controller.level {
        case .hunt: return ""
        case .balance: return L10n.string("fair.balance.confirm")
        case .privacy: return L10n.string("fair.privacy.finish")
        case .judge: return L10n.string("fair.judge.finish")
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

    // MARK: Level 1

    private func huntView(_ hunt: BiasHuntChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("fair.hunt.dataset_title")).font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(CatCoat.allCases) { coat in
                    HStack(spacing: 8) {
                        CatCardView(coat: coat, size: 30)
                        Text(L10n.format("fair.hunt.count_format", L10n.string(coat.nameKey), hunt.count(coat))).font(.callout)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<hunt.count(coat), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3).fill(CatCardView.color(for: coat)).frame(width: 12, height: 16)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("fair.hunt.tests_title")).font(.caption.bold()).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64, maximum: 90), spacing: 8)], spacing: 8) {
                    ForEach(hunt.testResults) { result in
                        VStack(spacing: 2) {
                            CatCardView(coat: result.coat, size: 40)
                            Image(systemName: result.recognized ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(result.recognized ? Color.green : Color.red)
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(L10n.string("fair.hunt.question")).font(.subheadline.bold())
            HStack(spacing: 10) {
                ForEach(CatCoat.allCases) { coat in
                    Button {
                        controller.pick(coat)
                    } label: {
                        VStack(spacing: 4) {
                            CatCardView(coat: coat, size: 44)
                            Text(L10n.string(coat.nameKey)).font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(controller.hintCoat == coat ? Color.orange : (hunt.picks.contains(coat) ? Color.gray : Color.accentColor))
                    .disabled(hunt.isSolved || hunt.picks.contains(coat))
                }
            }
            if let feedback = controller.feedback {
                switch feedback {
                case .wrongPick:
                    Text(L10n.string("fair.hunt.wrong")).font(.callout.bold()).foregroundStyle(Color.orange)
                case .rightPick(let coat):
                    Text(L10n.format("fair.hunt.right_format", L10n.string(coat.nameKey))).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
                }
            }
        }
    }

    // MARK: Level 2

    private func balanceView(_ balance: BalanceChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.format("fair.balance.target_format", balance.target)).font(.subheadline.bold())
            VStack(alignment: .leading, spacing: 6) {
                ForEach(CatCoat.allCases) { coat in
                    HStack(spacing: 8) {
                        CatCardView(coat: coat, size: 26)
                        Text(L10n.format("fair.balance.recognition_format", L10n.string(coat.nameKey), Int((balance.recognition(for: coat) * 100).rounded())))
                            .font(.caption)
                        Spacer()
                        ProgressView(value: balance.recognition(for: coat))
                            .frame(width: 90)
                            .tint(balance.count(coat) >= balance.target ? Theme.eyeGreen : Color.orange)
                    }
                }
                Text(L10n.format("fair.balance.gap_format", Int((balance.fairnessGap * 100).rounded())))
                    .font(.caption.bold())
                    .foregroundStyle(balance.isSolved ? Theme.eyeGreen : Color.orange)
                if balance.isSolved {
                    Text(L10n.string("fair.balance.solved")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
                }
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("fair.balance.dataset_title")).font(.caption.bold()).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 60), spacing: 6)], spacing: 6) {
                    ForEach(balance.dataset) { card in
                        Button {
                            controller.remove(card.id)
                        } label: {
                            CatCardView(coat: card.coat, size: 40)
                                .overlay(alignment: .topTrailing) {
                                    if balance.isFromPool(card.id) {
                                        Circle().fill(Theme.eyeGreen).frame(width: 10, height: 10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(!balance.isFromPool(card.id) || balance.isSolved)
                    }
                }
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("fair.balance.pool_title")).font(.caption.bold()).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 60), spacing: 6)], spacing: 6) {
                    ForEach(balance.pool) { card in
                        Button {
                            controller.add(card.id)
                        } label: {
                            CatCardView(coat: card.coat, size: 40)
                        }
                        .buttonStyle(.plain)
                        .disabled(balance.isSolved)
                    }
                }
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Level 3

    private func privacyView(_ privacy: PrivacyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("fair.privacy.rule")).font(.subheadline.bold())
            Text(L10n.format("fair.privacy.progress_format", privacy.decisions.count, privacy.items.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(privacy.items) { item in
                let decision = privacy.decision(for: item.id)
                HStack(spacing: 8) {
                    Text(L10n.string(item.key)).font(.callout)
                    Spacer()
                    Button(L10n.string("fair.privacy.keep")) { controller.decide(item.id, keep: true) }
                        .buttonStyle(.bordered)
                        .tint(decision == true ? Theme.eyeGreen : Color.gray)
                    Button(L10n.string("fair.privacy.drop")) { controller.decide(item.id, keep: false) }
                        .buttonStyle(.bordered)
                        .tint(decision == false ? Color.red : Color.gray)
                }
                .padding(10)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: Level 4

    private func judgeView(_ judge: JudgeChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.format("fair.judge.progress_format", judge.causeAnswers.count + judge.fixAnswers.count, judge.cases.count * 2))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(Array(judge.cases.enumerated()), id: \.element.id) { pair in
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.format("fair.judge.case_format", pair.offset + 1)).font(.caption.bold()).foregroundStyle(.secondary)
                    Text(L10n.string(pair.element.key)).font(.callout)
                    Text(L10n.string("fair.judge.cause_title")).font(.caption.bold())
                    ForEach(FairCause.allCases, id: \.self) { cause in
                        answerButton(title: L10n.string(cause.key),
                                     chosen: judge.causeAnswers[pair.element.id] == cause,
                                     answered: judge.causeAnswers[pair.element.id] != nil,
                                     correct: cause == pair.element.cause) {
                            controller.answerCause(pair.element.id, cause)
                        }
                    }
                    Text(L10n.string("fair.judge.fix_title")).font(.caption.bold())
                    ForEach(FairFix.allCases, id: \.self) { fix in
                        answerButton(title: L10n.string(fix.key),
                                     chosen: judge.fixAnswers[pair.element.id] == fix,
                                     answered: judge.fixAnswers[pair.element.id] != nil,
                                     correct: fix == pair.element.fix) {
                            controller.answerFix(pair.element.id, fix)
                        }
                    }
                }
                .padding(12)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func answerButton(title: String, chosen: Bool, answered: Bool, correct: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.callout).multilineTextAlignment(.leading)
                Spacer()
                if answered && chosen {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(correct ? Color.green : Color.red)
                } else if answered && correct {
                    Image(systemName: "checkmark.circle").foregroundStyle(Color.green)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(chosen ? Theme.eyeGreen : Color.accentColor)
        .disabled(answered)
    }
}

/// A cat card coloured by its coat.
struct CatCardView: View {
    let coat: CatCoat
    let size: CGFloat

    static func color(for coat: CatCoat) -> Color {
        switch coat {
        case .black: return Theme.catBlack
        case .orange: return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .white: return Color(red: 0.95, green: 0.95, blue: 0.93)
        case .striped: return Color(red: 0.6, green: 0.55, blue: 0.5)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Self.color(for: coat))
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(Theme.lockedGray, lineWidth: 1)
            Text("🐱").font(.system(size: size * 0.55))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(L10n.format("a11y.cat_card_format", L10n.string(coat.nameKey))))
    }
}
