import XCTest
@testable import AICatCore

final class NeuronMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.neuronFactory).challenges }
    private let difficulty = AdaptiveDifficulty(value: 0.45)

    func testTernaryNeuronsAndNetworks() {
        let and = TernaryNeuron(weights: [1, 1], threshold: 2)
        XCTAssertTrue(and.fires([1, 1]))
        XCTAssertFalse(and.fires([1, 0]))
        let notSecond = TernaryNeuron(weights: [0, -1], threshold: 0)
        XCTAssertTrue(notSecond.fires([1, 0]))
        XCTAssertFalse(notSecond.fires([0, 1]))
        let xor = NeuronContent.targets(inputs: 3, layers: 2)[0]
        XCTAssertEqual(NeuronContent.allRows(inputs: 3).map { xor.predict($0) }, [0, 0, 1, 1, 1, 1, 0, 0])
        XCTAssertEqual(xor.dialCount, 11)
        let exactlyOne = NeuronContent.targets(inputs: 3, layers: 2)[2]
        XCTAssertEqual(NeuronContent.allRows(inputs: 3).map { exactlyOne.predict($0) }, [0, 1, 1, 0, 1, 0, 0, 0])
        var blank = TernaryNetwork.blank(inputs: 2, hiddenCount: 0)
        XCTAssertEqual(blank.dialCount, 3)
        blank.set(.outputWeight(index: 0), to: 5)
        XCTAssertEqual(blank.value(of: .outputWeight(index: 0)), 1, "weights clamp to −1…1")
        blank.set(.outputThreshold, to: -3)
        XCTAssertEqual(blank.value(of: .outputThreshold), 0, "thresholds clamp to 0…inputs")
    }

    func testSeparabilityCheck() {
        let rows = NeuronContent.allRows(inputs: 2)
        let xorRows = rows.map { NeuronExample(inputs: $0, target: $0[0] ^ $0[1]) }
        XCTAssertFalse(NeuronContent.isLinearlySeparable(xorRows, inputs: 2))
        let andRows = rows.map { NeuronExample(inputs: $0, target: $0[0] & $0[1]) }
        XCTAssertTrue(NeuronContent.isLinearlySeparable(andRows, inputs: 2))
    }

    func testContentPerLevel() {
        for (index, spec) in specs.prefix(3).enumerated() {
            for seed in 1...10 {
                let challenge = NeuronContent.make(spec: spec, difficulty: difficulty, seed: UInt64(seed))
                let inputs = spec.param("inputs", default: 2)
                XCTAssertTrue(challenge.examples.allSatisfy { $0.inputs.count == inputs })
                XCTAssertTrue(challenge.examples.contains { $0.target == 1 }, "level \(index + 1) seed \(seed): a positive example")
                XCTAssertTrue(challenge.examples.contains { $0.target == 0 }, "level \(index + 1) seed \(seed): a negative example")
                XCTAssertTrue(challenge.examples.allSatisfy { challenge.solution.predict($0.inputs) == $0.target }, "the stored solution fits")
                XCTAssertEqual(Set(challenge.examples.map(\.id)).count, challenge.examples.count, "no duplicate rows")
                if index == 2 {
                    XCTAssertTrue(challenge.network.isTwoLayer)
                    XCTAssertGreaterThanOrEqual(challenge.examples.count, 4)
                    XCTAssertFalse(NeuronContent.isLinearlySeparable(challenge.examples, inputs: inputs), "level 3 needs the hidden layer")
                } else {
                    XCTAssertFalse(challenge.network.isTwoLayer)
                }
                XCTAssertFalse(challenge.isSolved, "a blank network never fits both classes")
            }
        }
    }

    func testDialsHintsAndScore() {
        var challenge = NeuronContent.make(spec: specs[0], difficulty: difficulty, seed: 3)
        let dials = challenge.network.dialCount
        XCTAssertEqual(dials, 3)
        challenge.cycleWeight(.outputWeight(index: 0))
        XCTAssertEqual(challenge.network.value(of: .outputWeight(index: 0)), 1)
        challenge.cycleWeight(.outputWeight(index: 0))
        XCTAssertEqual(challenge.network.value(of: .outputWeight(index: 0)), -1)
        challenge.cycleWeight(.outputWeight(index: 0))
        XCTAssertEqual(challenge.network.value(of: .outputWeight(index: 0)), 0)
        challenge.adjustThreshold(.outputThreshold, by: 1)
        XCTAssertEqual(challenge.network.value(of: .outputThreshold), 2)
        XCTAssertEqual(challenge.turns, 4)
        var hints = 0
        while !challenge.isSolved, hints < dials + 1 {
            XCTAssertNotNil(challenge.hint())
            hints += 1
        }
        XCTAssertTrue(challenge.isSolved, "hints converge to the solution")
        XCTAssertLessThanOrEqual(hints, dials)
        XCTAssertEqual(challenge.scoreAccuracy, 1, accuracy: 1e-12, "few turns → full score")
        var twiddler = NeuronContent.make(spec: specs[0], difficulty: difficulty, seed: 3)
        for _ in 0..<30 { twiddler.cycleWeight(.outputWeight(index: 1)) }
        XCTAssertLessThan(twiddler.scoreAccuracy, 0.5, "unsolved scores half the fraction right")
        while !twiddler.isSolved { twiddler.hint() }
        XCTAssertEqual(twiddler.scoreAccuracy, max(0.7, 1 - 0.02 * Double(max(0, twiddler.turns - 2 * dials))), accuracy: 1e-12)
    }

    func testGradientStepReducesLoss() {
        let examples = NeuronContent.allRows(inputs: 4).map { NeuronExample(inputs: $0, target: NeuronContent.TrainingTarget.atLeastThree.label($0)) }
        var network = SigmoidNetwork(inputs: 4, hidden: 3, seed: 11)
        let before = network.loss(on: examples)
        let reported = network.trainEpoch(on: examples, learningRate: 0.1)
        XCTAssertEqual(reported, before, accuracy: 1e-12, "the epoch reports the loss before updating")
        XCTAssertLessThan(network.loss(on: examples), before, "a small step descends")
    }

    func testTrainingConvergesAtTheMediumRate() {
        for target in NeuronContent.TrainingTarget.allCases {
            for seed in 1...20 {
                var challenge = TrainingChallenge(spec: specs[3],
                                                  examples: NeuronContent.allRows(inputs: 4).map { NeuronExample(inputs: $0, target: target.label($0)) },
                                                  seed: UInt64(seed))
                XCTAssertEqual(challenge.learningRate, 3.0, accuracy: 1e-12)
                var presses = 0
                while !challenge.isSolved, presses < 12 {
                    challenge.train()
                    presses += 1
                }
                XCTAssertTrue(challenge.isSolved, "\(target) seed \(seed): must converge within 12 presses (720 epochs)")
                XCTAssertEqual(challenge.correctCount, 16)
                XCTAssertGreaterThanOrEqual(challenge.scoreAccuracy, 0.6)
                XCTAssertEqual(challenge.presses, presses)
                if let first = challenge.lossHistory.first, let last = challenge.lossHistory.last {
                    XCTAssertLessThan(last, first, "the error goes down")
                }
            }
        }
    }

    func testTrainingContentRestartAndRates() {
        var challenge = NeuronContent.makeTraining(spec: specs[3], difficulty: difficulty, seed: 5)
        XCTAssertEqual(challenge.examples.count, 16)
        XCTAssertEqual(challenge.learningRates, [0.5, 3.0, 20.0])
        XCTAssertEqual(NeuronContent.trainingTarget(seed: 5), .firstTwoDiffer)
        XCTAssertEqual(NeuronContent.trainingTarget(seed: 6), .atLeastThree)
        let initial = challenge.network
        challenge.selectRate(0)
        XCTAssertEqual(challenge.learningRate, 0.5, accuracy: 1e-12)
        challenge.selectRate(9)
        XCTAssertEqual(challenge.rateIndex, 2)
        challenge.train()
        XCTAssertEqual(challenge.presses, 1)
        XCTAssertFalse(challenge.lossHistory.isEmpty)
        challenge.restart()
        XCTAssertEqual(challenge.restarts, 1)
        XCTAssertTrue(challenge.lossHistory.isEmpty)
        XCTAssertNotEqual(challenge.network, initial, "a restart draws new weights")
        XCTAssertEqual(challenge.presses, 1, "presses already spent still count")
        XCTAssertLessThan(challenge.scoreAccuracy, 0.6)
    }
}
