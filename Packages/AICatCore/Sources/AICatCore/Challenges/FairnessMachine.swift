import Foundation

// MARK: - Shared

public enum CatCoat: String, CaseIterable, Codable, Sendable, Identifiable {
    case black, orange, white, striped

    public var id: String { rawValue }
    public var nameKey: String { "fair.coat.\(rawValue)" }
}

public struct FairCard: Hashable, Sendable, Identifiable {
    public let id: String
    public let coat: CatCoat

    public init(id: String, coat: CatCoat) {
        self.id = id
        self.coat = coat
    }
}

// MARK: - Level 1: find the missing group

public struct RecognitionResult: Hashable, Sendable, Identifiable {
    public let id: String
    public let coat: CatCoat
    public let recognized: Bool
}

/// The data set is shown with counts per coat next to the kitten's guesses on new cats.
/// The child points at the coat that is missing from the examples.
public struct BiasHuntChallenge: Sendable {
    public let spec: ChallengeSpec
    public let dataset: [FairCard]
    public let testResults: [RecognitionResult]
    public let missingCoat: CatCoat
    public private(set) var picks: [CatCoat] = []

    public init(spec: ChallengeSpec, dataset: [FairCard], testResults: [RecognitionResult], missingCoat: CatCoat) {
        self.spec = spec
        self.dataset = dataset
        self.testResults = testResults
        self.missingCoat = missingCoat
    }

    public func count(_ coat: CatCoat) -> Int { dataset.filter { $0.coat == coat }.count }
    public var isSolved: Bool { picks.contains(missingCoat) }

    /// Returns whether the pick was right. Nothing changes once solved.
    @discardableResult
    public mutating func pick(_ coat: CatCoat) -> Bool {
        guard !isSolved, !picks.contains(coat) else { return coat == missingCoat }
        picks.append(coat)
        return coat == missingCoat
    }

    /// Right first time = 1; each wrong pick costs 0.25, never below 0.5.
    public var scoreAccuracy: Double {
        guard isSolved else { return 0 }
        return max(0.5, 1 - 0.25 * Double(picks.count - 1))
    }
}

// MARK: - Level 2: balance the scale

/// The child moves cards from the pool into the data set until every coat has at least `target` examples.
/// Recognition per coat grows with its examples (up to the target): the fairness gap is what the scale shows.
public struct BalanceChallenge: Sendable {
    public let spec: ChallengeSpec
    public let target: Int
    public private(set) var dataset: [FairCard]
    public private(set) var pool: [FairCard]
    public private(set) var adds = 0
    public let neededAdds: Int
    private let originalIDs: Set<String>

    public init(spec: ChallengeSpec, target: Int, dataset: [FairCard], pool: [FairCard]) {
        self.spec = spec
        self.target = target
        self.dataset = dataset
        self.pool = pool
        originalIDs = Set(dataset.map(\.id))
        neededAdds = CatCoat.allCases.reduce(0) { partial, coat in
            partial + max(0, target - dataset.filter { $0.coat == coat }.count)
        }
    }

    public func count(_ coat: CatCoat) -> Int { dataset.filter { $0.coat == coat }.count }
    public func recognition(for coat: CatCoat) -> Double { min(1, Double(count(coat)) / Double(max(target, 1))) }
    public var fairnessGap: Double {
        let values = CatCoat.allCases.map(recognition(for:))
        return (values.max() ?? 0) - (values.min() ?? 0)
    }
    public var coatsAtTarget: Int { CatCoat.allCases.filter { count($0) >= target }.count }
    public var isSolved: Bool { coatsAtTarget == CatCoat.allCases.count }
    public func isFromPool(_ cardID: String) -> Bool { !originalIDs.contains(cardID) }

    @discardableResult
    public mutating func add(_ cardID: String) -> Bool {
        guard !isSolved, let index = pool.firstIndex(where: { $0.id == cardID }) else { return false }
        dataset.append(pool.remove(at: index))
        adds += 1
        return true
    }

    @discardableResult
    public mutating func remove(_ cardID: String) -> Bool {
        guard !isSolved, isFromPool(cardID), let index = dataset.firstIndex(where: { $0.id == cardID }) else { return false }
        pool.append(dataset.remove(at: index))
        return true
    }

    /// Pool cards sitting in the data set right now (cards put back do not count).
    public var addedCards: Int { dataset.filter { isFromPool($0.id) }.count }

    /// Solved = 1 minus 0.05 per card kept beyond what was needed (never below 0.7); unsolved = half the coats at target.
    public var scoreAccuracy: Double {
        guard isSolved else { return 0.5 * Double(coatsAtTarget) / Double(CatCoat.allCases.count) }
        return max(0.7, 1 - 0.05 * Double(max(0, addedCards - neededAdds)))
    }
}

// MARK: - Level 3: keep it private

public struct PrivacyItem: Hashable, Sendable, Identifiable {
    public let id: String
    public let isSensitive: Bool
    public let isNeeded: Bool

    public init(id: String, isSensitive: Bool, isNeeded: Bool) {
        self.id = id
        self.isSensitive = isSensitive
        self.isNeeded = isNeeded
    }

    public var key: String { "fair.privacy.\(id)" }
    /// Keep only what the game needs and is not private (data minimisation).
    public var shouldKeep: Bool { isNeeded && !isSensitive }
}

public struct PrivacyChallenge: Sendable {
    public let spec: ChallengeSpec
    public let items: [PrivacyItem]
    public private(set) var decisions: [String: Bool] = [:]

    public init(spec: ChallengeSpec, items: [PrivacyItem]) {
        self.spec = spec
        self.items = items
    }

    public mutating func decide(_ itemID: String, keep: Bool) {
        guard items.contains(where: { $0.id == itemID }) else { return }
        decisions[itemID] = keep
    }

    public func decision(for itemID: String) -> Bool? { decisions[itemID] }
    public func isCorrect(_ item: PrivacyItem) -> Bool? { decisions[item.id].map { $0 == item.shouldKeep } }
    public var isComplete: Bool { items.allSatisfy { decisions[$0.id] != nil } }
    public var correctCount: Int { items.filter { isCorrect($0) == true }.count }
    public var isSolved: Bool { isComplete }
    public var scoreAccuracy: Double { isComplete ? Double(correctCount) / Double(max(items.count, 1)) : 0 }
}

// MARK: - Level 4: master judge

public enum FairCause: String, CaseIterable, Codable, Sendable {
    case missingExamples, unbalancedData, privateData, noHumanCheck
    public var key: String { "fair.cause.\(rawValue)" }
}

public enum FairFix: String, CaseIterable, Codable, Sendable {
    case addExamples, balanceGroups, deleteData, askAPerson
    public var key: String { "fair.fix.\(rawValue)" }
}

public struct JudgeCase: Hashable, Sendable, Identifiable {
    public let id: String
    public let cause: FairCause
    public let fix: FairFix

    public init(id: String, cause: FairCause, fix: FairFix) {
        self.id = id
        self.cause = cause
        self.fix = fix
    }

    public var key: String { "fair.case.\(id)" }
}

public struct JudgeChallenge: Sendable {
    public let spec: ChallengeSpec
    public let cases: [JudgeCase]
    public private(set) var causeAnswers: [String: FairCause] = [:]
    public private(set) var fixAnswers: [String: FairFix] = [:]

    public init(spec: ChallengeSpec, cases: [JudgeCase]) {
        self.spec = spec
        self.cases = cases
    }

    public mutating func answerCause(_ caseID: String, _ cause: FairCause) {
        guard causeAnswers[caseID] == nil, cases.contains(where: { $0.id == caseID }) else { return }
        causeAnswers[caseID] = cause
    }

    public mutating func answerFix(_ caseID: String, _ fix: FairFix) {
        guard fixAnswers[caseID] == nil, cases.contains(where: { $0.id == caseID }) else { return }
        fixAnswers[caseID] = fix
    }

    public var isComplete: Bool { cases.allSatisfy { causeAnswers[$0.id] != nil && fixAnswers[$0.id] != nil } }
    public var correctCount: Int {
        cases.reduce(0) { $0 + (causeAnswers[$1.id] == $1.cause ? 1 : 0) + (fixAnswers[$1.id] == $1.fix ? 1 : 0) }
    }
    public var isSolved: Bool { isComplete }
    public var scoreAccuracy: Double { isComplete ? Double(correctCount) / Double(max(cases.count * 2, 1)) : 0 }
}

// MARK: - Content

public enum FairnessContent {
    public static let privacyBank: [PrivacyItem] = [
        PrivacyItem(id: "name", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "address", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "face_photo", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "voice", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "school", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "friends_phones", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "birthday", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "location", isSensitive: true, isNeeded: false),
        PrivacyItem(id: "level", isSensitive: false, isNeeded: true),
        PrivacyItem(id: "cat_name", isSensitive: false, isNeeded: true),
        PrivacyItem(id: "language", isSensitive: false, isNeeded: true),
        PrivacyItem(id: "stars", isSensitive: false, isNeeded: true),
        PrivacyItem(id: "drawings", isSensitive: false, isNeeded: true),
        PrivacyItem(id: "favorite_colour", isSensitive: false, isNeeded: false),
        PrivacyItem(id: "shoe_size", isSensitive: false, isNeeded: false),
    ]

    public static let caseBank: [JudgeCase] = [
        JudgeCase(id: "orange_dog", cause: .missingExamples, fix: .addExamples),
        JudgeCase(id: "toys_by_gender", cause: .unbalancedData, fix: .balanceGroups),
        JudgeCase(id: "avatar_faces", cause: .privateData, fix: .deleteData),
        JudgeCase(id: "grandma_unlock", cause: .missingExamples, fix: .addExamples),
        JudgeCase(id: "homework_grade", cause: .noHumanCheck, fix: .askAPerson),
        JudgeCase(id: "music_one_style", cause: .unbalancedData, fix: .balanceGroups),
        JudgeCase(id: "quiz_location", cause: .privateData, fix: .deleteData),
        JudgeCase(id: "team_picker", cause: .noHumanCheck, fix: .askAPerson),
    ]

    static func sampled<T>(_ bank: [T], count: Int, rng: inout SeededGenerator) -> [T] {
        var pool = bank
        pool.shuffle(using: &rng)
        return Array(pool.prefix(max(0, min(count, pool.count))))
    }

    /// Level 1: `items` cards, one coat absent, a second one scarce; two test cats per coat.
    public static func makeBiasHunt(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> BiasHuntChallenge {
        var rng = SeededGenerator(seed: seed)
        let coats = CatCoat.allCases
        let missing = coats[Int(rng.next() % UInt64(coats.count))]
        let others = coats.filter { $0 != missing }
        let scarce = others[Int(rng.next() % UInt64(others.count))]
        let total = max(difficulty.itemCount(in: spec.itemRange), 5)
        var dataset: [FairCard] = [FairCard(id: "d_scarce", coat: scarce)]
        var index = 0
        let plentiful = others.filter { $0 != scarce }
        while dataset.count < total {
            dataset.append(FairCard(id: "d\(index)", coat: plentiful[index % plentiful.count]))
            index += 1
        }
        dataset.shuffle(using: &rng)
        var results: [RecognitionResult] = []
        for coat in coats {
            let count = dataset.filter { $0.coat == coat }.count
            for k in 0..<2 {
                let recognized = count >= 2 || (count == 1 && k == 0)
                results.append(RecognitionResult(id: "t_\(coat.rawValue)_\(k)", coat: coat, recognized: recognized))
            }
        }
        return BiasHuntChallenge(spec: spec, dataset: dataset, testResults: results, missingCoat: missing)
    }

    /// Level 2: an unbalanced data set and a pool with enough cards of every coat (plus some that do not help).
    public static func makeBalance(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> BalanceChallenge {
        var rng = SeededGenerator(seed: seed)
        let target = difficulty.tier >= 3 ? 3 : 2
        var coats = CatCoat.allCases
        coats.shuffle(using: &rng)
        let plentiful = coats[0]
        var dataset: [FairCard] = []
        for i in 0..<(target + 2) { dataset.append(FairCard(id: "d_\(plentiful.rawValue)_\(i)", coat: plentiful)) }
        dataset.append(FairCard(id: "d_\(coats[1].rawValue)_0", coat: coats[1]))
        if target >= 3 { dataset.append(FairCard(id: "d_\(coats[2].rawValue)_0", coat: coats[2])) }
        var pool: [FairCard] = []
        for coat in CatCoat.allCases {
            let present = dataset.filter { $0.coat == coat }.count
            let needed = max(0, target - present)
            for i in 0..<(needed + 1) { pool.append(FairCard(id: "p_\(coat.rawValue)_\(i)", coat: coat)) }
        }
        let extra = max(0, difficulty.itemCount(in: spec.itemRange) - pool.count)
        for i in 0..<extra { pool.append(FairCard(id: "p_\(plentiful.rawValue)_x\(i)", coat: plentiful)) }
        pool.shuffle(using: &rng)
        dataset.shuffle(using: &rng)
        return BalanceChallenge(spec: spec, target: target, dataset: dataset, pool: pool)
    }

    /// Level 3: a seeded sample of the privacy bank with both kinds of answer.
    public static func makePrivacy(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> PrivacyChallenge {
        var rng = SeededGenerator(seed: seed)
        let count = max(4, min(difficulty.itemCount(in: spec.itemRange), privacyBank.count))
        var items = sampled(privacyBank, count: count, rng: &rng)
        if !items.contains(where: { $0.shouldKeep }), let keep = privacyBank.first(where: { $0.shouldKeep }) { items[0] = keep }
        if !items.contains(where: { !$0.shouldKeep }), let drop = privacyBank.first(where: { !$0.shouldKeep }) { items[items.count - 1] = drop }
        return PrivacyChallenge(spec: spec, items: items)
    }

    /// Level 4: two to four cases covering different causes.
    public static func makeJudge(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> JudgeChallenge {
        var rng = SeededGenerator(seed: seed)
        let count = max(2, min(4, difficulty.itemCount(in: spec.itemRange) / 4 + 1))
        var chosen: [JudgeCase] = []
        var pool = caseBank
        pool.shuffle(using: &rng)
        for candidate in pool where !chosen.contains(where: { $0.cause == candidate.cause }) {
            chosen.append(candidate)
            if chosen.count == count { break }
        }
        if chosen.count < count {
            for candidate in pool where !chosen.contains(candidate) {
                chosen.append(candidate)
                if chosen.count == count { break }
            }
        }
        return JudgeChallenge(spec: spec, cases: chosen)
    }
}
