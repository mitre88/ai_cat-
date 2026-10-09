import XCTest
@testable import AICatCore

/// Cross-checks the seeded algorithms against the independent Python reference (Tools/reference_rl_nn.py).
final class GoldenRLTests: XCTestCase {
    func testSplitMixMatchesPython() {
        var rng = SeededGenerator(seed: 1)
        XCTAssertEqual([rng.next(), rng.next(), rng.next()], GoldenRLValues.splitMixSeed1)
        var unit = SeededGenerator(seed: 2024)
        XCTAssertEqual(unit.nextUnit(), GoldenRLValues.mazeRandomDraws[0], accuracy: 0)
    }

    func testQLearningMatchesPython() {
        var world = MazeContent.layout(level: 1, variant: 0)
        world[MazeCell(3, 3)] = .treat
        var learner = MazeLearner(size: world.size, epsilon: 0.3)
        var rng = SeededGenerator(seed: 2024)
        var outcomes: [String] = []
        var lengths: [Int] = []
        for _ in 0..<6 {
            let episode = learner.runEpisode(in: world, using: &rng)
            outcomes.append(String(describing: episode.outcome))
            lengths.append(episode.steps.count)
        }
        XCTAssertEqual(outcomes, GoldenRLValues.mazeOutcomes)
        XCTAssertEqual(lengths, GoldenRLValues.mazeEpisodeLengths)
        let q = learner.q.actionValues(at: world.start)
        for (value, golden) in zip(q, GoldenRLValues.mazeStartQ) {
            XCTAssertEqual(value, golden, accuracy: 1e-12)
        }
        let greedy = learner.greedyEpisode(in: world)
        XCTAssertEqual(String(describing: greedy.outcome), GoldenRLValues.mazeGreedyOutcome)
        XCTAssertEqual(greedy.path.map { [$0.x, $0.y] }, GoldenRLValues.mazeGreedyPath)
    }

    func testSigmoidNetworkMatchesPython() {
        let examples = NeuronContent.allRows(inputs: 4).map { NeuronExample(inputs: $0, target: NeuronContent.TrainingTarget.atLeastThree.label($0)) }
        var network = SigmoidNetwork(inputs: 4, hidden: 3, seed: 5)
        let first = [network.w1[0][0], network.b1[0], network.w2[0], network.b2]
        for (value, golden) in zip(first, GoldenRLValues.networkFirstWeights) {
            XCTAssertEqual(value, golden, accuracy: 1e-15)
        }
        XCTAssertEqual(network.loss(on: examples), GoldenRLValues.networkInitialLoss, accuracy: 1e-12)
        XCTAssertEqual(network.trainEpoch(on: examples, learningRate: 3.0), GoldenRLValues.networkFirstEpochLoss, accuracy: 1e-12)
        for _ in 0..<9 { network.trainEpoch(on: examples, learningRate: 3.0) }
        XCTAssertEqual(network.loss(on: examples), GoldenRLValues.networkLossAfterTenEpochs, accuracy: 1e-10)
        XCTAssertEqual(network.correctCount(on: examples), GoldenRLValues.networkCorrectAfterTenEpochs)
    }

    func testStoryGrammarMatchesPython() {
        let seeds = StorySeeds(character: StoryBank.characters[0], place: StoryBank.places[0], object: StoryBank.objects[0])
        XCTAssertEqual(StoryGenerator.generate(seeds: seeds, seed: 42).variants, GoldenRLValues.storyVariantsSeed42)
    }
}
