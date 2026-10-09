import SwiftUI
import AICatCore

/// One world: concept, AI CAT's intro and its four challenges.
struct ScenarioHostView: View {
    let scenarioID: ScenarioID
    @Environment(AppModel.self) private var app

    private var scenario: Scenario { Curriculum.scenario(scenarioID) }
    private var palette: WorldPalette { Theme.palette(for: scenario.theme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Text(Theme.emoji(for: scenario.theme)).font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string(scenario.titleKey.raw)).font(.title.bold())
                        Text(L10n.string(scenario.subtitleKey.raw)).font(.subheadline).foregroundStyle(.secondary)
                        Text(L10n.string(scenario.bigIdea.titleKey.raw))
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(palette.accent.opacity(0.2), in: Capsule())
                    }
                }
                Text(L10n.string(scenario.conceptKey.raw))
                    .font(.body)
                    .padding(14)
                    .background(palette.sky.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                CatSpeechBubble(line: app.speech)
                VStack(spacing: 10) {
                    ForEach(scenario.challenges) { spec in
                        ChallengeRow(spec: spec, isUnlocked: app.profile.isUnlocked(challenge: spec), stars: stars(for: spec)) {
                            open(spec)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.mapBackground.ignoresSafeArea())
        .navigationTitle(L10n.string(scenario.titleKey.raw))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { app.say(.scenarioIntro, scenario: scenarioID) }
    }

    private func stars(for spec: ChallengeSpec) -> Int? {
        guard app.profile.isPassed(spec.id), let best = app.profile.bestResult(for: spec.id) else { return nil }
        return Scoring.stars(accuracy: best.accuracy)
    }

    private func open(_ spec: ChallengeSpec) {
        if app.profile.isUnlocked(challenge: spec) {
            app.path.append(spec)
        } else {
            app.say(.locked)
        }
    }
}

struct ChallengeRow: View {
    let spec: ChallengeSpec
    let isUnlocked: Bool
    let stars: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(spec.isMaster ? Color.orange : Theme.eyeGreen)
                        .frame(width: 40, height: 40)
                    Image(systemName: spec.isMaster ? "crown.fill" : "\(spec.index).circle.fill")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(spec.titleKey.raw)).font(.headline).foregroundStyle(.primary)
                    Text(L10n.string(spec.goalKey.raw)).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                trailing
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(isUnlocked ? 1 : 0.6)
    }

    @ViewBuilder
    private var trailing: some View {
        if let stars {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < stars ? "star.fill" : "star")
                }
            }
            .font(.caption)
            .foregroundStyle(.yellow)
        } else if !isUnlocked {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        } else {
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
    }
}
