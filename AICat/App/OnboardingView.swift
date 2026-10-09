import SwiftUI
import AICatCore

/// Three friendly steps: language → name the kitten → play. No personal data is requested.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var step = 0
    @State private var name = ""

    private let suggestions = ["Luna", "Max", "Nube", "Pixel", "Mochi", "Byte"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CatAvatarView(emotion: step == 2 ? .excited : .curious, size: 140)
                    .padding(.top, 40)
                Text(L10n.string("app.name"))
                    .font(.largeTitle.bold())
                stepView
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.mapBackground.ignoresSafeArea())
        .animation(.easeInOut, value: step)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case 0: languageStep
        case 1: nameStep
        default: readyStep
        }
    }

    private var languageStep: some View {
        VStack(spacing: 16) {
            Text(L10n.string("onboarding.choose_language"))
                .font(.title3)
                .multilineTextAlignment(.center)
            Button("Español") {
                app.setLanguage(.spanish)
                step = 1
            }
            .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
            Button("English") {
                app.setLanguage(.english)
                step = 1
            }
            .buttonStyle(KidButtonStyle(tint: .accentColor))
        }
    }

    private var nameStep: some View {
        VStack(spacing: 16) {
            Text(L10n.string("onboarding.name_prompt"))
                .font(.title3)
                .multilineTextAlignment(.center)
            TextField(L10n.string("onboarding.name_placeholder"), text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .onSubmit { step = 2 }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { name = suggestion }
                        .buttonStyle(.bordered)
                }
            }
            Button(L10n.string("common.continue")) { step = 2 }
                .buttonStyle(KidButtonStyle())
        }
    }

    private var readyStep: some View {
        VStack(spacing: 16) {
            Text(L10n.string("onboarding.ready_title"))
                .font(.title2.bold())
            Text(L10n.string("onboarding.ready_adults"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.string("onboarding.start")) {
                app.completeOnboarding(catName: name)
            }
            .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
            Button(L10n.string("common.back")) { step = 1 }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }
}
