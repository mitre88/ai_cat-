import Foundation

// MARK: - Tokenizer

/// Greedy longest-match tokenizer over a small vocabulary (a toy WordPiece). Letters the vocabulary
/// does not cover become chunks of up to three characters, so any text can be shown as tokens.
public struct Tokenizer: Hashable, Sendable {
    public let vocabulary: [String]

    public init(vocabulary: [String]) {
        self.vocabulary = vocabulary.map { $0.lowercased() }.sorted { $0.count > $1.count }
    }

    public func tokenize(word: String) -> [String] {
        let characters = Array(word.lowercased())
        var tokens: [String] = []
        var index = 0
        while index < characters.count {
            var matched: String?
            for piece in vocabulary where piece.count <= characters.count - index {
                if Array(piece) == Array(characters[index..<(index + piece.count)]) {
                    matched = piece
                    break
                }
            }
            if let matched {
                tokens.append(matched)
                index += matched.count
            } else {
                var end = min(characters.count, index + 3)
                for probe in (index + 1)..<end where vocabulary.contains(where: { piece in
                    piece.count <= characters.count - probe && Array(piece) == Array(characters[probe..<(probe + piece.count)])
                }) {
                    end = probe
                    break
                }
                tokens.append(String(characters[index..<end]))
                index = end
            }
        }
        return tokens
    }

    /// Splits on whitespace and punctuation, then tokenizes every word.
    public func tokenize(sentence: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return sentence.components(separatedBy: separators).filter { !$0.isEmpty }.flatMap { tokenize(word: $0) }
    }
}

// MARK: - Level 1: tokens

public struct TokenRound: Hashable, Sendable {
    public let word: String
    public let pieces: [String]
    public let chips: [String]

    public init(word: String, pieces: [String], chips: [String]) {
        self.word = word
        self.pieces = pieces
        self.chips = chips
    }
}

/// Rebuild each word from chips in the order AI CAT's tokenizer splits it.
public struct TokenChallenge: Sendable {
    public let spec: ChallengeSpec
    public let rounds: [TokenRound]
    public private(set) var roundIndex = 0
    public private(set) var assembled: [String] = []
    public private(set) var mistakes = 0

    public init(spec: ChallengeSpec, rounds: [TokenRound]) {
        self.spec = spec
        self.rounds = rounds
    }

    public var current: TokenRound? { rounds.indices.contains(roundIndex) ? rounds[roundIndex] : nil }
    public var isComplete: Bool { roundIndex >= rounds.count }
    public var isSolved: Bool { isComplete }
    public var nextPiece: String? {
        guard let current, assembled.count < current.pieces.count else { return nil }
        return current.pieces[assembled.count]
    }

    public enum TapResult: Equatable, Sendable {
        case accepted, wrong, roundComplete, allComplete
    }

    /// A chip is right only when it is the next piece of the split.
    @discardableResult
    public mutating func tap(_ chip: String) -> TapResult? {
        guard let expected = nextPiece else { return nil }
        guard chip == expected else {
            mistakes += 1
            return .wrong
        }
        assembled.append(chip)
        if assembled.count == current?.pieces.count {
            roundIndex += 1
            assembled = []
            return isComplete ? .allComplete : .roundComplete
        }
        return .accepted
    }

    public var scoreAccuracy: Double { isComplete ? max(0.5, 1 - 0.1 * Double(mistakes)) : 0 }
}

// MARK: - Level 2: next word

/// Counts which word follows which: P(next | word) = count(word, next) / count(word, ·).
public struct BigramModel: Hashable, Sendable {
    public private(set) var counts: [String: [String: Int]] = [:]

    public init(sentences: [[String]]) {
        for sentence in sentences {
            for (index, word) in sentence.enumerated() where index + 1 < sentence.count {
                counts[word, default: [:]][sentence[index + 1], default: 0] += 1
            }
        }
    }

    public struct Prediction: Hashable, Sendable {
        public let word: String
        public let count: Int
        public let probability: Double
    }

    /// Continuations sorted by probability (ties alphabetically, so the answer is deterministic).
    public func predictions(after word: String) -> [Prediction] {
        guard let followers = counts[word], !followers.isEmpty else { return [] }
        let total = Double(followers.values.reduce(0, +))
        return followers.map { Prediction(word: $0.key, count: $0.value, probability: Double($0.value) / total) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.word < $1.word }
    }

    public func mostLikely(after word: String) -> String? { predictions(after: word).first?.word }
}

public struct NextWordRound: Hashable, Sendable {
    public let context: String
    public let options: [String]
    public let answer: String

    public init(context: String, options: [String], answer: String) {
        self.context = context
        self.options = options
        self.answer = answer
    }
}

public struct NextWordChallenge: Sendable {
    public let spec: ChallengeSpec
    public let corpus: [[String]]
    public let model: BigramModel
    public let rounds: [NextWordRound]
    public private(set) var answers: [String] = []

    public init(spec: ChallengeSpec, corpus: [[String]], rounds: [NextWordRound]) {
        self.spec = spec
        self.corpus = corpus
        model = BigramModel(sentences: corpus)
        self.rounds = rounds
    }

    public var currentIndex: Int { answers.count }
    public var current: NextWordRound? { rounds.indices.contains(currentIndex) ? rounds[currentIndex] : nil }
    public var isComplete: Bool { answers.count >= rounds.count }
    public var isSolved: Bool { isComplete }
    public var correctCount: Int { zip(answers, rounds).filter { $0 == $1.answer }.count }

    @discardableResult
    public mutating func pick(_ word: String) -> Bool? {
        guard let round = current, round.options.contains(word) else { return nil }
        answers.append(word)
        return word == round.answer
    }

    public var scoreAccuracy: Double { isComplete ? Double(correctCount) / Double(max(rounds.count, 1)) : 0 }
}

// MARK: - Level 3: talk (speech becomes text and tokens)

public struct TalkChallenge: Sendable {
    public let spec: ChallengeSpec
    public let required: Int
    public let tokenizer: Tokenizer
    public private(set) var utterances: [String] = []

    public init(spec: ChallengeSpec, required: Int, tokenizer: Tokenizer) {
        self.spec = spec
        self.required = max(1, required)
        self.tokenizer = tokenizer
    }

    public var isSolved: Bool { utterances.count >= required }

    public mutating func record(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSolved, !trimmed.isEmpty else { return }
        utterances.append(trimmed)
    }

    public func tokens(of text: String) -> [String] { tokenizer.tokenize(sentence: text) }
    public var scoreAccuracy: Double { isSolved ? 1 : 0.5 * Double(utterances.count) / Double(required) }
}

// MARK: - Level 4: conversation with planted mistakes

public struct ChatTurn: Hashable, Sendable, Identifiable {
    public let id: String
    public let isWrong: Bool

    public init(id: String, isWrong: Bool) {
        self.id = id
        self.isWrong = isWrong
    }

    public var questionKey: String { "chat.\(id).q" }
    public var answerKey: String { "chat.\(id).a" }
}

/// AI CAT answers questions; some answers are wrong on purpose and the child has to spot them.
public struct ConversationChallenge: Sendable {
    public let spec: ChallengeSpec
    public let turns: [ChatTurn]
    public private(set) var judgements: [String: Bool] = [:]

    public init(spec: ChallengeSpec, turns: [ChatTurn]) {
        self.spec = spec
        self.turns = turns
    }

    public var revealedCount: Int { judgements.count }
    public var current: ChatTurn? { turns.first { judgements[$0.id] == nil } }
    public var isComplete: Bool { turns.allSatisfy { judgements[$0.id] != nil } }
    public var isSolved: Bool { isComplete }

    public func isCorrect(_ turn: ChatTurn) -> Bool? { judgements[turn.id].map { $0 == !turn.isWrong } }
    public var correctCount: Int { turns.filter { isCorrect($0) == true }.count }

    /// `believes` = the child thinks the answer is right.
    @discardableResult
    public mutating func judge(_ turnID: String, believes: Bool) -> Bool? {
        guard judgements[turnID] == nil, let turn = turns.first(where: { $0.id == turnID }) else { return nil }
        judgements[turnID] = believes
        return believes == !turn.isWrong
    }

    public var scoreAccuracy: Double { isComplete ? Double(correctCount) / Double(max(turns.count, 1)) : 0 }
}

// MARK: - Content

public enum LanguageContent {
    public struct TokenWord: Hashable, Sendable {
        public let word: String
        public let pieces: [String]
        public let distractors: [String]
    }

    public static func tokenWords(language: String) -> [TokenWord] {
        if language.hasPrefix("es") {
            return [
                TokenWord(word: "gatitos", pieces: ["gat", "ito", "s"], distractors: ["perr", "a"]),
                TokenWord(word: "jugando", pieces: ["jug", "ando"], distractors: ["ado", "ar"]),
                TokenWord(word: "infeliz", pieces: ["in", "feliz"], distractors: ["mente", "triste"]),
                TokenWord(word: "robots", pieces: ["robot", "s"], distractors: ["ro", "bot"]),
                TokenWord(word: "girasol", pieces: ["gira", "sol"], distractors: ["luna", "es"]),
                TokenWord(word: "saltaron", pieces: ["salt", "aron"], distractors: ["ando", "s"]),
                TokenWord(word: "arcoíris", pieces: ["arco", "íris"], distractors: ["nube", "s"]),
            ]
        }
        return [
            TokenWord(word: "kittens", pieces: ["kit", "ten", "s"], distractors: ["cat", "ing"]),
            TokenWord(word: "playing", pieces: ["play", "ing"], distractors: ["ed", "er"]),
            TokenWord(word: "unhappy", pieces: ["un", "happy"], distractors: ["ly", "sad"]),
            TokenWord(word: "robots", pieces: ["robot", "s"], distractors: ["ro", "bot"]),
            TokenWord(word: "sunflower", pieces: ["sun", "flower"], distractors: ["moon", "s"]),
            TokenWord(word: "jumped", pieces: ["jump", "ed"], distractors: ["ing", "s"]),
            TokenWord(word: "rainbow", pieces: ["rain", "bow"], distractors: ["snow", "s"]),
        ]
    }

    /// Everything the game's tokenizer knows for a language: all pieces of the token words.
    public static func tokenizer(language: String) -> Tokenizer {
        Tokenizer(vocabulary: Array(Set(tokenWords(language: language).flatMap { $0.pieces + $0.distractors })))
    }

    public static func corpus(language: String) -> [[String]] {
        if language.hasPrefix("es") {
            return [
                ["el", "gato", "come", "pescado"],
                ["el", "gato", "come", "leche"],
                ["el", "perro", "come", "huesos"],
                ["el", "gato", "duerme"],
                ["el", "perro", "corre", "rápido"],
                ["el", "gato", "come", "pescado"],
                ["mi", "gato", "come", "pescado"],
                ["el", "perro", "come", "pescado"],
            ]
        }
        return [
            ["the", "cat", "likes", "fish"],
            ["the", "cat", "likes", "milk"],
            ["the", "dog", "likes", "bones"],
            ["the", "cat", "sleeps"],
            ["the", "dog", "runs", "fast"],
            ["the", "cat", "likes", "fish"],
            ["my", "cat", "likes", "fish"],
            ["the", "dog", "likes", "fish"],
        ]
    }

    static func contexts(language: String) -> [String] {
        language.hasPrefix("es") ? ["el", "gato", "come", "perro"] : ["the", "cat", "likes", "dog"]
    }

    public static let chatBank: [ChatTurn] = [
        ChatTurn(id: "pattern", isWrong: false),
        ChatTurn(id: "learn", isWrong: false),
        ChatTurn(id: "never_wrong", isWrong: true),
        ChatTurn(id: "token", isWrong: false),
        ChatTurn(id: "photos", isWrong: false),
        ChatTurn(id: "spider", isWrong: true),
        ChatTurn(id: "neuron", isWrong: false),
        ChatTurn(id: "moon_cheese", isWrong: true),
    ]

    public static func makeTokens(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64, language: String) -> TokenChallenge {
        var rng = SeededGenerator(seed: seed)
        var words = tokenWords(language: language)
        words.shuffle(using: &rng)
        let count = max(2, min(difficulty.itemCount(in: spec.itemRange), words.count))
        let rounds = words.prefix(count).map { entry -> TokenRound in
            var chips = entry.pieces + entry.distractors
            chips.shuffle(using: &rng)
            return TokenRound(word: entry.word, pieces: entry.pieces, chips: chips)
        }
        return TokenChallenge(spec: spec, rounds: Array(rounds))
    }

    public static func makeNextWord(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64, language: String) -> NextWordChallenge {
        var rng = SeededGenerator(seed: seed)
        let sentences = corpus(language: language)
        let model = BigramModel(sentences: sentences)
        var contexts = self.contexts(language: language)
        contexts.shuffle(using: &rng)
        let count = max(2, min(difficulty.itemCount(in: spec.itemRange) - 1, contexts.count))
        let vocabulary = Array(Set(sentences.flatMap { $0 })).sorted()
        let rounds = contexts.prefix(count).compactMap { context -> NextWordRound? in
            let predictions = model.predictions(after: context)
            guard let answer = predictions.first?.word else { return nil }
            var options = [answer]
            for prediction in predictions.dropFirst() where options.count < 3 {
                options.append(prediction.word)
            }
            var fillers = vocabulary.filter { !options.contains($0) && $0 != context }
            fillers.shuffle(using: &rng)
            for filler in fillers where options.count < 3 {
                options.append(filler)
            }
            options.shuffle(using: &rng)
            return NextWordRound(context: context, options: options, answer: answer)
        }
        return NextWordChallenge(spec: spec, corpus: sentences, rounds: rounds)
    }

    public static func makeTalk(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64, language: String) -> TalkChallenge {
        TalkChallenge(spec: spec, required: max(2, min(4, difficulty.itemCount(in: spec.itemRange) / 2)), tokenizer: tokenizer(language: language))
    }

    public static func makeConversation(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> ConversationChallenge {
        var rng = SeededGenerator(seed: seed)
        var pool = chatBank
        pool.shuffle(using: &rng)
        let count = max(3, min(5, difficulty.itemCount(in: spec.itemRange) / 2))
        var chosen = Array(pool.prefix(count))
        if !chosen.contains(where: { $0.isWrong }), let wrong = pool.first(where: { $0.isWrong }) { chosen[0] = wrong }
        if !chosen.contains(where: { !$0.isWrong }), let right = pool.first(where: { !$0.isWrong }) { chosen[chosen.count - 1] = right }
        return ConversationChallenge(spec: spec, turns: chosen)
    }
}
