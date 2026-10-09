import SwiftUI
import AICatCore

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if app.profile.onboardingDone {
                NavigationStack(path: $app.path) {
                    ScenarioMapView()
                        .navigationDestination(for: ScenarioID.self) { id in
                            ScenarioHostView(scenarioID: id)
                        }
                        .navigationDestination(for: ChallengeSpec.self) { spec in
                            ChallengeHost(spec: spec)
                        }
                }
                .id(app.language)
            } else {
                OnboardingView()
            }
        }
        .environment(\.locale, app.language.locale)
        .sheet(isPresented: $app.isParentZonePresented) {
            ParentFlowView()
                .environment(app)
        }
    }
}
