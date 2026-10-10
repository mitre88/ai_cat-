import SwiftUI
import AICatCore

/// The ten worlds. Locked worlds wake up when the previous one is completed.
struct ScenarioMapView: View {
    @Environment(AppModel.self) private var app
    @State private var homeWorld = WorldModel(theme: .garden)

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 230), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Curriculum.scenarios) { scenario in
                        ScenarioCard(
                            scenario: scenario,
                            isUnlocked: app.profile.isUnlocked(scenario.id),
                            isCompleted: app.profile.isCompleted(scenario.id)
                        ) {
                            open(scenario)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.mapBackground.ignoresSafeArea())
        .navigationTitle(L10n.string("app.name"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    app.isParentZonePresented = true
                } label: {
                    Label(L10n.string("parent.zone"), systemImage: "person.2.fill")
                }
            }
        }
        .onAppear {
            if app.speech == nil { app.say(.greeting) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            StageView(world: homeWorld, showsSpeech: false)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // The kitten's line lives under the stage, so the world stays in full view.
            if let line = app.speech, !line.text.isEmpty {
                CatSpeechBubble(line: line, style: .inset)
            }
            HStack(alignment: .top, spacing: 16) {
                CatAvatarView(emotion: app.speech?.emotion ?? .happy, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.profile.catName)
                        .font(.title.bold())
                    Text(L10n.format("map.stage_format", app.profile.stage))
                        .font(.subheadline)
                    ProgressView(value: app.profile.stageProgress)
                        .tint(Theme.eyeGreen)
                    Text(L10n.format("map.xp_format", app.profile.totalXP, app.profile.xpToNextStage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    knowledgeRow
                }
            }
        }
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    @ViewBuilder
    private var knowledgeRow: some View {
        if !app.profile.unlockedKnowledge.isEmpty {
            HStack(spacing: 6) {
                ForEach(app.profile.unlockedKnowledge) { item in
                    Image(systemName: Theme.symbol(for: item))
                        .foregroundStyle(Theme.eyeGreen)
                        .accessibilityLabel(Text(L10n.string(item.titleKey.raw)))
                }
            }
            .font(.caption)
        }
    }

    private func open(_ scenario: Scenario) {
        if app.profile.isUnlocked(scenario.id) {
            app.path.append(scenario.id)
        } else {
            app.say(.locked)
        }
    }
}

struct ScenarioCard: View {
    let scenario: Scenario
    let isUnlocked: Bool
    let isCompleted: Bool
    let action: () -> Void

    private var palette: WorldPalette { Theme.palette(for: scenario.theme) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(Theme.emoji(for: scenario.theme))
                        .font(.largeTitle)
                    Spacer()
                    status
                }
                Text(L10n.string(scenario.titleKey.raw))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(L10n.string(scenario.subtitleKey.raw))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.sky.opacity(isUnlocked ? 0.55 : 0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.accent.opacity(isUnlocked ? 0.6 : 0.2), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .opacity(isUnlocked ? 1 : 0.8)
        .accessibilityLabel(Text(L10n.string(scenario.titleKey.raw)))
    }

    @ViewBuilder
    private var status: some View {
        if isCompleted {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
        } else if !scenario.isPlayable {
            Text(L10n.string("common.coming_soon"))
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.lockedGray, in: Capsule())
        } else if !isUnlocked {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        }
    }
}
