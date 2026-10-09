import SwiftUI
import AICatCore

/// Board of AI CAT's Voice: tokens, next-word guessing, talking to AI CAT and judging its answers.
struct LanguageBoard: View {
    let controller: CatVoiceController
    @Environment(AppModel.self) private var app
    @State private var gatePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                switch controller.level {
                case .tokens:
                    if let challenge = controller.tokens { tokensView(challenge) }
                case .nextWord:
                    if let challenge = controller.nextWord { nextWordView(challenge) }
                case .talk:
                    if let challenge = controller.talk { talkView(challenge) }
                case .chat:
                    if let challenge = controller.chat { chatView(challenge) }
                }
                HStack(spacing: 12) {
                    Button(L10n.string("tokens.confirm")) { controller.confirm() }
                        .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                        .disabled(!controller.canConfirm)
                    if controller.level == .tokens || controller.level == .nextWord {
                        hintButton
                    }
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
        .sheet(isPresented: $gatePresented) {
            ParentGateView {
                gatePresented = false
                controller.approveParent()
            }
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

    private func tokenChips(_ tokens: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 54, maximum: 110), spacing: 6)], spacing: 6) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { pair in
                Text(pair.element)
                    .font(.callout.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.eyeGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    // MARK: Tokens

    private func tokensView(_ challenge: TokenChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("tokens.tip")).font(.footnote).foregroundStyle(.secondary)
            Text(L10n.format("tokens.round_format", min(challenge.roundIndex + 1, challenge.rounds.count), challenge.rounds.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let round = challenge.current {
                Text(round.word).font(.largeTitle.bold()).frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    Text(L10n.string("tokens.so_far")).font(.caption).foregroundStyle(.secondary)
                    tokenChips(challenge.assembled)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70, maximum: 120), spacing: 8)], spacing: 8) {
                    ForEach(Array(round.chips.enumerated()), id: \.offset) { pair in
                        Button {
                            controller.tapChip(pair.element)
                        } label: {
                            Text(pair.element).font(.title3.monospaced()).frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(controller.isDone)
                    }
                }
            } else {
                Text(L10n.string("tokens.round_done")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            }
            if controller.feedback == .wrongChip {
                Text(L10n.string("tokens.wrong")).font(.callout.bold()).foregroundStyle(Color.orange)
            } else if controller.feedback == .roundDone, challenge.current != nil {
                Text(L10n.string("tokens.round_done")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            }
        }
    }

    // MARK: Next word

    private func nextWordView(_ challenge: NextWordChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("nextword.tip")).font(.footnote).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("nextword.corpus_title")).font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(Array(challenge.corpus.enumerated()), id: \.offset) { pair in
                    Text(pair.element.joined(separator: " ")).font(.callout)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(L10n.format("nextword.round_format", min(challenge.currentIndex + 1, challenge.rounds.count), challenge.rounds.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let round = challenge.current {
                Text(L10n.format("nextword.after_format", round.context)).font(.title3.bold())
                HStack(spacing: 8) {
                    ForEach(round.options, id: \.self) { option in
                        Button {
                            controller.pickWord(option)
                        } label: {
                            Text(option).font(.title3).frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .disabled(controller.isDone)
                    }
                }
            }
            if let last = challenge.rounds.indices.contains(challenge.currentIndex - 1) ? challenge.rounds[challenge.currentIndex - 1] : nil {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(challenge.model.predictions(after: last.context).enumerated()), id: \.offset) { pair in
                        Text(L10n.format("nextword.counts_format", pair.element.word, pair.element.count)).font(.caption)
                    }
                }
            }
            switch controller.feedback {
            case .pickRight:
                Text(L10n.string("nextword.right")).font(.callout.bold()).foregroundStyle(Theme.eyeGreen)
            case .pickWrong(let answer):
                Text(L10n.format("nextword.wrong_format", answer)).font(.callout.bold()).foregroundStyle(Color.orange)
            default:
                EmptyView()
            }
        }
    }

    // MARK: Talk

    @ViewBuilder
    private func talkView(_ challenge: TalkChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("talk.tip")).font(.footnote).foregroundStyle(.secondary)
            Text(L10n.format("talk.progress_format", challenge.utterances.count, challenge.required)).font(.caption).foregroundStyle(.secondary)
            switch controller.listeningState {
            case .needsParent:
                Text(L10n.string("talk.parent_needed")).font(.callout)
                Button(L10n.string("vision.live.ask_parent")) { gatePresented = true }
                    .buttonStyle(KidButtonStyle(tint: Color.accentColor))
            case .idle:
                Button(L10n.string("talk.listen")) { controller.listen() }
                    .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                    .disabled(controller.isDone)
            case .listening:
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.string("talk.listening")).font(.callout)
                    Text(controller.listener.partialText).font(.callout).foregroundStyle(.secondary)
                }
            case .unavailable:
                Text(L10n.string("talk.unavailable")).font(.caption).foregroundStyle(.secondary)
            }
            if controller.listeningState != .needsParent {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.string("talk.pretend_title")).font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(1...3, id: \.self) { index in
                        Button {
                            controller.pretend(L10n.string("talk.pretend.\(index)"))
                        } label: {
                            Text(L10n.string("talk.pretend.\(index)")).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .disabled(controller.isDone || controller.listeningState == .listening)
                    }
                }
            }
            if let heard = controller.lastTranscript {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.format("talk.heard_format", heard)).font(.callout.bold())
                    Text(L10n.string("talk.tokens_title")).font(.caption).foregroundStyle(.secondary)
                    tokenChips(controller.tokens(of: heard))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text(L10n.string("talk.private_note")).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Chat

    private func chatView(_ challenge: ConversationChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("chat.tip")).font(.footnote).foregroundStyle(.secondary)
            Text(L10n.format("chat.progress_format", challenge.revealedCount, challenge.turns.count)).font(.caption).foregroundStyle(.secondary)
            ForEach(challenge.turns) { turn in
                let judged = challenge.judgements[turn.id]
                VStack(alignment: .leading, spacing: 6) {
                    Text("🧒 " + L10n.string(turn.questionKey)).font(.callout)
                    Text("🐱 " + L10n.string(turn.answerKey)).font(.callout.bold())
                    if let judged {
                        HStack(spacing: 6) {
                            Image(systemName: challenge.isCorrect(turn) == true ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(challenge.isCorrect(turn) == true ? Color.green : Color.red)
                            Text(L10n.string(turn.isWrong ? (judged ? "chat.missed" : "chat.caught") : (judged ? "chat.trusted_right" : "chat.doubted_right")))
                                .font(.caption)
                        }
                    } else if challenge.current?.id == turn.id {
                        HStack(spacing: 8) {
                            Button(L10n.string("chat.believe")) { controller.judge(turn.id, believes: true) }
                                .buttonStyle(.bordered)
                                .tint(Theme.eyeGreen)
                            Button(L10n.string("chat.doubt")) { controller.judge(turn.id, believes: false) }
                                .buttonStyle(.bordered)
                                .tint(Color.red)
                        }
                        .disabled(controller.isDone)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(judged == nil && challenge.current?.id != turn.id ? 0.4 : 1)
            }
            if challenge.isComplete && controller.creativeModeOn {
                askCard
            }
        }
    }

    private var askCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("chat.ask_title")).font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(1...3, id: \.self) { index in
                Button {
                    controller.ask(L10n.string("chat.ask.\(index)"))
                } label: {
                    Text(L10n.string("chat.ask.\(index)")).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(controller.isAsking)
            }
            if controller.isAsking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L10n.string("chat.thinking")).font(.caption).foregroundStyle(.secondary)
                }
            } else if let answer = controller.modelAnswer {
                Text("🐱 " + answer).font(.callout.bold())
                Text(L10n.string("chat.model_answer_note")).font(.caption2).foregroundStyle(.secondary)
            } else if controller.modelDeclined {
                Text(L10n.string("chat.model_silent")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
