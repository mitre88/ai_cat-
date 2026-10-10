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

/// A world as a postcard: its sky, two felt hills in its palette and the emoji as a sticker, with no
/// outline. Locked worlds fade to grey, finished ones wear a seal.
struct ScenarioCard: View {
    let scenario: Scenario
    let isUnlocked: Bool
    let isCompleted: Bool
    let action: () -> Void

    private var palette: WorldPalette { Theme.palette(for: scenario.theme) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    sticker
                    Spacer()
                    status
                }
                Spacer(minLength: 18)
                Text(L10n.string(scenario.titleKey.raw))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(L10n.string(scenario.subtitleKey.raw))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .opacity(0.7)
                    .lineLimit(2)
                    .padding(.top, 3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .leading)
            .background(postcard)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            .saturation(isUnlocked ? 1 : 0.35)   // locked worlds keep a hint of their colour
            .opacity(isUnlocked ? 1 : 0.8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.string(scenario.titleKey.raw)))
    }

    // MARK: Postcard

    private var skyTop: Color { Theme.mix(palette.sky, white: 0.72) }
    private var skyBottom: Color { Theme.mix(palette.sky, white: 0.35) }
    private var farHill: Color { Theme.mix(palette.accent, white: 0.55) }
    private var nearHill: Color { Theme.mix(palette.ground, white: 0.45) }

    private var sky: LinearGradient {
        LinearGradient(colors: [skyTop, skyBottom], startPoint: .top, endPoint: .bottom)
    }

    /// Sky gradient with two soft hills along the bottom, like the stage's horizon.
    private var postcard: some View {
        ZStack(alignment: .bottom) {
            sky
            Ellipse()
                .fill(farHill)
                .frame(width: 260, height: 130)
                .offset(x: 70, y: 25)
            Ellipse()
                .fill(nearHill)
                .frame(width: 320, height: 150)
                .offset(x: -50, y: 55)
        }
    }

    private var sticker: some View {
        Text(Theme.emoji(for: scenario.theme))
            .font(.title)
            .frame(width: 48, height: 48)
            .background(Color.white, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    @ViewBuilder
    private var status: some View {
        if isCompleted {
            badge("checkmark", tint: .green)
        } else if !scenario.isPlayable {
            Text(L10n.string("common.coming_soon"))
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.85), in: Capsule())
        } else if !isUnlocked {
            badge("lock.fill", tint: .secondary)
        }
    }

    private func badge(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.caption.bold())
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(Color.white, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
