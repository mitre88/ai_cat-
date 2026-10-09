import Foundation

public enum Species: String, CaseIterable, Codable, Sendable, Identifiable {
    case cat, dog, bird

    public var id: String { rawValue }

    public var nameKey: TextKey {
        switch self {
        case .cat: return TextKey("species.cat")
        case .dog: return TextKey("species.dog")
        case .bird: return TextKey("species.bird")
        }
    }

    /// Prototype features: [size, pointy ears, song].
    public var centroid: [Double] {
        switch self {
        case .cat: return [0.30, 0.90, 0.20]
        case .dog: return [0.60, 0.40, 0.60]
        case .bird: return [0.10, 0.00, 0.90]
        }
    }
}

public enum AnimalFeature: Int, CaseIterable, Codable, Sendable {
    case size = 0, ears, song

    public var nameKey: TextKey {
        switch self {
        case .size: return TextKey("feature.size")
        case .ears: return TextKey("feature.ears")
        case .song: return TextKey("feature.song")
        }
    }
}

public struct AnimalCard: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let species: Species        // ground truth (hidden from the child until labelled)
    public let features: FeatureVector
    public let variant: Int            // 0…2, picks an art variant

    public init(id: String, species: Species, features: FeatureVector, variant: Int) {
        self.id = id
        self.species = species
        self.features = features
        self.variant = variant
    }
}

public enum LabelOutcome: Equatable, Sendable {
    case correct
    case wrong(expected: Species)
    case ignored
}

/// Pure state of one Data Library challenge. Wrong labels stick (and lower AI CAT's accuracy)
/// until the child fixes them: data quality is the lesson.
public struct LabelingChallenge: Codable, Sendable {
    public let spec: ChallengeSpec
    public let species: [Species]
    public let cards: [AnimalCard]
    public let testSet: [AnimalCard]

    public private(set) var labels: [String: Species] = [:]
    public private(set) var trapIDs: Set<String> = []
    public private(set) var attempts = 0
    public private(set) var mistakes = 0
    public private(set) var hintsUsed = 0

    public init(spec: ChallengeSpec, species: [Species], cards: [AnimalCard], testSet: [AnimalCard], traps: [String: Species]) {
        self.spec = spec
        self.species = species
        self.cards = cards
        self.testSet = testSet
        labels = traps
        trapIDs = Set(traps.keys)
    }

    public func card(id: String) -> AnimalCard? { cards.first { $0.id == id } }
    public func label(of cardID: String) -> Species? { labels[cardID] }
    public func isCorrectlyLabeled(_ card: AnimalCard) -> Bool { labels[card.id] == card.species }
    public func isTrap(_ cardID: String) -> Bool { trapIDs.contains(cardID) }

    public var unlabeled: [AnimalCard] { cards.filter { labels[$0.id] == nil } }
    public var wronglyLabeled: [AnimalCard] { cards.filter { labels[$0.id] != nil && labels[$0.id] != $0.species } }
    public var isComplete: Bool { cards.allSatisfy { isCorrectlyLabeled($0) } }

    /// Correct answers over attempts (1 when nothing attempted yet).
    public var childAccuracy: Double {
        attempts == 0 ? 1 : Double(attempts - mistakes) / Double(attempts)
    }

    public mutating func label(cardID: String, as species: Species) -> LabelOutcome {
        guard let card = card(id: cardID), self.species.contains(species) else { return .ignored }
        if labels[cardID] == species { return .ignored }
        attempts += 1
        labels[cardID] = species
        if species == card.species {
            trapIDs.remove(cardID)
            return .correct
        }
        mistakes += 1
        return .wrong(expected: card.species)
    }

    public mutating func useHint() -> (card: AnimalCard, species: Species)? {
        guard let card = wronglyLabeled.first ?? unlabeled.first else { return nil }
        hintsUsed += 1
        return (card, card.species)
    }

    // MARK: AI CAT's brain

    public var classifier: KNNClassifier {
        let examples = cards.compactMap { card -> LabeledFeature? in
            guard let label = labels[card.id] else { return nil }
            return LabeledFeature(features: card.features, label: label.rawValue)
        }
        return KNNClassifier(k: 3, examples: examples)
    }

    /// Accuracy of AI CAT on the hidden test set (0 with no data).
    public var aiAccuracy: Double {
        guard !labels.isEmpty else { return 0 }
        return classifier.accuracy(on: testSet.map { LabeledFeature(features: $0.features, label: $0.species.rawValue) })
    }

    public func aiGuess(for card: AnimalCard) -> KNNClassifier.Prediction? {
        classifier.predict(card.features)
    }

    public var labeledCount: Int { labels.count }
}

public enum LabelingContent {
    /// params: "species" (2 or 3), "traps" (pre-filled wrong labels), "noise" (1 = noisier features).
    public static func make(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> LabelingChallenge {
        var rng = SeededGenerator(seed: seed)
        let speciesCount = max(2, min(3, spec.param("species", default: 2)))
        let species = Array(Species.allCases.prefix(speciesCount))
        let noise = spec.param("noise", default: 0) == 1 ? 0.15 : 0.08
        let count = max(difficulty.itemCount(in: spec.itemRange), speciesCount * 2)

        var cards: [AnimalCard] = []
        for i in 0..<count {
            let s = species[i % speciesCount]
            cards.append(AnimalCard(id: "card\(i + 1)", species: s, features: jitter(s.centroid, amount: noise, rng: &rng), variant: (i / speciesCount) % 3))
        }
        cards.shuffle(using: &rng)

        var tests: [AnimalCard] = []
        for (i, s) in species.enumerated() {
            for j in 0..<3 {
                tests.append(AnimalCard(id: "test\(i)_\(j)", species: s, features: jitter(s.centroid, amount: 0.06, rng: &rng), variant: j))
            }
        }

        var traps: [String: Species] = [:]
        let trapCount = min(spec.param("traps", default: 0), cards.count / 3)
        for card in cards.prefix(trapCount) {
            let wrong = species.first { $0 != card.species } ?? card.species
            traps[card.id] = wrong
        }

        return LabelingChallenge(spec: spec, species: species, cards: cards, testSet: tests, traps: traps)
    }

    private static func jitter(_ centroid: [Double], amount: Double, rng: inout SeededGenerator) -> FeatureVector {
        FeatureVector(centroid.map { v in
            GrowthModel.clamp(v + rng.nextDouble(in: -amount..<amount), 0, 1)
        })
    }
}
