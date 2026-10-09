import Foundation

/// One training example: categorical attributes → label (basket id).
public struct Example: Hashable, Sendable, Codable {
    public var attributes: [String: String]
    public var label: String

    public init(attributes: [String: String], label: String) {
        self.attributes = attributes
        self.label = label
    }
}

/// A one-level decision tree: look at one attribute, map each value to a label.
public struct DecisionStump: Hashable, Sendable, Codable {
    public let attribute: String
    public let mapping: [String: String]   // value → label

    public init(attribute: String, mapping: [String: String]) {
        self.attribute = attribute
        self.mapping = mapping
    }

    /// nil when the value was never seen during learning (AI CAT "isn't sure").
    public func predict(_ attributes: [String: String]) -> String? {
        guard let value = attributes[attribute] else { return nil }
        return mapping[value]
    }
}

/// "attribute1 == value1 AND attribute2 == value2 → positive, otherwise negative".
public struct ConjunctionRule: Hashable, Sendable, Codable {
    public let attribute1: String
    public let value1: String
    public let attribute2: String
    public let value2: String
    public let positiveLabel: String
    public let negativeLabel: String

    public init(attribute1: String, value1: String, attribute2: String, value2: String, positiveLabel: String, negativeLabel: String) {
        self.attribute1 = attribute1
        self.value1 = value1
        self.attribute2 = attribute2
        self.value2 = value2
        self.positiveLabel = positiveLabel
        self.negativeLabel = negativeLabel
    }

    public func matches(_ attributes: [String: String]) -> Bool {
        attributes[attribute1] == value1 && attributes[attribute2] == value2
    }

    public func predict(_ attributes: [String: String]) -> String {
        matches(attributes) ? positiveLabel : negativeLabel
    }
}

public enum LearnedRule: Hashable, Sendable, Codable {
    case stump(DecisionStump)
    case conjunction(ConjunctionRule)

    public func predict(_ attributes: [String: String]) -> String? {
        switch self {
        case .stump(let s): return s.predict(attributes)
        case .conjunction(let c): return c.predict(attributes)
        }
    }

    public var attributes: [String] {
        switch self {
        case .stump(let s): return [s.attribute]
        case .conjunction(let c): return [c.attribute1, c.attribute2]
        }
    }
}

/// Honest, tiny inductive learner (ID3-style) used by AI CAT in the Pattern Garden.
/// It only commits to a rule when exactly one hypothesis is consistent with the child's examples
/// (a version-space idea): otherwise it asks for more examples.
public enum RuleLearner {
    public static let minimumExamples = 3

    /// Shannon entropy in bits.
    public static func entropy(_ labels: [String]) -> Double {
        let n = Double(labels.count)
        guard n > 0 else { return 0 }
        var counts: [String: Int] = [:]
        for l in labels { counts[l, default: 0] += 1 }
        var h = 0.0
        for c in counts.values {
            let p = Double(c) / n
            h -= p * log2(p)
        }
        return h
    }

    public static func informationGain(_ examples: [Example], attribute: String) -> Double {
        let total = entropy(examples.map { $0.label })
        var groups: [String: [String]] = [:]
        for e in examples { groups[e.attributes[attribute] ?? "", default: []].append(e.label) }
        let n = Double(examples.count)
        var remainder = 0.0
        for g in groups.values { remainder += Double(g.count) / n * entropy(g) }
        return total - remainder
    }

    /// Every observed value of `attribute` maps to a single label.
    public static func isPure(_ examples: [Example], attribute: String) -> Bool {
        var seen: [String: String] = [:]
        for e in examples {
            guard let v = e.attributes[attribute] else { return false }
            if let l = seen[v], l != e.label { return false }
            seen[v] = e.label
        }
        return true
    }

    /// Pure attributes whose mapping actually separates ≥ 2 labels, as stumps (deterministic order).
    public static func stumpCandidates(_ examples: [Example], attributes: [String]) -> [DecisionStump] {
        let labels = Set(examples.map { $0.label })
        guard labels.count >= 2 else { return [] }
        var result: [DecisionStump] = []
        for attribute in attributes.sorted() where isPure(examples, attribute: attribute) {
            var mapping: [String: String] = [:]
            for e in examples {
                if let v = e.attributes[attribute] { mapping[v] = e.label }
            }
            if Set(mapping.values).count >= 2 {
                result.append(DecisionStump(attribute: attribute, mapping: mapping))
            }
        }
        return result
    }

    public static func learnStump(_ examples: [Example], attributes: [String]) -> DecisionStump? {
        let candidates = stumpCandidates(examples, attributes: attributes)
        return candidates.count == 1 ? candidates[0] : nil
    }

    public static func conjunctionCandidates(_ examples: [Example], attributes: [String],
                                             positiveLabel: String, negativeLabel: String) -> [ConjunctionRule] {
        let labels = Set(examples.map { $0.label })
        guard labels.contains(positiveLabel), labels.contains(negativeLabel) else { return [] }
        let sorted = attributes.sorted()
        var values: [String: [String]] = [:]
        for a in sorted {
            values[a] = Array(Set(examples.compactMap { $0.attributes[a] })).sorted()
        }
        var result: [ConjunctionRule] = []
        for i in 0..<sorted.count {
            for j in (i + 1)..<sorted.count {
                let a1 = sorted[i], a2 = sorted[j]
                for v1 in values[a1] ?? [] {
                    for v2 in values[a2] ?? [] {
                        let rule = ConjunctionRule(attribute1: a1, value1: v1, attribute2: a2, value2: v2,
                                                   positiveLabel: positiveLabel, negativeLabel: negativeLabel)
                        if examples.allSatisfy({ rule.predict($0.attributes) == $0.label }) {
                            result.append(rule)
                        }
                    }
                }
            }
        }
        return result
    }

    public static func learnConjunction(_ examples: [Example], attributes: [String],
                                        positiveLabel: String, negativeLabel: String) -> ConjunctionRule? {
        let candidates = conjunctionCandidates(examples, attributes: attributes, positiveLabel: positiveLabel, negativeLabel: negativeLabel)
        return candidates.count == 1 ? candidates[0] : nil
    }

    /// Learn within the hypothesis space of the current challenge.
    /// - When `conjunctionLabels` is nil only single-attribute rules are considered.
    /// - Otherwise a conjunction is accepted only once every single-attribute hypothesis is refuted.
    public static func learn(_ examples: [Example], attributes: [String],
                             conjunctionLabels: (positive: String, negative: String)?) -> LearnedRule? {
        guard examples.count >= minimumExamples else { return nil }
        let stumps = stumpCandidates(examples, attributes: attributes)
        if let labels = conjunctionLabels {
            guard stumps.isEmpty else { return nil }
            if let c = learnConjunction(examples, attributes: attributes, positiveLabel: labels.positive, negativeLabel: labels.negative) {
                return .conjunction(c)
            }
            return nil
        }
        return stumps.count == 1 ? .stump(stumps[0]) : nil
    }
}
