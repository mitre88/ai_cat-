import Foundation

// MARK: - Words and stories

public enum StorySlot: String, CaseIterable, Codable, Sendable {
    case character, place, object
}

public struct StoryWord: Hashable, Sendable, Identifiable, Codable {
    public let id: String
    public let slot: StorySlot

    public init(id: String, slot: StorySlot) {
        self.id = id
        self.slot = slot
    }

    public var key: String { "story.word.\(id)" }
}

public enum StoryBank {
    public static let characters = ["kitten", "robot", "dragon", "fairy", "turtle"].map { StoryWord(id: $0, slot: .character) }
    public static let places = ["moon", "castle", "sea", "forest", "school"].map { StoryWord(id: $0, slot: .place) }
    public static let objects = ["kite", "key", "balloon", "box", "song"].map { StoryWord(id: $0, slot: .object) }
    public static let sentenceCount = 3
    public static let variantCount = 3
    public static let titleCount = 3

    public static func words(for slot: StorySlot) -> [StoryWord] {
        switch slot {
        case .character: return characters
        case .place: return places
        case .object: return objects
        }
    }

    /// Localised template with %1$@ character, %2$@ place, %3$@ object.
    public static func templateKey(sentence: Int, variant: Int) -> String { "story.s\(sentence).v\(variant)" }
    public static func titleKey(_ index: Int) -> String { "story.title.\(index)" }
}

public struct StorySeeds: Hashable, Sendable, Codable {
    public let character: StoryWord
    public let place: StoryWord
    public let object: StoryWord

    public init(character: StoryWord, place: StoryWord, object: StoryWord) {
        self.character = character
        self.place = place
        self.object = object
    }

    public var words: [StoryWord] { [character, place, object] }
}

public enum StorySource: String, Codable, Sendable {
    /// AI CAT's pattern book: a seeded grammar, always available.
    case patterns
    /// Written by the on-device language model (creative mode, parent opt-in).
    case model
}

public struct GeneratedStory: Hashable, Sendable, Codable {
    public let seeds: StorySeeds
    public var variants: [Int]
    public var source: StorySource
    /// Sentences written by the model; nil when the story comes from the pattern book.
    public var modelSentences: [String]?

    public init(seeds: StorySeeds, variants: [Int], source: StorySource = .patterns, modelSentences: [String]? = nil) {
        self.seeds = seeds
        self.variants = variants
        self.source = source
        self.modelSentences = modelSentences
    }

    public var templateKeys: [String] {
        variants.enumerated().map { StoryBank.templateKey(sentence: $0.offset, variant: $0.element) }
    }
}

/// A tiny generative model: a grammar of three sentence slots with three variants each, sampled with a seed.
/// Same seeds + same seed → same story; change a word → the story changes.
public enum StoryGenerator {
    public static func generate(seeds: StorySeeds, seed: UInt64) -> GeneratedStory {
        var rng = SeededGenerator(seed: seed)
        let variants = (0..<StoryBank.sentenceCount).map { _ in Int(rng.next() % UInt64(StoryBank.variantCount)) }
        return GeneratedStory(seeds: seeds, variants: variants)
    }
}

// MARK: - Level 1: story seeds

public struct StorySeedChallenge: Sendable {
    public let spec: ChallengeSpec
    /// Distinct seed sets the child must try (change a word, change the story).
    public let required: Int
    public private(set) var selection: [StorySlot: StoryWord] = [:]
    public private(set) var stories: [GeneratedStory] = []
    public private(set) var generations = 0

    public init(spec: ChallengeSpec, required: Int) {
        self.spec = spec
        self.required = max(1, required)
    }

    public var seeds: StorySeeds? {
        guard let character = selection[.character], let place = selection[.place], let object = selection[.object] else { return nil }
        return StorySeeds(character: character, place: place, object: object)
    }

    public var distinctSeedSets: Int { Set(stories.map(\.seeds)).count }
    public var isSolved: Bool { distinctSeedSets >= required }
    public var latest: GeneratedStory? { stories.last }

    public mutating func select(_ word: StoryWord) {
        selection[word.slot] = word
    }

    /// Grows a story from the current seeds; nil until all three words are chosen.
    @discardableResult
    public mutating func generate(seed: UInt64) -> GeneratedStory? {
        guard let seeds else { return nil }
        generations += 1
        let story = StoryGenerator.generate(seeds: seeds, seed: seed &+ UInt64(generations) &* 977)
        stories.append(story)
        return story
    }

    /// Replaces the latest story's sentences with the model's (creative mode); the seeds stay the same.
    public mutating func attachModelSentences(_ sentences: [String]) {
        guard var story = stories.popLast() else { return }
        story.source = .model
        story.modelSentences = sentences
        stories.append(story)
    }

    public var scoreAccuracy: Double { isSolved ? 1 : 0.5 * Double(distinctSeedSets) / Double(required) }
}

// MARK: - Level 2: remix

public struct RemixChallenge: Sendable {
    public let spec: ChallengeSpec
    public let original: GeneratedStory
    public let requiredChanges: Int
    public private(set) var variants: [Int]
    public private(set) var titleIndex: Int?
    public private(set) var edits = 0

    public init(spec: ChallengeSpec, original: GeneratedStory, requiredChanges: Int) {
        self.spec = spec
        self.original = original
        self.requiredChanges = max(1, min(requiredChanges, StoryBank.sentenceCount))
        variants = original.variants
    }

    public var current: GeneratedStory { GeneratedStory(seeds: original.seeds, variants: variants) }
    public var changedSentences: Int { zip(variants, original.variants).filter { $0 != $1 }.count }
    public var isSolved: Bool { changedSentences >= requiredChanges && titleIndex != nil }

    /// Tapping a sentence cycles through its variants.
    public mutating func cycle(sentence index: Int) {
        guard variants.indices.contains(index) else { return }
        variants[index] = (variants[index] + 1) % StoryBank.variantCount
        edits += 1
    }

    public mutating func chooseTitle(_ index: Int) {
        guard (0..<StoryBank.titleCount).contains(index) else { return }
        titleIndex = index
    }

    public var scoreAccuracy: Double {
        guard isSolved else { return 0.5 * Double(changedSentences) / Double(requiredChanges) }
        return 1
    }
}

// MARK: - Level 3: design a helper

public enum HelperGoal: String, CaseIterable, Codable, Sendable {
    case lostToys, bookTips, plantCare, birdSongs
    public var key: String { "helper.goal.\(rawValue)" }
}

public enum HelperData: String, CaseIterable, Codable, Sendable {
    case toyPhotos, roomMap, booksRead, favoriteTopics, plantTypes, wateringDays, birdRecordings, parkVisits
    case friendsFaces, homeAddress, schoolGrades, everythingOnPhone

    public var key: String { "helper.data.\(rawValue)" }

    public var isPrivate: Bool {
        switch self {
        case .friendsFaces, .homeAddress, .schoolGrades, .everythingOnPhone: return true
        default: return false
        }
    }

    public var relevantGoals: [HelperGoal] {
        switch self {
        case .toyPhotos, .roomMap: return [.lostToys]
        case .booksRead, .favoriteTopics: return [.bookTips]
        case .plantTypes, .wateringDays: return [.plantCare]
        case .birdRecordings, .parkVisits: return [.birdSongs]
        default: return []
        }
    }
}

public enum HelperRule: String, CaseIterable, Codable, Sendable {
    case askBeforeCamera, neverKeepPrivate, personChecks, worksOffline, collectEverything, decidesAlone

    public var key: String { "helper.rule.\(rawValue)" }
    public var isGood: Bool { self != .collectEverything && self != .decidesAlone }
}

public enum HelperCheck: String, CaseIterable, Codable, Sendable {
    case goalChosen, dataHelpsGoal, noPrivateData, privacyRule, humanRule, noBadRules
    public var key: String { "helper.check.\(rawValue)" }
}

public struct HelperDesignChallenge: Sendable {
    public let spec: ChallengeSpec
    public private(set) var goal: HelperGoal?
    public private(set) var data: Set<HelperData> = []
    public private(set) var rules: Set<HelperRule> = []

    public init(spec: ChallengeSpec) {
        self.spec = spec
    }

    public mutating func choose(_ goal: HelperGoal) { self.goal = goal }
    public mutating func toggle(_ item: HelperData) { if data.contains(item) { data.remove(item) } else { data.insert(item) } }
    public mutating func toggle(_ rule: HelperRule) { if rules.contains(rule) { rules.remove(rule) } else { rules.insert(rule) } }

    public func passes(_ check: HelperCheck) -> Bool {
        switch check {
        case .goalChosen: return goal != nil
        case .dataHelpsGoal:
            guard let goal else { return false }
            let useful = data.filter { $0.relevantGoals.contains(goal) }
            return !useful.isEmpty && data.allSatisfy { $0.isPrivate || $0.relevantGoals.contains(goal) }
        case .noPrivateData: return !data.contains { $0.isPrivate }
        case .privacyRule: return rules.contains(.neverKeepPrivate)
        case .humanRule: return rules.contains(.personChecks)
        case .noBadRules: return !rules.contains { !$0.isGood }
        }
    }

    public var passedCount: Int { HelperCheck.allCases.filter(passes).count }
    public var isSolved: Bool { passedCount == HelperCheck.allCases.count }
    public var scoreAccuracy: Double { Double(passedCount) / Double(HelperCheck.allCases.count) }
}

// MARK: - Level 4: graduation quiz

public struct QuizQuestion: Hashable, Sendable, Identifiable {
    public let id: String
    public let answer: Int
    public static let optionCount = 3

    public init(id: String, answer: Int) {
        self.id = id
        self.answer = answer
    }

    public var key: String { "quiz.\(id).q" }
    public func optionKey(_ index: Int) -> String { "quiz.\(id).o\(index)" }
}

public struct GraduationQuiz: Sendable {
    public let spec: ChallengeSpec
    public let questions: [QuizQuestion]
    public private(set) var answers: [String: Int] = [:]

    public init(spec: ChallengeSpec, questions: [QuizQuestion]) {
        self.spec = spec
        self.questions = questions
    }

    public mutating func answer(_ questionID: String, option: Int) {
        guard answers[questionID] == nil, questions.contains(where: { $0.id == questionID }), (0..<QuizQuestion.optionCount).contains(option) else { return }
        answers[questionID] = option
    }

    public func isCorrect(_ question: QuizQuestion) -> Bool? { answers[question.id].map { $0 == question.answer } }
    public var isComplete: Bool { questions.allSatisfy { answers[$0.id] != nil } }
    public var correctCount: Int { questions.filter { isCorrect($0) == true }.count }
    public var isSolved: Bool { isComplete }
    public var scoreAccuracy: Double { isComplete ? Double(correctCount) / Double(max(questions.count, 1)) : 0 }
}

// MARK: - Content

public enum CreativeContent {
    public static let quizBank: [QuizQuestion] = [
        QuizQuestion(id: "rule_from_examples", answer: 0),
        QuizQuestion(id: "wrong_label", answer: 1),
        QuizQuestion(id: "boundary", answer: 2),
        QuizQuestion(id: "endless_loop", answer: 0),
        QuizQuestion(id: "warm_tiles", answer: 1),
        QuizQuestion(id: "weights", answer: 2),
        QuizQuestion(id: "only_black_cats", answer: 0),
        QuizQuestion(id: "who_checks", answer: 1),
    ]

    public static func makeStorySeeds(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> StorySeedChallenge {
        StorySeedChallenge(spec: spec, required: difficulty.tier >= 2 ? 3 : 2)
    }

    public static func makeRemix(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> RemixChallenge {
        var rng = SeededGenerator(seed: seed)
        let seeds = StorySeeds(character: StoryBank.characters[Int(rng.next() % 5)],
                               place: StoryBank.places[Int(rng.next() % 5)],
                               object: StoryBank.objects[Int(rng.next() % 5)])
        let original = StoryGenerator.generate(seeds: seeds, seed: seed)
        return RemixChallenge(spec: spec, original: original, requiredChanges: difficulty.tier >= 3 ? 3 : 2)
    }

    public static func makeHelperDesign(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> HelperDesignChallenge {
        HelperDesignChallenge(spec: spec)
    }

    public static func makeGraduation(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> GraduationQuiz {
        var rng = SeededGenerator(seed: seed)
        var pool = quizBank
        pool.shuffle(using: &rng)
        let count = max(3, min(difficulty.itemCount(in: spec.itemRange) / 2 + 2, pool.count))
        return GraduationQuiz(spec: spec, questions: Array(pool.prefix(count)))
    }
}
