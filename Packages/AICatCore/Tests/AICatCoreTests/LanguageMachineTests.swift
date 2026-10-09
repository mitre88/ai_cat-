import XCTest
@testable import AICatCore

final class LanguageMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.catVoice).challenges }
    private let difficulty = AdaptiveDifficulty(value: 0.45)

    func testTokenizerReproducesEveryIntendedSplit() {
        for language in ["en", "es"] {
            for entry in LanguageContent.tokenWords(language: language) {
                let tokenizer = Tokenizer(vocabulary: entry.pieces + entry.distractors)
                XCTAssertEqual(tokenizer.tokenize(word: entry.word), entry.pieces, "\(language): \(entry.word)")
                XCTAssertEqual(entry.pieces.joined(), entry.word)
            }
            let general = LanguageContent.tokenizer(language: language)
            XCTAssertEqual(general.tokenize(word: "robots"), ["robot", "s"])
        }
        let fallback = Tokenizer(vocabulary: ["cat"])
        XCTAssertEqual(fallback.tokenize(word: "xyzcatq"), ["xyz", "cat", "q"], "unknown letters become small chunks")
        XCTAssertEqual(fallback.tokenize(sentence: "Cat, cat!"), ["cat", "cat"])
    }

    func testTokenChallengeFlow() {
        var challenge = LanguageContent.makeTokens(spec: specs[0], difficulty: difficulty, seed: 3, language: "es")
        XCTAssertGreaterThanOrEqual(challenge.rounds.count, 2)
        let first = challenge.current!
        XCTAssertEqual(Set(first.chips).count, first.chips.count)
        XCTAssertTrue(first.pieces.allSatisfy { first.chips.contains($0) })
        let wrongChip = first.chips.first { $0 != first.pieces[0] }!
        XCTAssertEqual(challenge.tap(wrongChip), .wrong)
        XCTAssertEqual(challenge.mistakes, 1)
        var result: TokenChallenge.TapResult?
        while !challenge.isComplete {
            result = challenge.tap(challenge.nextPiece!)
        }
        XCTAssertEqual(result, .allComplete)
        XCTAssertNil(challenge.tap("x"))
        XCTAssertEqual(challenge.scoreAccuracy, 0.9, accuracy: 1e-12)
    }

    func testBigramModelCountsPatterns() {
        let model = BigramModel(sentences: LanguageContent.corpus(language: "en"))
        XCTAssertEqual(model.mostLikely(after: "cat"), "likes")
        XCTAssertEqual(model.mostLikely(after: "likes"), "fish")
        XCTAssertEqual(model.mostLikely(after: "the"), "cat")
        let after = model.predictions(after: "likes")
        XCTAssertEqual(after.first?.probability ?? 0, 4.0 / 6.0, accuracy: 1e-12)
        XCTAssertNil(model.mostLikely(after: "fish"), "nothing follows the last word")
        let spanish = BigramModel(sentences: LanguageContent.corpus(language: "es"))
        XCTAssertEqual(spanish.mostLikely(after: "gato"), "come")
    }

    func testNextWordChallenge() {
        for language in ["en", "es"] {
            var challenge = LanguageContent.makeNextWord(spec: specs[1], difficulty: difficulty, seed: 5, language: language)
            XCTAssertGreaterThanOrEqual(challenge.rounds.count, 2)
            for round in challenge.rounds {
                XCTAssertEqual(round.options.count, 3)
                XCTAssertTrue(round.options.contains(round.answer))
                XCTAssertEqual(challenge.model.mostLikely(after: round.context), round.answer)
            }
            XCTAssertNil(challenge.pick("zzz"))
            while let round = challenge.current {
                challenge.pick(round.answer)
            }
            XCTAssertEqual(challenge.scoreAccuracy, 1, accuracy: 1e-12)
        }
    }

    func testTalkAndConversation() {
        var talk = LanguageContent.makeTalk(spec: specs[2], difficulty: difficulty, seed: 1, language: "en")
        talk.record("   ")
        XCTAssertTrue(talk.utterances.isEmpty)
        talk.record("The kittens are playing")
        XCTAssertEqual(talk.tokens(of: "The kittens are playing"), ["the", "kit", "ten", "s", "are", "play", "ing"])
        while !talk.isSolved { talk.record("robots") }
        XCTAssertEqual(talk.scoreAccuracy, 1)

        var chat = LanguageContent.makeConversation(spec: specs[3], difficulty: difficulty, seed: 2)
        XCTAssertTrue(chat.turns.contains { $0.isWrong })
        XCTAssertTrue(chat.turns.contains { !$0.isWrong })
        for turn in chat.turns {
            XCTAssertEqual(chat.judge(turn.id, believes: !turn.isWrong), true)
            XCTAssertNil(chat.judge(turn.id, believes: true), "judgements are final")
        }
        XCTAssertTrue(chat.isComplete)
        XCTAssertEqual(chat.scoreAccuracy, 1, accuracy: 1e-12)
    }
}
