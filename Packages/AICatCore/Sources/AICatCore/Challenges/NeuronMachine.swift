import Foundation

// MARK: - Examples and ternary neurons (levels 1–3: dials)

/// One labelled row: lamps that are on (1) or off (0) and whether the output lamp should light.
public struct NeuronExample: Hashable, Sendable, Identifiable {
    public let inputs: [Int]
    public let target: Int

    public init(inputs: [Int], target: Int) {
        self.inputs = inputs
        self.target = target
    }

    public var id: String { inputs.map(String.init).joined() }
}

/// A neuron with weights in {−1, 0, +1} that fires when Σ wᵢxᵢ ≥ threshold ("needs at least k").
public struct TernaryNeuron: Hashable, Sendable {
    public var weights: [Int]
    public var threshold: Int

    public init(weights: [Int], threshold: Int) {
        self.weights = weights
        self.threshold = threshold
    }

    public func sum(_ inputs: [Int]) -> Int {
        zip(weights, inputs).reduce(0) { $0 + $1.0 * $1.1 }
    }

    public func fires(_ inputs: [Int]) -> Bool { sum(inputs) >= threshold }
}

public enum NeuronDial: Hashable, Sendable {
    case hiddenWeight(neuron: Int, input: Int)
    case hiddenThreshold(neuron: Int)
    case outputWeight(index: Int)
    case outputThreshold
}

/// One or two layers of ternary neurons. With hidden neurons, the output neuron reads the hidden lamps.
public struct TernaryNetwork: Hashable, Sendable {
    public let inputCount: Int
    public var hidden: [TernaryNeuron]
    public var output: TernaryNeuron

    public init(inputCount: Int, hidden: [TernaryNeuron], output: TernaryNeuron) {
        self.inputCount = inputCount
        self.hidden = hidden
        self.output = output
    }

    /// All weights off and every threshold at 1.
    public static func blank(inputs: Int, hiddenCount: Int) -> TernaryNetwork {
        let hidden = (0..<hiddenCount).map { _ in TernaryNeuron(weights: Array(repeating: 0, count: inputs), threshold: 1) }
        let outputInputs = hiddenCount == 0 ? inputs : hiddenCount
        return TernaryNetwork(inputCount: inputs, hidden: hidden,
                              output: TernaryNeuron(weights: Array(repeating: 0, count: outputInputs), threshold: 1))
    }

    public var isTwoLayer: Bool { !hidden.isEmpty }

    public func hiddenActivations(_ inputs: [Int]) -> [Int] {
        hidden.map { $0.fires(inputs) ? 1 : 0 }
    }

    /// What the output neuron sees: the input lamps, or the hidden lamps in a two-layer network.
    public func outputInputs(_ inputs: [Int]) -> [Int] {
        isTwoLayer ? hiddenActivations(inputs) : inputs
    }

    public func predict(_ inputs: [Int]) -> Int {
        output.fires(outputInputs(inputs)) ? 1 : 0
    }

    public var allDials: [NeuronDial] {
        var dials: [NeuronDial] = []
        for (n, neuron) in hidden.enumerated() {
            for i in neuron.weights.indices { dials.append(.hiddenWeight(neuron: n, input: i)) }
            dials.append(.hiddenThreshold(neuron: n))
        }
        for i in output.weights.indices { dials.append(.outputWeight(index: i)) }
        dials.append(.outputThreshold)
        return dials
    }

    public var dialCount: Int { allDials.count }

    public func value(of dial: NeuronDial) -> Int {
        switch dial {
        case .hiddenWeight(let n, let i): return hidden[n].weights[i]
        case .hiddenThreshold(let n): return hidden[n].threshold
        case .outputWeight(let i): return output.weights[i]
        case .outputThreshold: return output.threshold
        }
    }

    /// Sets a dial, clamping weights to −1…1 and thresholds to 0…(number of inputs of that neuron).
    public mutating func set(_ dial: NeuronDial, to value: Int) {
        switch dial {
        case .hiddenWeight(let n, let i):
            hidden[n].weights[i] = max(-1, min(1, value))
        case .hiddenThreshold(let n):
            hidden[n].threshold = max(0, min(hidden[n].weights.count, value))
        case .outputWeight(let i):
            output.weights[i] = max(-1, min(1, value))
        case .outputThreshold:
            output.threshold = max(0, min(output.weights.count, value))
        }
    }
}

/// The child sets the dials by hand until the lamp agrees with every example.
public struct NeuronChallenge: Sendable {
    public let spec: ChallengeSpec
    public let examples: [NeuronExample]
    public let solution: TernaryNetwork
    public private(set) var network: TernaryNetwork
    public private(set) var turns = 0
    public private(set) var hintsUsed = 0

    public init(spec: ChallengeSpec, examples: [NeuronExample], solution: TernaryNetwork, network: TernaryNetwork) {
        self.spec = spec
        self.examples = examples
        self.solution = solution
        self.network = network
    }

    public var correctCount: Int { examples.filter { network.predict($0.inputs) == $0.target }.count }
    public var correctFraction: Double { examples.isEmpty ? 0 : Double(correctCount) / Double(examples.count) }
    public var isSolved: Bool { !examples.isEmpty && correctCount == examples.count }

    /// Tapping a wire cycles off → excite (+1) → inhibit (−1) → off.
    public mutating func cycleWeight(_ dial: NeuronDial) {
        let current = network.value(of: dial)
        let next = current == 0 ? 1 : (current == 1 ? -1 : 0)
        network.set(dial, to: next)
        turns += 1
    }

    public mutating func adjustThreshold(_ dial: NeuronDial, by delta: Int) {
        network.set(dial, to: network.value(of: dial) + delta)
        turns += 1
    }

    /// A hint is one dial change. Preferred: the single change that fixes the most examples without moving
    /// further from AI CAT's own solution (so a child's different-but-valid design is respected); otherwise the
    /// first dial that differs from the closest equivalent solution. Each hint strictly improves the
    /// (examples right, distance to solution) pair, so hints always converge. Nil when already solved.
    @discardableResult
    public mutating func hint() -> NeuronDial? {
        hintsUsed += 1
        guard !isSolved else { return nil }
        let target = closestSolution()
        let baseline = correctCount
        let baseDistance = Self.distance(network, target)
        var best: (dial: NeuronDial, value: Int, correct: Int, distance: Int)?
        for dial in network.allDials {
            let current = network.value(of: dial)
            for candidate in candidateValues(for: dial) where candidate != current {
                var trial = network
                trial.set(dial, to: candidate)
                let score = examples.filter { trial.predict($0.inputs) == $0.target }.count
                let distance = Self.distance(trial, target)
                guard score > baseline, distance <= baseDistance else { continue }
                if let current = best {
                    if score > current.correct || (score == current.correct && distance < current.distance) {
                        best = (dial, candidate, score, distance)
                    }
                } else {
                    best = (dial, candidate, score, distance)
                }
            }
        }
        if let best {
            network.set(best.dial, to: best.value)
            return best.dial
        }
        for dial in network.allDials where network.value(of: dial) != target.value(of: dial) {
            network.set(dial, to: target.value(of: dial))
            return dial
        }
        return nil
    }

    /// Dials that differ between two networks of the same shape.
    static func distance(_ a: TernaryNetwork, _ b: TernaryNetwork) -> Int {
        a.allDials.filter { a.value(of: $0) != b.value(of: $0) }.count
    }

    /// With two hidden neurons the solution with them swapped is the same function: hint towards the closer one.
    private func closestSolution() -> TernaryNetwork {
        guard solution.hidden.count == 2, solution.output.weights.count == 2 else { return solution }
        var swapped = solution
        swapped.hidden = [solution.hidden[1], solution.hidden[0]]
        swapped.output.weights = [solution.output.weights[1], solution.output.weights[0]]
        return Self.distance(network, swapped) < Self.distance(network, solution) ? swapped : solution
    }

    private func candidateValues(for dial: NeuronDial) -> [Int] {
        switch dial {
        case .hiddenWeight, .outputWeight: return [-1, 0, 1]
        case .hiddenThreshold(let n): return Array(0...network.hidden[n].weights.count)
        case .outputThreshold: return Array(0...network.output.weights.count)
        }
    }

    /// Solved = 1 minus 0.02 per turn beyond two per dial (never below 0.7); unsolved = half the fraction right.
    public var scoreAccuracy: Double {
        guard isSolved else { return correctFraction * 0.5 }
        let excess = max(0, turns - 2 * network.dialCount)
        return max(0.7, 1 - 0.02 * Double(excess))
    }
}

// MARK: - Sigmoid network trained by gradient descent (level 4)

/// inputs → hidden (sigmoid) → 1 output (sigmoid), trained with full-batch gradient descent on cross-entropy.
public struct SigmoidNetwork: Hashable, Sendable {
    public private(set) var w1: [[Double]]
    public private(set) var b1: [Double]
    public private(set) var w2: [Double]
    public private(set) var b2: Double

    public var inputCount: Int { w1.first?.count ?? 0 }
    public var hiddenCount: Int { w1.count }

    public init(inputs: Int, hidden: Int, seed: UInt64) {
        var rng = SeededGenerator(seed: seed)
        w1 = (0..<hidden).map { _ in (0..<inputs).map { _ in rng.nextDouble(in: -0.8..<0.8) } }
        b1 = (0..<hidden).map { _ in rng.nextDouble(in: -0.8..<0.8) }
        w2 = (0..<hidden).map { _ in rng.nextDouble(in: -0.8..<0.8) }
        b2 = rng.nextDouble(in: -0.8..<0.8)
    }

    public static func sigmoid(_ z: Double) -> Double {
        1 / (1 + exp(-max(-60, min(60, z))))
    }

    public func forward(_ inputs: [Int]) -> (hidden: [Double], output: Double) {
        let x = inputs.map(Double.init)
        let h = (0..<hiddenCount).map { j -> Double in
            Self.sigmoid(zip(w1[j], x).reduce(0) { $0 + $1.0 * $1.1 } + b1[j])
        }
        let o = Self.sigmoid(zip(w2, h).reduce(0) { $0 + $1.0 * $1.1 } + b2)
        return (h, o)
    }

    public func predict(_ inputs: [Int]) -> Int { forward(inputs).output > 0.5 ? 1 : 0 }

    public func correctCount(on examples: [NeuronExample]) -> Int {
        examples.filter { predict($0.inputs) == $0.target }.count
    }

    /// Mean cross-entropy loss.
    public func loss(on examples: [NeuronExample]) -> Double {
        guard !examples.isEmpty else { return 0 }
        let total = examples.reduce(0.0) { partial, example in
            let o = forward(example.inputs).output
            let t = Double(example.target)
            return partial - (t * log(max(o, 1e-12)) + (1 - t) * log(max(1 - o, 1e-12)))
        }
        return total / Double(examples.count)
    }

    /// One full-batch gradient-descent epoch. Returns the mean loss measured before the update.
    @discardableResult
    public mutating func trainEpoch(on examples: [NeuronExample], learningRate: Double) -> Double {
        guard !examples.isEmpty else { return 0 }
        var gW1 = w1.map { $0.map { _ in 0.0 } }
        var gb1 = b1.map { _ in 0.0 }
        var gW2 = w2.map { _ in 0.0 }
        var gb2 = 0.0
        var total = 0.0
        for example in examples {
            let x = example.inputs.map(Double.init)
            let (h, o) = forward(example.inputs)
            let t = Double(example.target)
            total -= t * log(max(o, 1e-12)) + (1 - t) * log(max(1 - o, 1e-12))
            let dOutput = o - t   // ∂loss/∂z for sigmoid + cross-entropy
            for j in 0..<hiddenCount {
                gW2[j] += dOutput * h[j]
                let dHidden = dOutput * w2[j] * h[j] * (1 - h[j])
                for i in 0..<inputCount { gW1[j][i] += dHidden * x[i] }
                gb1[j] += dHidden
            }
            gb2 += dOutput
        }
        let n = Double(examples.count)
        for j in 0..<hiddenCount {
            for i in 0..<inputCount { w1[j][i] -= learningRate * gW1[j][i] / n }
            b1[j] -= learningRate * gb1[j] / n
            w2[j] -= learningRate * gW2[j] / n
        }
        b2 -= learningRate * gb2 / n
        return total / n
    }
}

/// The network trains itself; the child picks the learning rate, presses "train" and watches the error fall.
public struct TrainingChallenge: Sendable {
    public let spec: ChallengeSpec
    public let examples: [NeuronExample]
    public let learningRates: [Double]
    public let epochsPerPress: Int
    public let hiddenCount: Int
    public private(set) var rateIndex: Int
    public private(set) var network: SigmoidNetwork
    public private(set) var presses = 0
    public private(set) var restarts = 0
    public private(set) var lossHistory: [Double] = []
    public private(set) var isSolved = false
    private let seed: UInt64

    public init(spec: ChallengeSpec, examples: [NeuronExample], seed: UInt64, hiddenCount: Int = 3,
                learningRates: [Double] = [0.5, 3.0, 20.0], epochsPerPress: Int = 60, rateIndex: Int = 1) {
        self.spec = spec
        self.examples = examples
        self.seed = seed
        self.hiddenCount = hiddenCount
        self.learningRates = learningRates
        self.epochsPerPress = epochsPerPress
        self.rateIndex = max(0, min(learningRates.count - 1, rateIndex))
        let inputs = examples.first?.inputs.count ?? 2
        network = SigmoidNetwork(inputs: inputs, hidden: hiddenCount, seed: seed)
    }

    public var learningRate: Double { learningRates[rateIndex] }
    public var correctCount: Int { network.correctCount(on: examples) }
    public var correctFraction: Double { examples.isEmpty ? 0 : Double(correctCount) / Double(examples.count) }
    public var currentLoss: Double { network.loss(on: examples) }
    public var epochsTrained: Int { lossHistory.count }

    public mutating func selectRate(_ index: Int) {
        rateIndex = max(0, min(learningRates.count - 1, index))
    }

    /// One press: up to `epochsPerPress` epochs, stopping early once every example is right.
    @discardableResult
    public mutating func train() -> [Double] {
        guard !isSolved, !examples.isEmpty else { return [] }
        presses += 1
        var losses: [Double] = []
        for _ in 0..<epochsPerPress {
            losses.append(network.trainEpoch(on: examples, learningRate: learningRate))
            if network.correctCount(on: examples) == examples.count { break }
        }
        lossHistory.append(contentsOf: losses)
        if network.correctCount(on: examples) == examples.count { isSolved = true }
        return losses
    }

    /// New random weights (a fresh start keeps the presses already spent).
    public mutating func restart() {
        guard !isSolved else { return }
        restarts += 1
        network = SigmoidNetwork(inputs: examples.first?.inputs.count ?? 2, hidden: hiddenCount,
                                 seed: seed &+ UInt64(restarts) &* 7_919)
        lossHistory = []
    }

    /// Solved within three presses = 1; each extra press costs 0.05, never below 0.6. Unsolved = half the fraction right.
    public var scoreAccuracy: Double {
        guard isSolved else { return correctFraction * 0.5 }
        return max(0.6, 1 - 0.05 * Double(max(0, presses - 3)))
    }
}

// MARK: - Content

public enum NeuronContent {
    public static func allRows(inputs: Int) -> [[Int]] {
        (0..<(1 << inputs)).map { pattern in (0..<inputs).map { (pattern >> (inputs - 1 - $0)) & 1 } }
    }

    /// Target networks per level: every one of them is reachable with the dials the child has.
    static func targets(inputs: Int, layers: Int) -> [TernaryNetwork] {
        func single(_ w: [Int], _ k: Int) -> TernaryNetwork {
            TernaryNetwork(inputCount: w.count, hidden: [], output: TernaryNeuron(weights: w, threshold: k))
        }
        func double(_ h1: ([Int], Int), _ h2: ([Int], Int), _ out: ([Int], Int)) -> TernaryNetwork {
            TernaryNetwork(inputCount: h1.0.count,
                           hidden: [TernaryNeuron(weights: h1.0, threshold: h1.1), TernaryNeuron(weights: h2.0, threshold: h2.1)],
                           output: TernaryNeuron(weights: out.0, threshold: out.1))
        }
        if layers >= 2 {
            switch inputs {
            case ...2:
                return [
                    double(([1, 1], 2), ([1, 1], 1), ([-1, 1], 1)),    // XOR
                    double(([1, 1], 2), ([1, 1], 1), ([1, -1], 0)),    // same (XNOR)
                ]
            case 3:
                return [
                    double(([1, 1, 0], 2), ([1, 1, 0], 1), ([-1, 1], 1)),   // lamp 1 XOR lamp 2
                    double(([1, 0, 1], 2), ([1, 0, 1], 1), ([-1, 1], 1)),   // lamp 1 XOR lamp 3
                    double(([1, 1, 1], 1), ([1, 1, 1], 2), ([1, -1], 1)),   // exactly one lamp on
                ]
            default:
                return [
                    double(([1, 1, 0, 0], 2), ([1, 1, 0, 0], 1), ([-1, 1], 1)),   // lamp 1 XOR lamp 2
                    double(([1, 1, 1, 1], 1), ([1, 1, 1, 1], 2), ([1, -1], 1)),   // exactly one lamp on
                    double(([0, 0, 1, 1], 2), ([0, 0, 1, 1], 1), ([-1, 1], 1)),   // lamp 3 XOR lamp 4
                ]
            }
        }
        if inputs >= 4 {
            return [
                single([1, 1, 1, 1], 2),    // at least two
                single([1, 0, 0, 1], 2),    // first and last
                single([0, 1, 1, 0], 1),    // either middle lamp
                single([1, 0, 0, -1], 1),   // first on, last off
                single([1, 1, 1, 1], 4),    // all four
            ]
        }
        if inputs <= 2 {
            return [
                single([1, 1], 2),    // both
                single([1, 1], 1),    // either
                single([1, 0], 1),    // only the first lamp matters
                single([1, -1], 1),   // first on, second off
                single([-1, 1], 1),   // second on, first off
                single([0, -1], 0),   // second lamp off
            ]
        }
        return [
            single([1, 1, 1], 2),    // at least two
            single([1, 1, 1], 3),    // all three
            single([1, 1, 0], 2),    // first two
            single([1, 0, 1], 1),    // first or third
            single([0, 1, -1], 1),   // second on, third off
            single([1, 1, 1], 1),    // any lamp
        ]
    }

    /// Can one dial-neuron (weights −1…1, threshold 0…n) fit all the rows? Brute force, 3ⁿ·(n+1) candidates.
    public static func isLinearlySeparable(_ examples: [NeuronExample], inputs: Int) -> Bool {
        let combos = Int(pow(3.0, Double(inputs)))
        for code in 0..<combos {
            var weights: [Int] = []
            var rest = code
            for _ in 0..<inputs {
                weights.append(rest % 3 - 1)
                rest /= 3
            }
            for threshold in 0...inputs {
                let neuron = TernaryNeuron(weights: weights, threshold: threshold)
                if examples.allSatisfy({ (neuron.fires($0.inputs) ? 1 : 0) == $0.target }) { return true }
            }
        }
        return false
    }

    /// params: "inputs" (2…4), "layers" (1|2). Rows are a seeded sample of the truth table with both answers
    /// present; for two layers the sample is guaranteed to need the hidden layer.
    public static func make(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> NeuronChallenge {
        let requestedInputs = max(2, min(4, spec.param("inputs", default: 2)))
        let layers = max(1, min(2, spec.param("layers", default: 1)))
        var rng = SeededGenerator(seed: seed)
        let options = targets(inputs: requestedInputs, layers: layers)
        let solution = options[Int(rng.next() % UInt64(options.count))]
        let inputs = solution.inputCount   // the dials always match the stored solution
        let labelled = allRows(inputs: inputs).map { NeuronExample(inputs: $0, target: solution.predict($0)) }
        var count = difficulty.itemCount(in: spec.itemRange)
        if layers == 2 { count = max(count, 4) }
        count = max(2, min(count, labelled.count))

        var chosen: [NeuronExample] = []
        for _ in 0..<40 {
            var pool = labelled
            pool.shuffle(using: &rng)
            var sample = Array(pool.prefix(count))
            if !sample.contains(where: { $0.target == 1 }), let positive = pool.first(where: { $0.target == 1 }) { sample[0] = positive }
            if !sample.contains(where: { $0.target == 0 }), let negative = pool.first(where: { $0.target == 0 }) { sample[sample.count - 1] = negative }
            chosen = sample
            if layers == 1 || !isLinearlySeparable(sample, inputs: inputs) { break }
            chosen = []
        }
        if chosen.isEmpty { chosen = labelled }
        chosen.sort { $0.inputs.lexicographicallyPrecedes($1.inputs) }
        let network = TernaryNetwork.blank(inputs: inputs, hiddenCount: layers == 2 ? 2 : 0)
        return NeuronChallenge(spec: spec, examples: chosen, solution: solution, network: network)
    }

    public enum TrainingTarget: Int, CaseIterable, Sendable {
        case atLeastThree = 0, firstTwoDiffer

        public func label(_ inputs: [Int]) -> Int {
            switch self {
            case .atLeastThree: return inputs.reduce(0, +) >= 3 ? 1 : 0
            case .firstTwoDiffer: return inputs.count >= 2 && inputs[0] != inputs[1] ? 1 : 0
            }
        }

        public var key: String {
            switch self {
            case .atLeastThree: return "neuron.target.at_least_three"
            case .firstTwoDiffer: return "neuron.target.first_two_differ"
            }
        }
    }

    public static func trainingTarget(seed: UInt64) -> TrainingTarget {
        TrainingTarget(rawValue: Int(seed % UInt64(TrainingTarget.allCases.count))) ?? .atLeastThree
    }

    /// params: "inputs" (4). The whole truth table is the data set; the target alternates by seed.
    public static func makeTraining(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> TrainingChallenge {
        let inputs = max(3, min(4, spec.param("inputs", default: 4)))
        let target = trainingTarget(seed: seed)
        let examples = allRows(inputs: inputs).map { NeuronExample(inputs: $0, target: target.label($0)) }
        return TrainingChallenge(spec: spec, examples: examples, seed: seed)
    }
}
