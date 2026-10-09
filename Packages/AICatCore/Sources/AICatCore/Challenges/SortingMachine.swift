import Foundation

// MARK: - Fruits

public enum FruitAttribute: String, CaseIterable, Codable, Sendable {
    case color, shape, size

    public var nameKey: TextKey {
        switch self {
        case .color: return TextKey("fruit.attribute.color")
        case .shape: return TextKey("fruit.attribute.shape")
        case .size: return TextKey("fruit.attribute.size")
        }
    }
}

public enum FruitColor: String, CaseIterable, Codable, Sendable {
    case red, yellow, green, purple

    public var nameKey: TextKey {
        switch self {
        case .red: return TextKey("fruit.color.red")
        case .yellow: return TextKey("fruit.color.yellow")
        case .green: return TextKey("fruit.color.green")
        case .purple: return TextKey("fruit.color.purple")
        }
    }
}

public enum FruitShape: String, CaseIterable, Codable, Sendable {
    case round, long

    public var nameKey: TextKey {
        switch self {
        case .round: return TextKey("fruit.shape.round")
        case .long: return TextKey("fruit.shape.long")
        }
    }
}

public enum FruitSize: String, CaseIterable, Codable, Sendable {
    case small, big

    public var nameKey: TextKey {
        switch self {
        case .small: return TextKey("fruit.size.small")
        case .big: return TextKey("fruit.size.big")
        }
    }
}

/// Localization key of an attribute value ("red", "round", …).
public func fruitValueKey(attribute: FruitAttribute, value: String) -> TextKey {
    switch attribute {
    case .color: return (FruitColor(rawValue: value) ?? .red).nameKey
    case .shape: return (FruitShape(rawValue: value) ?? .round).nameKey
    case .size: return (FruitSize(rawValue: value) ?? .big).nameKey
    }
}

public struct Fruit: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let color: FruitColor
    public let shape: FruitShape
    public let size: FruitSize

    public init(id: String, color: FruitColor, shape: FruitShape, size: FruitSize) {
        self.id = id
        self.color = color
        self.shape = shape
        self.size = size
    }

    public var attributes: [String: String] {
        [FruitAttribute.color.rawValue: color.rawValue,
         FruitAttribute.shape.rawValue: shape.rawValue,
         FruitAttribute.size.rawValue: size.rawValue]
    }

    public func value(of attribute: FruitAttribute) -> String {
        switch attribute {
        case .color: return color.rawValue
        case .shape: return shape.rawValue
        case .size: return size.rawValue
        }
    }
}

public struct Basket: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let index: Int   // 1-based, for display

    public init(id: String, index: Int) {
        self.id = id
        self.index = index
    }

    public var nameKey: TextKey {
        switch index {
        case 1: return TextKey("basket.1")
        case 2: return TextKey("basket.2")
        default: return TextKey("basket.3")
        }
    }
}

// MARK: - Rules

public enum SortingRule: Hashable, Codable, Sendable {
    /// value of `attribute` → basket id
    case byAttribute(attribute: FruitAttribute, mapping: [String: String])
    /// first == firstValue AND second == secondValue → yesBasket, otherwise noBasket
    case conjunction(first: FruitAttribute, firstValue: String, second: FruitAttribute, secondValue: String, yesBasket: String, noBasket: String)

    public func basket(for fruit: Fruit) -> String {
        switch self {
        case .byAttribute(let attribute, let mapping):
            return mapping[fruit.value(of: attribute)] ?? ""
        case .conjunction(let first, let v1, let second, let v2, let yes, let no):
            return (fruit.value(of: first) == v1 && fruit.value(of: second) == v2) ? yes : no
        }
    }

    public var attributes: [FruitAttribute] {
        switch self {
        case .byAttribute(let a, _): return [a]
        case .conjunction(let a, _, let b, _, _, _): return [a, b]
        }
    }

    public var isConjunction: Bool {
        if case .conjunction = self { return true }
        return false
    }

    /// Labels for the learner when the rule is a conjunction.
    public var conjunctionLabels: (positive: String, negative: String)? {
        if case .conjunction(_, _, _, _, let yes, let no) = self { return (yes, no) }
        return nil
    }

    /// Human-explainable statements (the app turns them into sentences with format keys).
    public enum Statement: Hashable, Sendable {
        case valueToBasket(valueKey: TextKey, basketID: String)
        case conjunction(firstKey: TextKey, secondKey: TextKey, yesBasketID: String, noBasketID: String)
    }

    public var statements: [Statement] {
        switch self {
        case .byAttribute(let attribute, let mapping):
            return mapping.keys.sorted().map { .valueToBasket(valueKey: fruitValueKey(attribute: attribute, value: $0), basketID: mapping[$0] ?? "") }
        case .conjunction(let first, let v1, let second, let v2, let yes, let no):
            return [.conjunction(firstKey: fruitValueKey(attribute: first, value: v1), secondKey: fruitValueKey(attribute: second, value: v2), yesBasketID: yes, noBasketID: no)]
        }
    }
}

public enum PlacementOutcome: Equatable, Sendable {
    case correct
    case wrong(expected: String)
    case ignored
}

public struct AIMove: Equatable, Sendable {
    public let fruit: Fruit
    public let basketID: String
}

// MARK: - Challenge state machine

/// Pure state of one Pattern Garden challenge. The app owns rendering; this owns the truth.
public struct SortingChallenge: Codable, Sendable {
    public let spec: ChallengeSpec
    public let rule: SortingRule
    public let ruleIsStated: Bool
    public let activeAttributes: [FruitAttribute]
    public let fruits: [Fruit]
    public let baskets: [Basket]
    public let minExamplesToLearn: Int

    public private(set) var placements: [String: String] = [:]   // fruit id → basket id
    public private(set) var childSortedIDs: Set<String> = []
    public private(set) var aiSortedIDs: Set<String> = []
    public private(set) var attempts = 0
    public private(set) var mistakes = 0
    public private(set) var hintsUsed = 0
    public private(set) var aiRule: LearnedRule?

    public init(spec: ChallengeSpec, rule: SortingRule, ruleIsStated: Bool, activeAttributes: [FruitAttribute],
                fruits: [Fruit], baskets: [Basket], minExamplesToLearn: Int) {
        self.spec = spec
        self.rule = rule
        self.ruleIsStated = ruleIsStated
        self.activeAttributes = activeAttributes
        self.fruits = fruits
        self.baskets = baskets
        self.minExamplesToLearn = minExamplesToLearn
    }

    public var remaining: [Fruit] { fruits.filter { placements[$0.id] == nil } }
    public var isComplete: Bool { remaining.isEmpty }
    public var aiHasLearned: Bool { aiRule != nil }

    /// Correct first-time placements over all attempts (1 when nothing attempted yet).
    public var accuracy: Double {
        attempts == 0 ? 1 : Double(childSortedIDs.count) / Double(attempts)
    }

    public func fruit(id: String) -> Fruit? { fruits.first { $0.id == id } }
    public func basket(id: String) -> Basket? { baskets.first { $0.id == id } }
    public func expectedBasket(for fruit: Fruit) -> String { rule.basket(for: fruit) }

    public mutating func place(fruitID: String, in basketID: String) -> PlacementOutcome {
        guard let fruit = fruit(id: fruitID), placements[fruitID] == nil, basket(id: basketID) != nil else { return .ignored }
        attempts += 1
        let expected = rule.basket(for: fruit)
        if expected == basketID {
            placements[fruitID] = basketID
            childSortedIDs.insert(fruitID)
            return .correct
        }
        mistakes += 1
        return .wrong(expected: expected)
    }

    public mutating func useHint() -> (fruit: Fruit, basketID: String)? {
        guard let fruit = remaining.first else { return nil }
        hintsUsed += 1
        return (fruit, rule.basket(for: fruit))
    }

    /// The child's correct placements as training data for AI CAT.
    public var examplesForLearning: [Example] {
        fruits.compactMap { fruit in
            guard childSortedIDs.contains(fruit.id), let basket = placements[fruit.id] else { return nil }
            return Example(attributes: fruit.attributes, label: basket)
        }
    }

    /// Let AI CAT try to infer the rule from the child's examples.
    @discardableResult
    public mutating func letAICatLearn() -> LearnedRule? {
        if let known = aiRule { return known }
        let examples = examplesForLearning
        guard examples.count >= minExamplesToLearn else { return nil }
        let learned = RuleLearner.learn(examples, attributes: activeAttributes.map { $0.rawValue },
                                        conjunctionLabels: rule.conjunctionLabels)
        aiRule = learned
        return learned
    }

    /// AI CAT sorts every remaining fruit it is sure about. Returns the moves for animation.
    public mutating func aiCatSortsRemaining() -> [AIMove] {
        guard let learned = aiRule else { return [] }
        var moves: [AIMove] = []
        for fruit in remaining {
            if let basketID = learned.predict(fruit.attributes), basket(id: basketID) != nil {
                placements[fruit.id] = basketID
                aiSortedIDs.insert(fruit.id)
                moves.append(AIMove(fruit: fruit, basketID: basketID))
            }
        }
        return moves
    }
}

// MARK: - Content generation

public enum SortingContent {
    public static let basketA = "basketA"
    public static let basketB = "basketB"

    /// Deterministic challenge content for a spec, difficulty and seed.
    /// params: "attributes" (1…3 active attributes), "rule" (0 stated colour rule, 1 hidden single attribute,
    /// 2 conjunction, 3 random between 1 and 2).
    public static func make(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> SortingChallenge {
        var rng = SeededGenerator(seed: seed)
        let attributeCount = max(1, min(3, spec.param("attributes", default: 1)))
        let active: [FruitAttribute] = Array([FruitAttribute.color, .shape, .size].prefix(attributeCount))
        var kind = spec.param("rule", default: 0)
        if kind == 3 { kind = Int.random(in: 1...2, using: &rng) }
        if kind == 2 && attributeCount < 2 { kind = 1 }

        // Two colours per challenge keep the pattern readable; which two is random.
        let colours = Array(FruitColor.allCases.shuffled(using: &rng).prefix(2))
        let shapes: [FruitShape] = active.contains(.shape) ? FruitShape.allCases : [.round]
        let sizes: [FruitSize] = active.contains(.size) ? FruitSize.allCases : [.big]

        var combos: [(FruitColor, FruitShape, FruitSize)] = []
        for c in colours { for s in shapes { for z in sizes { combos.append((c, s, z)) } } }

        let baskets = [Basket(id: basketA, index: 1), Basket(id: basketB, index: 2)]
        let rule: SortingRule
        switch kind {
        case 2:
            let first = active[0]
            let second = active[1]
            let v1 = first == .color ? colours[0].rawValue : (first == .shape ? FruitShape.round.rawValue : FruitSize.big.rawValue)
            let v2 = second == .shape ? FruitShape.allCases.shuffled(using: &rng)[0].rawValue : FruitSize.allCases.shuffled(using: &rng)[0].rawValue
            rule = .conjunction(first: first, firstValue: v1, second: second, secondValue: v2, yesBasket: basketA, noBasket: basketB)
        case 1:
            let target = active.shuffled(using: &rng)[0]
            rule = .byAttribute(attribute: target, mapping: mapping(for: target, colours: colours))
        default:
            rule = .byAttribute(attribute: .color, mapping: mapping(for: .color, colours: colours))
        }

        let count = max(difficulty.itemCount(in: spec.itemRange), combos.count)
        var fruits: [Fruit] = []
        var index = 0
        while fruits.count < count {
            let combo = combos[index % combos.count]
            fruits.append(Fruit(id: "fruit\(fruits.count + 1)", color: combo.0, shape: combo.1, size: combo.2))
            index += 1
        }
        fruits.shuffle(using: &rng)

        return SortingChallenge(
            spec: spec,
            rule: rule,
            ruleIsStated: kind == 0,
            activeAttributes: active,
            fruits: fruits,
            baskets: baskets,
            minExamplesToLearn: kind == 2 ? 4 : RuleLearner.minimumExamples
        )
    }

    private static func mapping(for attribute: FruitAttribute, colours: [FruitColor]) -> [String: String] {
        switch attribute {
        case .color: return [colours[0].rawValue: basketA, colours[1].rawValue: basketB]
        case .shape: return [FruitShape.round.rawValue: basketA, FruitShape.long.rawValue: basketB]
        case .size: return [FruitSize.big.rawValue: basketA, FruitSize.small.rawValue: basketB]
        }
    }
}
