import SwiftUI
import AICatCore

/// Settings an adult controls: age band, language, voice, generative mode, effects, progress, privacy.
struct ParentZoneView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section(L10n.string("parent.age_section")) {
                Picker(L10n.string("parent.age_section"), selection: ageBinding) {
                    ForEach(AgeBand.allCases) { band in
                        Text(L10n.string(band.titleKey.raw)).tag(band)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Text(L10n.string(app.profile.ageBand.descriptionKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.string("common.language")) {
                Picker(L10n.string("common.language"), selection: languageBinding) {
                    Text(L10n.string("common.spanish")).tag(L10n.Language.spanish)
                    Text(L10n.string("common.english")).tag(L10n.Language.english)
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle(L10n.string("parent.voice"), isOn: binding(\.voiceEnabled))
                Toggle(L10n.string("parent.creative"), isOn: binding(\.creativeModeEnabled))
                Toggle(L10n.string("parent.effects"), isOn: binding(\.reduceEffects))
            } footer: {
                Text(L10n.string("parent.creative_footer"))
            }
            Section(L10n.string("parent.progress_section")) {
                LabeledContent(L10n.string("common.stage"), value: "\(app.profile.stage) / 10")
                LabeledContent(L10n.string("common.xp"), value: "\(app.profile.totalXP)")
                Text(L10n.format("parent.completed_format", app.profile.completedScenarioCount))
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    Text(L10n.string("parent.reset"))
                }
            }
            Section(L10n.string("parent.privacy_section")) {
                Text(L10n.string("parent.privacy_text"))
                    .font(.footnote)
            }
            Section(L10n.string("parent.about")) {
                Text(L10n.format("parent.version_format", versionString))
                    .font(.footnote)
            }
        }
        .navigationTitle(L10n.string("parent.zone"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.string("common.done")) { dismiss() }
            }
        }
        .confirmationDialog(L10n.string("parent.reset_confirm"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L10n.string("parent.reset"), role: .destructive) { app.resetProgress() }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        }
    }

    private var versionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    private var ageBinding: Binding<AgeBand> {
        Binding(
            get: { app.profile.ageBand },
            set: { band in
                app.update {
                    $0.ageBand = band
                    $0.difficulty = AdaptiveDifficulty(band: band)
                }
            }
        )
    }

    private var languageBinding: Binding<L10n.Language> {
        Binding(
            get: { app.language },
            set: { app.setLanguage($0) }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<PlayerProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { app.profile[keyPath: keyPath] },
            set: { value in app.update { $0[keyPath: keyPath] = value } }
        )
    }
}
