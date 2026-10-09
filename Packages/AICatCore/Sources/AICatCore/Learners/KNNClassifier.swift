import Foundation

public struct FeatureVector: Hashable, Codable, Sendable {
    public var values: [Double]

    public init(_ values: [Double]) {
        self.values = values
    }

    public static func distance(_ a: FeatureVector, _ b: FeatureVector) -> Double {
        let n = min(a.values.count, b.values.count)
        var sum = 0.0
        for i in 0..<n {
            let d = a.values[i] - b.values[i]
            sum += d * d
        }
        return sum.squareRoot()
    }
}

public struct LabeledFeature: Hashable, Codable, Sendable {
    public var features: FeatureVector
    public var label: String

    public init(features: FeatureVector, label: String) {
        self.features = features
        self.label = label
    }
}

/// k-nearest-neighbours with majority vote. Ties: smallest summed distance, then alphabetical label.
/// This is the "brain" AI CAT uses in the Data Library: the child's labels are its whole knowledge.
public struct KNNClassifier: Sendable, Equatable {
    public var k: Int
    public var examples: [LabeledFeature]

    public init(k: Int = 3, examples: [LabeledFeature]) {
        self.k = max(1, k)
        self.examples = examples
    }

    public struct Prediction: Equatable, Sendable {
        public var label: String
        public var votes: [String: Int]
        /// Share of the neighbours that agree with the winning label.
        public var confidence: Double
    }

    public func predict(_ query: FeatureVector) -> Prediction? {
        guard !examples.isEmpty else { return nil }
        let scored = examples
            .map { (distance: FeatureVector.distance($0.features, query), label: $0.label) }
            .sorted { $0.distance < $1.distance }
        let neighbours = scored.prefix(k)
        var votes: [String: Int] = [:]
        var distanceSum: [String: Double] = [:]
        for n in neighbours {
            votes[n.label, default: 0] += 1
            distanceSum[n.label, default: 0] += n.distance
        }
        guard let best = votes.values.max() else { return nil }
        let tied = votes.filter { $0.value == best }.map { $0.key }
        let winner: String
        if tied.count == 1 {
            winner = tied[0]
        } else {
            winner = tied.sorted { lhs, rhs in
                let dl = distanceSum[lhs] ?? 0, dr = distanceSum[rhs] ?? 0
                if dl != dr { return dl < dr }
                return lhs < rhs
            }[0]
        }
        return Prediction(label: winner, votes: votes, confidence: Double(best) / Double(neighbours.count))
    }

    /// Fraction of test items predicted correctly (unpredictable items count as wrong).
    public func accuracy(on tests: [LabeledFeature]) -> Double {
        guard !tests.isEmpty else { return 0 }
        var correct = 0
        for t in tests where predict(t.features)?.label == t.label { correct += 1 }
        return Double(correct) / Double(tests.count)
    }
}
