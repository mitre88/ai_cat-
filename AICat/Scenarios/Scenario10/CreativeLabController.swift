import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one Creative Lab challenge: story seeds, remix, helper design or the graduation quiz.
/// Stories come from AI CAT's pattern book; with creative mode on, the on-device model may write them.
@MainActor
@Observable
final class CreativeLabController {
    enum Level: Equatable {
        case seeds, remix, helper, graduation
    }

    let spec: ChallengeSpec
    let level: Level
    private(set) var seedsChallenge: StorySeedChallenge?
    private(set) var remix: RemixChallenge?
    private(set) var helper: HelperDesignChallenge?
    private(set) var quiz: GraduationQuiz?
    private(set) var isDone = false
    private(set) var isImagining = false
    private(set) var hintsLeft: Int

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var storySeed: UInt64
    @ObservationIgnored private var imagineTask: Task<Void, Never>?

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 9_576_890_767 &+ UInt64(spec.index) &* 41
        storySeed = seed
        let difficulty = app.profile.difficulty
        if spec.param("graduation", default: 0) == 1 {
            level = .graduation
            quiz = CreativeContent.makeGraduation(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("design", default: 0) == 1 {
            level = .helper
            helper = CreativeContent.makeHelperDesign(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("remix", default: 0) == 1 {
            level = .remix
            remix = CreativeContent.makeRemix(spec: spec, difficulty: difficulty, seed: seed)
        } else {
            level = .seeds
            seedsChallenge = CreativeContent.makeStorySeeds(spec: spec, difficulty: difficulty, seed: seed)
        }
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Derived

    var isSolved: Bool {
        seedsChallenge?.isSolved ?? remix?.isSolved ?? helper?.isSolved ?? quiz?.isSolved ?? false
    }

    var canConfirm: Bool {
        guard !isDone, !isImagining else { return false }
        if let helper { return helper.passedCount >= 4 }
        return isSolved
    }

    var canRequestHint: Bool { hintsLeft > 0 && !isDone && !isSolved && (level == .helper || level == .remix) }

    private var scoreAccuracy: Double {
        seedsChallenge?.scoreAccuracy ?? remix?.scoreAccuracy ?? helper?.scoreAccuracy ?? quiz?.scoreAccuracy ?? 0
    }

    var catName: String { app.profile.catName }

    /// The sentences of a story, rendered in the current language (model text when the model wrote it).
    func sentences(of story: GeneratedStory) -> [String] {
        if story.source == .model, let model = story.modelSentences, model.count == StoryBank.sentenceCount {
            return model
        }
        let words = story.seeds.words.map { L10n.string($0.key) }
        return story.templateKeys.map { key in
            Self.capitalized(L10n.format(key, words[0], words[1], words[2]))
        }
    }

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    // MARK: Stage

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.45, 0, 0.2]
        world.cat.stopWalking()
        let bench = PropFactory.pedestal(color: Color(red: 0.6, green: 0.5, blue: 0.4), radius: 0.34)
        bench.position = [-0.45, 0, 0.3]
        world.addProp(bench, id: "bench")
        for (index, side) in [-1, 1].enumerated() {
            let page = ModelEntity(mesh: .generateBox(size: [0.22, 0.012, 0.3], cornerRadius: 0.004),
                                   materials: [Materials.matte(Color(red: 0.98, green: 0.96, blue: 0.9))])
            page.position = [-0.45 + Float(side) * 0.115, 0.135, 0.3]
            page.orientation = simd_quatf(angle: Float(side) * 0.12, axis: [0, 0, 1])
            world.addProp(page, id: "page_\(index)")
        }
        let ink = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [Materials.glossy(Color(red: 0.2, green: 0.3, blue: 0.7))])
        ink.position = [-0.75, 0.16, 0.42]
        ink.components.set(GroundingShadowComponent(castsShadow: true))
        world.addProp(ink, id: "ink")
        world.cat.lookAt([-0.45, 0.2, 0.3])
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        updateProgress()
    }

    private func frame(_ dt: Float) {
        guard let countdown = finishCountdown else { return }
        let next = countdown - dt
        if next <= 0 {
            finishCountdown = nil
            session.finish(accuracy: scoreAccuracy, app: app)
        } else {
            finishCountdown = next
        }
    }

    private func updateProgress() {
        if let seedsChallenge { session.progress = min(1, Double(seedsChallenge.distinctSeedSets) / Double(seedsChallenge.required)) }
        if let remix { session.progress = min(1, Double(remix.changedSentences) / Double(remix.requiredChanges)) }
        if let helper { session.progress = Double(helper.passedCount) / Double(HelperCheck.allCases.count) }
        if let quiz { session.progress = Double(quiz.answers.count) / Double(max(quiz.questions.count, 1)) }
    }

    private func react() {
        updateProgress()
        world.cat.set(emotion: isSolved ? .proud : .curious)
    }

    // MARK: Story seeds

    func select(_ word: StoryWord) {
        guard !isDone, var challenge = seedsChallenge else { return }
        challenge.select(word)
        seedsChallenge = challenge
    }

    func grow() {
        guard !isDone, !isImagining, var challenge = seedsChallenge, challenge.seeds != nil else { return }
        storySeed = storySeed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        guard let story = challenge.generate(seed: storySeed) else { return }
        seedsChallenge = challenge
        world.cat.play(gesture: .headTilt)
        app.say(.correct)
        react()
        imagine(story)
    }

    /// Creative mode: ask the on-device model for its own three sentences; the pattern story stays otherwise.
    private func imagine(_ story: GeneratedStory) {
        guard app.context.creativeMode else { return }
        imagineTask?.cancel()
        isImagining = true
        let seedWords = story.seeds.words.map { L10n.string($0.key) }
        let context = app.context
        imagineTask = Task { [weak self] in
            guard let self else { return }
            let sentences = await self.app.brain.story(from: seedWords, context: context)
            guard !Task.isCancelled else { return }
            if let sentences, var challenge = self.seedsChallenge, challenge.latest?.seeds == story.seeds {
                challenge.attachModelSentences(sentences)
                self.seedsChallenge = challenge
            }
            self.isImagining = false
        }
    }

    // MARK: Remix

    func cycle(sentence index: Int) {
        guard !isDone, var challenge = remix else { return }
        challenge.cycle(sentence: index)
        remix = challenge
        react()
    }

    func chooseTitle(_ index: Int) {
        guard !isDone, var challenge = remix else { return }
        challenge.chooseTitle(index)
        remix = challenge
        react()
    }

    // MARK: Helper design

    func choose(_ goal: HelperGoal) {
        guard !isDone, var challenge = helper else { return }
        challenge.choose(goal)
        helper = challenge
        react()
    }

    func toggle(_ item: HelperData) {
        guard !isDone, var challenge = helper else { return }
        challenge.toggle(item)
        helper = challenge
        react()
    }

    func toggle(_ rule: HelperRule) {
        guard !isDone, var challenge = helper else { return }
        challenge.toggle(rule)
        helper = challenge
        react()
    }

    // MARK: Graduation

    func answer(_ questionID: String, option: Int) {
        guard !isDone, var challenge = quiz else { return }
        challenge.answer(questionID, option: option)
        quiz = challenge
        if let question = challenge.questions.first(where: { $0.id == questionID }) {
            if challenge.isCorrect(question) == true {
                world.cat.play(gesture: .nod)
                app.say(.correct)
            } else {
                world.cat.play(gesture: .headTilt)
                app.say(.encouragement)
            }
        }
        react()
    }

    // MARK: Hints and finishing

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        session.noteHint()
        app.say(.hint)
        if var challenge = remix {
            if challenge.changedSentences < challenge.requiredChanges {
                let index = challenge.variants.indices.first { challenge.variants[$0] == challenge.original.variants[$0] } ?? 0
                challenge.cycle(sentence: index)
            } else if challenge.titleIndex == nil {
                challenge.chooseTitle(0)
            }
            remix = challenge
        } else if var challenge = helper {
            if !challenge.passes(.goalChosen) {
                challenge.choose(.plantCare)
            } else if !challenge.passes(.noPrivateData) {
                for item in challenge.data where item.isPrivate { challenge.toggle(item) }
            } else if !challenge.passes(.dataHelpsGoal), let goal = challenge.goal {
                for item in challenge.data where !item.relevantGoals.contains(goal) { challenge.toggle(item) }
                if let useful = HelperData.allCases.first(where: { $0.relevantGoals.contains(goal) && !challenge.data.contains($0) }) {
                    challenge.toggle(useful)
                }
            } else if !challenge.passes(.noBadRules) {
                for rule in challenge.rules where !rule.isGood { challenge.toggle(rule) }
            } else if !challenge.passes(.privacyRule) {
                challenge.toggle(.neverKeepPrivate)
            } else if !challenge.passes(.humanRule) {
                challenge.toggle(.personChecks)
            }
            helper = challenge
        }
        react()
    }

    func confirm() {
        guard canConfirm else { return }
        isDone = true
        session.progress = 1
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        world.celebrate()
        app.say(level == .graduation ? .scenarioComplete : .aiSorted)
        finishCountdown = level == .graduation ? 2.6 : 1.8
    }
}
