import XCTest
@testable import AICatCore

final class StoryMachineTests: XCTestCase {
    private var specs: [ChallengeSpec] { Curriculum.scenario(.creativeLab).challenges }
    private let difficulty = AdaptiveDifficulty(value: 0.45)

    func testGeneratorIsSeededAndSensitiveToWords() {
        let seeds = StorySeeds(character: StoryBank.characters[0], place: StoryBank.places[1], object: StoryBank.objects[2])
        let a = StoryGenerator.generate(seeds: seeds, seed: 42)
        let b = StoryGenerator.generate(seeds: seeds, seed: 42)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.variants.count, 3)
        XCTAssertTrue(a.variants.allSatisfy { (0..<3).contains($0) })
        XCTAssertEqual(a.templateKeys[0], "story.s0.v\(a.variants[0])")
        let other = StorySeeds(character: StoryBank.characters[3], place: seeds.place, object: seeds.object)
        XCTAssertNotEqual(StoryGenerator.generate(seeds: other, seed: 42).seeds, a.seeds)
        var differing = false
        for seed in 1...30 where StoryGenerator.generate(seeds: seeds, seed: UInt64(seed)).variants != a.variants { differing = true }
        XCTAssertTrue(differing, "different seeds give different sentence variants")
    }

    func testStorySeedChallenge() {
        var challenge = CreativeContent.makeStorySeeds(spec: specs[0], difficulty: difficulty, seed: 1)
        XCTAssertEqual(challenge.required, 3)
        XCTAssertNil(challenge.generate(seed: 5), "all three words are needed")
        challenge.select(StoryBank.characters[1])
        challenge.select(StoryBank.places[2])
        challenge.select(StoryBank.objects[3])
        XCTAssertNotNil(challenge.generate(seed: 5))
        XCTAssertNotNil(challenge.generate(seed: 5))
        XCTAssertEqual(challenge.stories.count, 2)
        XCTAssertEqual(challenge.distinctSeedSets, 1, "same words = same seed set, however many times")
        challenge.select(StoryBank.characters[4])
        challenge.generate(seed: 5)
        challenge.select(StoryBank.objects[0])
        challenge.generate(seed: 5)
        XCTAssertEqual(challenge.distinctSeedSets, 3)
        XCTAssertTrue(challenge.isSolved)
        XCTAssertEqual(challenge.scoreAccuracy, 1)
        challenge.attachModelSentences(["Uno.", "Dos.", "Tres."])
        XCTAssertEqual(challenge.latest?.source, .model)
        XCTAssertEqual(challenge.latest?.modelSentences?.count, 3)
        let explorer = CreativeContent.makeStorySeeds(spec: specs[0], difficulty: AdaptiveDifficulty(value: 0.2), seed: 1)
        XCTAssertEqual(explorer.required, 2)
    }

    func testRemix() {
        var challenge = CreativeContent.makeRemix(spec: specs[1], difficulty: difficulty, seed: 9)
        XCTAssertEqual(challenge.requiredChanges, 2)
        XCTAssertEqual(challenge.changedSentences, 0)
        challenge.cycle(sentence: 0)
        XCTAssertEqual(challenge.changedSentences, 1)
        challenge.cycle(sentence: 0)
        challenge.cycle(sentence: 0)
        XCTAssertEqual(challenge.changedSentences, 0, "three taps cycle back to the original")
        challenge.cycle(sentence: 1)
        challenge.cycle(sentence: 2)
        XCTAssertFalse(challenge.isSolved, "a title is needed too")
        challenge.chooseTitle(7)
        XCTAssertNil(challenge.titleIndex)
        challenge.chooseTitle(2)
        XCTAssertTrue(challenge.isSolved)
        XCTAssertEqual(challenge.current.seeds, challenge.original.seeds)
        XCTAssertEqual(challenge.scoreAccuracy, 1)
    }

    func testHelperDesignChecks() {
        var design = CreativeContent.makeHelperDesign(spec: specs[2], difficulty: difficulty, seed: 1)
        XCTAssertEqual(design.passedCount, 2, "no private data and no bad rules pass on an empty design")
        design.choose(.plantCare)
        design.toggle(.plantTypes)
        design.toggle(.wateringDays)
        design.toggle(.neverKeepPrivate)
        design.toggle(.personChecks)
        XCTAssertTrue(design.isSolved)
        design.toggle(.homeAddress)
        XCTAssertFalse(design.passes(.noPrivateData))
        XCTAssertTrue(design.passes(.dataHelpsGoal), "private data is judged by its own check")
        design.toggle(.homeAddress)
        design.toggle(.birdRecordings)
        XCTAssertFalse(design.passes(.dataHelpsGoal), "bird recordings do not help with plants")
        design.toggle(.birdRecordings)
        design.toggle(.collectEverything)
        XCTAssertFalse(design.passes(.noBadRules))
        design.toggle(.collectEverything)
        XCTAssertEqual(design.scoreAccuracy, 1, accuracy: 1e-12)
    }

    func testGraduationQuiz() {
        var quiz = CreativeContent.makeGraduation(spec: specs[3], difficulty: difficulty, seed: 4)
        XCTAssertGreaterThanOrEqual(quiz.questions.count, 3)
        XCTAssertEqual(Set(quiz.questions.map(\.id)).count, quiz.questions.count)
        XCTAssertTrue(CreativeContent.quizBank.allSatisfy { (0..<QuizQuestion.optionCount).contains($0.answer) })
        for question in quiz.questions {
            quiz.answer(question.id, option: question.answer)
            quiz.answer(question.id, option: (question.answer + 1) % 3)   // final answers
        }
        XCTAssertTrue(quiz.isComplete)
        XCTAssertEqual(quiz.correctCount, quiz.questions.count)
        XCTAssertEqual(quiz.scoreAccuracy, 1, accuracy: 1e-12)
    }
}
