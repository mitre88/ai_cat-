import SwiftUI
import AICatCore

/// Board of the Neuron Factory: the examples, the dial-neurons (levels 1–3) or the self-training
/// network with its error curve (master level).
struct NeuronBoard: View {
    let controller: NeuronFactoryController
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.string(controller.spec.goalKey.raw))
                    .font(.headline)
                if let key = controller.trainingTargetKey {
                    Text(L10n.string(key)).font(.subheadline)
                }
                Text(L10n.string(controller.isTrainingMode ? "neuron.training_tip" : "neuron.wire_tip"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(L10n.format("neuron.correct_format", controller.correctCount, controller.examples.count))
                    .font(.subheadline.bold())
                    .foregroundStyle(controller.isSolved ? Theme.eyeGreen : Color.primary)
                if controller.isDone {
                    Text(L10n.string("neuron.solved"))
                        .font(.callout.bold())
                        .foregroundStyle(Theme.eyeGreen)
                }
                examplesCard
                if controller.isTrainingMode {
                    trainingCard
                } else if let network = controller.network {
                    networkCard(network)
                    hintButton
                }
                Text(L10n.string(controller.spec.conceptKey.raw))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.mapBackground)
    }

    // MARK: Examples

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("neuron.examples_title")).font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(Array(controller.examples.enumerated()), id: \.element.id) { pair in
                exampleRow(pair.element, index: pair.offset)
            }
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func exampleRow(_ example: NeuronExample, index: Int) -> some View {
        let predicted = controller.prediction(for: example)
        let right = predicted == example.target
        let selected = controller.selectedExample == index
        return Button {
            controller.select(example: index)
        } label: {
            HStack(spacing: 6) {
                ForEach(Array(example.inputs.enumerated()), id: \.offset) { lamp in
                    Text(lamp.element == 1 ? "💡" : "⚫").font(.body)
                }
                Text("→").foregroundStyle(.secondary)
                Text(example.target == 1 ? "💡" : "⚫").font(.body)
                Spacer()
                if controller.isTrainingMode {
                    Text(String(format: "%.0f%%", controller.outputProbability(for: example) * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(right ? Color.green : Color.red)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(selected ? Theme.eyeGreen.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Dials

    private func networkCard(_ network: TernaryNetwork) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("neuron.network_title")).font(.caption.bold()).foregroundStyle(.secondary)
            if network.isTwoLayer {
                ForEach(Array(network.hidden.enumerated()), id: \.offset) { pair in
                    neuronRow(title: L10n.format("neuron.hidden_format", pair.offset + 1),
                              neuron: pair.element,
                              inputs: controller.currentExample?.inputs ?? [],
                              inputLabels: (0..<network.inputCount).map { "💡\($0 + 1)" },
                              weightDial: { .hiddenWeight(neuron: pair.offset, input: $0) },
                              thresholdDial: .hiddenThreshold(neuron: pair.offset))
                }
                neuronRow(title: L10n.string("neuron.output_neuron"),
                          neuron: network.output,
                          inputs: controller.currentExample.map { network.hiddenActivations($0.inputs) } ?? [],
                          inputLabels: (0..<network.hidden.count).map { "🔵\($0 + 1)" },
                          weightDial: { .outputWeight(index: $0) },
                          thresholdDial: .outputThreshold)
            } else {
                neuronRow(title: L10n.string("neuron.output_neuron"),
                          neuron: network.output,
                          inputs: controller.currentExample?.inputs ?? [],
                          inputLabels: (0..<network.inputCount).map { "💡\($0 + 1)" },
                          weightDial: { .outputWeight(index: $0) },
                          thresholdDial: .outputThreshold)
            }
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func neuronRow(title: String, neuron: TernaryNeuron, inputs: [Int], inputLabels: [String],
                           weightDial: @escaping (Int) -> NeuronDial, thresholdDial: NeuronDial) -> some View {
        let sum = inputs.count == neuron.weights.count ? neuron.sum(inputs) : 0
        let fires = inputs.count == neuron.weights.count && neuron.fires(inputs)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Text(L10n.format("neuron.sum_format", sum)).font(.caption).foregroundStyle(.secondary)
                Text(fires ? "💡" : "⚫")
            }
            HStack(spacing: 8) {
                ForEach(Array(neuron.weights.enumerated()), id: \.offset) { pair in
                    Button {
                        controller.cycleWeight(weightDial(pair.offset))
                    } label: {
                        VStack(spacing: 2) {
                            Text(inputLabels.indices.contains(pair.offset) ? inputLabels[pair.offset] : "").font(.caption2)
                            Text(Self.wireSymbol(pair.element)).font(.title3)
                        }
                        .frame(minWidth: 44)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(controller.lastHint == weightDial(pair.offset) ? Color.orange : Color.accentColor)
                    .disabled(controller.isDone)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Text(L10n.format("neuron.threshold_format", neuron.threshold)).font(.callout)
                Button {
                    controller.adjustThreshold(thresholdDial, by: -1)
                } label: {
                    Image(systemName: "minus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(controller.isDone || neuron.threshold <= 0)
                Button {
                    controller.adjustThreshold(thresholdDial, by: 1)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(controller.isDone || neuron.threshold >= neuron.weights.count)
                if controller.lastHint == thresholdDial {
                    Image(systemName: "lightbulb.fill").foregroundStyle(Color.orange)
                }
            }
        }
        .padding(10)
        .background(Theme.mapBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    static func wireSymbol(_ weight: Int) -> String {
        weight > 0 ? "🟢" : (weight < 0 ? "🔴" : "⚪")
    }

    @ViewBuilder
    private var hintButton: some View {
        Button {
            controller.requestHint()
        } label: {
            Label(app.profile.ageBand.autoHints ? L10n.string("common.hint") : L10n.format("sorting.hint_button", controller.hintsLeft), systemImage: "lightbulb.fill")
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .disabled(!controller.canRequestHint)
    }

    // MARK: Training

    @ViewBuilder
    private var trainingCard: some View {
        if let training = controller.training {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("neuron.rate_label")).font(.caption.bold()).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(Array(training.learningRates.enumerated()), id: \.offset) { pair in
                        Button {
                            controller.selectRate(pair.offset)
                        } label: {
                            Text(rateLabel(pair.offset)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(training.rateIndex == pair.offset ? Theme.eyeGreen : Color.gray)
                        .disabled(controller.isDone)
                    }
                }
                LossChart(losses: training.lossHistory)
                    .frame(height: 90)
                HStack {
                    Text(L10n.format("neuron.loss_format", String(format: "%.3f", training.currentLoss))).font(.caption)
                    Spacer()
                    Text(L10n.format("neuron.epochs_format", training.epochsTrained)).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button(L10n.format("neuron.train_format", training.epochsPerPress)) {
                        controller.train()
                    }
                    .buttonStyle(KidButtonStyle(tint: Theme.eyeGreen))
                    .disabled(controller.isDone)
                    Button {
                        controller.restart()
                    } label: {
                        Label(L10n.string("neuron.restart"), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.isDone)
                }
            }
            .padding(12)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func rateLabel(_ index: Int) -> String {
        switch index {
        case 0: return "🐢 " + L10n.string("neuron.rate.slow")
        case 1: return "🐇 " + L10n.string("neuron.rate.medium")
        default: return "🚀 " + L10n.string("neuron.rate.fast")
        }
    }
}

/// The error over the last training steps, as bars (no Charts dependency, works in every posture).
struct LossChart: View {
    let losses: [Double]
    static let barCount = 48

    var body: some View {
        let recent = Array(losses.suffix(Self.barCount))
        let top = max(recent.max() ?? 1, 0.05)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(recent.enumerated()), id: \.offset) { pair in
                    Rectangle()
                        .fill(Theme.eyeGreen.opacity(0.75))
                        .frame(height: max(2, geo.size.height * CGFloat(pair.element / top)))
                }
                if recent.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomLeading)
        }
        .background(Theme.mapBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
