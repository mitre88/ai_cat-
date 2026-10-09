import SwiftUI
import AICatCore

/// Panel of the Data Library: accuracy meter, the cards to label, species buttons and AI CAT's guess.
struct LabelingBoard: View {
    let controller: DataLibraryController
    @Environment(AppModel.self) private var app

    private let columns = [GridItem(.adaptive(minimum: 84, maximum: 120), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.string(controller.spec.goalKey.raw))
                        .font(.headline)
                    Text(L10n.string("labeling.select_tip"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    AccuracyMeter(accuracy: controller.aiAccuracy, labeled: controller.labeledCount, total: controller.totalCount)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(controller.cards) { card in
                            AnimalCardView(
                                card: card,
                                label: controller.label(of: card),
                                isSelected: controller.selectedCardID == card.id,
                                isWrong: controller.isWrong(card),
                                isTrap: controller.isTrap(card),
                                isHinted: controller.hintCardID == card.id,
                                showFeatures: app.profile.ageBand != .explorer
                            ) {
                                controller.select(card)
                            }
                        }
                    }
                    guessCard
                    Text(L10n.string(controller.spec.conceptKey.raw))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            speciesBar
        }
        .background(Theme.mapBackground)
    }

    private var guessCard: some View {
        HStack(spacing: 10) {
            CatAvatarView(emotion: app.speech?.emotion ?? .happy, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                if let guess = controller.guess {
                    Text(L10n.format("labeling.guess_format", L10n.string(guess.species.nameKey.raw), guess.votes, guess.neighbours))
                        .font(.callout)
                } else {
                    Text(L10n.string("labeling.guess_none"))
                        .font(.callout)
                }
                if let hinted = controller.hintSpecies {
                    Label(L10n.format("labeling.hint_format", L10n.string(hinted.nameKey.raw)), systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.eyeGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var speciesBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(controller.speciesOptions) { species in
                    Button {
                        controller.label(species)
                    } label: {
                        VStack(spacing: 2) {
                            Text(AnimalCardView.emoji(for: species, variant: 0)).font(.title)
                            Text(L10n.string(species.nameKey.raw)).font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DataLibraryController.color(for: species))
                    .disabled(controller.selectedCard == nil || controller.isDone)
                }
            }
            if app.profile.ageBand.autoHints {
                Label(L10n.string("sorting.hint_auto"), systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    controller.requestHint()
                } label: {
                    Label(L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!controller.canRequestHint)
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }
}

/// AI CAT's live accuracy on the hidden test cards.
struct AccuracyMeter: View {
    let accuracy: Double
    let labeled: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(L10n.string("labeling.meter_title"), systemImage: "gauge.with.needle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.format("labeling.progress_format", labeled, total))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: accuracy)
                .tint(accuracy >= 0.8 ? Theme.eyeGreen : (accuracy >= 0.5 ? Color.orange : Color.red))
                .animation(.easeInOut(duration: 0.4), value: accuracy)
            Text(L10n.format("labeling.accuracy_format", Int((accuracy * 100).rounded())))
                .font(.subheadline.bold())
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AnimalCardView: View {
    let card: AnimalCard
    let label: Species?
    let isSelected: Bool
    let isWrong: Bool
    let isTrap: Bool
    let isHinted: Bool
    let showFeatures: Bool
    let action: () -> Void

    static func emoji(for species: Species, variant: Int) -> String {
        let table: [Species: [String]] = [
            .cat: ["🐱", "🐈", "🐈‍⬛"],
            .dog: ["🐶", "🐕", "🦮"],
            .bird: ["🐦", "🐤", "🦜"],
        ]
        let options = table[species] ?? ["🐾"]
        return options[((variant % options.count) + options.count) % options.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(Self.emoji(for: card.species, variant: card.variant))
                    .font(.system(size: 36))
                if showFeatures {
                    featureBars
                }
                labelChip
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected || isHinted ? 3 : 1.5)
            )
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.string(card.species.nameKey.raw)))
    }

    private var borderColor: Color {
        if isHinted { return .orange }
        if isWrong { return .red }
        if isSelected { return Theme.eyeGreen }
        return Theme.lockedGray
    }

    private var featureBars: some View {
        HStack(spacing: 3) {
            ForEach(Array(card.features.values.prefix(3).enumerated()), id: \.offset) { pair in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.eyeGreen.opacity(0.7))
                    .frame(width: 6, height: 4 + CGFloat(pair.element) * 18)
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    @ViewBuilder
    private var labelChip: some View {
        if let label {
            HStack(spacing: 3) {
                if isTrap { Text("🐭").font(.caption2) }
                Text(L10n.string(label.nameKey.raw))
                    .font(.caption2.bold())
                if isWrong { Text("?").font(.caption2.bold()) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background((isWrong ? Color.red : DataLibraryController.color(for: label)).opacity(0.25), in: Capsule())
        } else {
            Text("…")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.vertical, 3)
        }
    }
}
