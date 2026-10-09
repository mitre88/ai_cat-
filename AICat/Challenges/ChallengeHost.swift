import SwiftUI
import AICatCore

/// Hosts one challenge: the stage (AI CAT's world) and the board, laid out by posture,
/// plus the result overlay when the challenge ends.
struct ChallengeHost: View {
    let spec: ChallengeSpec
    @Environment(AppModel.self) private var app
    @State private var session: ChallengeSession
    @State private var world: WorldModel
    @State private var sorting: PatternGardenController?
    @State private var labeling: DataLibraryController?

    init(spec: ChallengeSpec) {
        self.spec = spec
        _session = State(initialValue: ChallengeSession(spec: spec))
        _world = State(initialValue: WorldModel(theme: Curriculum.scenario(spec.scenario).theme))
    }

    private var scenario: Scenario { Curriculum.scenario(spec.scenario) }

    var body: some View {
        PostureReader { info in
            AdaptiveStage(info: info) {
                StageView(world: world, interaction: sorting)
            } board: {
                board
            }
        }
        .overlay {
            if session.isFinished, let outcome = session.outcome {
                ChallengeResultOverlay(session: session, outcome: outcome, spec: spec)
            }
        }
        .navigationTitle(L10n.string(spec.titleKey.raw))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ProgressView(value: session.progress)
                    .frame(width: 80)
                    .tint(Theme.eyeGreen)
            }
        }
        .onAppear {
            app.say(spec.isMaster ? .masterIntro : .challengeStart)
            setUpController()
        }
        .onDisappear { app.hush() }
    }

    @ViewBuilder
    private var board: some View {
        if let sorting {
            SortingBoard(controller: sorting)
        } else if let labeling {
            LabelingBoard(controller: labeling)
        } else {
            ComingSoonBoard(spec: spec)
        }
    }

    private func setUpController() {
        switch spec.mechanic {
        case .sorting:
            if sorting == nil {
                let controller = PatternGardenController(spec: spec, world: world, session: session, app: app)
                sorting = controller
                controller.start()
            }
        case .labeling:
            if labeling == nil {
                let controller = DataLibraryController(spec: spec, world: world, session: session, app: app)
                labeling = controller
                controller.start()
            }
        default:
            break
        }
    }
}

/// Result card: stars, XP, growth and unlocks, then where to go next.
struct ChallengeResultOverlay: View {
    let session: ChallengeSession
    let outcome: PlayerProfile.RecordOutcome
    let spec: ChallengeSpec
    @Environment(AppModel.self) private var app

    private var nextChallenge: ChallengeSpec? {
        Curriculum.scenario(spec.scenario).challenges.first { $0.index == spec.index + 1 && app.profile.isUnlocked(challenge: $0) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                CatAvatarView(emotion: outcome.passed ? .proud : .curious, size: 110)
                Text(L10n.string(outcome.passed ? "result.title" : "result.try_again_title"))
                    .font(.title.bold())
                if outcome.passed {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < Scoring.stars(accuracy: session.finalAccuracy) ? "star.fill" : "star")
                                .font(.title)
                                .foregroundStyle(.yellow)
                        }
                    }
                } else {
                    Text(L10n.string("result.try_again_text"))
                        .multilineTextAlignment(.center)
                }
                Text(L10n.format("result.xp_format", outcome.xpGained))
                    .font(.headline)
                    .foregroundStyle(Theme.eyeGreen)
                if outcome.stageIncreased {
                    Label(L10n.format("result.stage_up", outcome.newStage), systemImage: "arrow.up.heart.fill")
                        .font(.headline)
                }
                if outcome.scenarioJustCompleted != nil {
                    Label(L10n.string("result.scenario_complete"), systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                if let item = outcome.knowledgeUnlocked {
                    Label(L10n.format("result.knowledge_format", L10n.string(item.titleKey.raw)), systemImage: Theme.symbol(for: item))
                        .font(.subheadline)
                }
                VStack(spacing: 10) {
                    if outcome.passed, let next = nextChallenge {
                        Button(L10n.string("result.next")) {
                            app.path.removeLast()
                            app.path.append(next)
                        }
                        .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                    }
                    Button(L10n.string(outcome.passed ? "result.back" : "result.again")) {
                        app.path.removeLast()
                    }
                    .buttonStyle(KidButtonStyle(tint: outcome.passed ? .accentColor : Theme.eyeGreen))
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding()
        }
        .transition(.opacity)
    }
}
