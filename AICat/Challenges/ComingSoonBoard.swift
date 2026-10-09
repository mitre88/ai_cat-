import SwiftUI
import AICatCore

/// Board for mechanics that are defined in the curriculum but not yet playable.
struct ComingSoonBoard: View {
    let spec: ChallengeSpec

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(L10n.string("challenge.coming_soon_title"), systemImage: "hammer.fill")
                    .font(.headline)
                Text(L10n.string("challenge.coming_soon_text"))
                    .foregroundStyle(.secondary)
                ChallengeBriefView(spec: spec)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }
}

/// Goal and idea of a challenge, reused by every board.
struct ChallengeBriefView: View {
    let spec: ChallengeSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("challenge.goal_label")).font(.caption.bold()).foregroundStyle(.secondary)
                Text(L10n.string(spec.goalKey.raw)).font(.body)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("challenge.concept_label")).font(.caption.bold()).foregroundStyle(.secondary)
                Text(L10n.string(spec.conceptKey.raw)).font(.body)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
