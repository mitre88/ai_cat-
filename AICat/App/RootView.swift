import SwiftUI

/// M0 placeholder. Replaced by the real root (onboarding → scenario map → scenarios) in M2.
struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cat.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            Text(L10n.string("app.name"))
                .font(.largeTitle.bold())
            Text(L10n.string("app.tagline"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
