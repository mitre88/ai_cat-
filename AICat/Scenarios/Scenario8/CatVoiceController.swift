import RealityKit
import SwiftUI
import Observation
import AICatCore

/// Drives one AI CAT's Voice challenge: tokens, next-word guessing, talking (on-device speech) and a
/// conversation with planted mistakes. The creative extra asks the on-device model a kid-chosen question.
@MainActor
@Observable
final class CatVoiceController {
    enum Level: Equatable {
        case tokens, nextWord, talk, chat
    }

    enum Feedback: Equatable {
        case wrongChip, roundDone, pickRight, pickWrong(String), caught, missed, trustedRight, doubtedRight
    }

    enum ListeningState: Equatable {
        case needsParent, idle, listening, unavailable
    }

    let spec: ChallengeSpec
    let level: Level
    private(set) var tokens: TokenChallenge?
    private(set) var nextWord: NextWordChallenge?
    private(set) var talk: TalkChallenge?
    private(set) var chat: ConversationChallenge?
    private(set) var isDone = false
    private(set) var hintsLeft: Int
    private(set) var feedback: Feedback?

    // Talk level
    let listener = SpeechListener()
    private(set) var listeningState: ListeningState = .needsParent
    private(set) var lastTranscript: String?

    // Creative extra (chat level)
    private(set) var askedQuestion: String?
    private(set) var modelAnswer: String?
    private(set) var isAsking = false
    private(set) var modelDeclined = false

    @ObservationIgnored private let world: WorldModel
    @ObservationIgnored private let session: ChallengeSession
    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var finishCountdown: Float?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var askTask: Task<Void, Never>?

    init(spec: ChallengeSpec, world: WorldModel, session: ChallengeSession, app: AppModel) {
        self.spec = spec
        self.world = world
        self.session = session
        self.app = app
        let attempt = UInt64(truncatingIfNeeded: app.profile.results.count + 1)
        let seed = attempt &* 3_266_489_917 &+ UInt64(spec.index) &* 29
        let difficulty = app.profile.difficulty
        let language = app.profile.languageCode
        if spec.param("model", default: 0) == 1 {
            level = .chat
            chat = LanguageContent.makeConversation(spec: spec, difficulty: difficulty, seed: seed)
        } else if spec.param("speech", default: 0) == 1 {
            level = .talk
            talk = LanguageContent.makeTalk(spec: spec, difficulty: difficulty, seed: seed, language: language)
        } else if spec.param("nextWord", default: 0) == 1 {
            level = .nextWord
            nextWord = LanguageContent.makeNextWord(spec: spec, difficulty: difficulty, seed: seed, language: language)
        } else {
            level = .tokens
            tokens = LanguageContent.makeTokens(spec: spec, difficulty: difficulty, seed: seed, language: language)
        }
        switch app.profile.ageBand {
        case .explorer: hintsLeft = 9
        case .apprentice: hintsLeft = spec.isMaster ? 2 : 4
        case .master: hintsLeft = spec.isMaster ? 1 : 2
        }
    }

    // MARK: Derived

    var isSolved: Bool {
        tokens?.isSolved ?? nextWord?.isSolved ?? talk?.isSolved ?? chat?.isSolved ?? false
    }

    var canConfirm: Bool { !isDone && isSolved && !isAsking }
    var canRequestHint: Bool { hintsLeft > 0 && !isDone && !isSolved && (level == .tokens || level == .nextWord) }
    var speechSupported: Bool { SpeechListener.isSupported(language: app.language) }
    var creativeModeOn: Bool { app.context.creativeMode }
    var catName: String { app.profile.catName }

    private var scoreAccuracy: Double {
        tokens?.scoreAccuracy ?? nextWord?.scoreAccuracy ?? talk?.scoreAccuracy ?? chat?.scoreAccuracy ?? 0
    }

    // MARK: Stage

    func start() {
        guard !started else { return }
        started = true
        world.clearProps()
        world.cat.root.position = [0.1, 0, 0.25]
        world.cat.stopWalking()
        let stage = PropFactory.pedestal(color: Color(red: 0.55, green: 0.3, blue: 0.35), radius: 0.5)
        stage.position = [0, 0, 0.1]
        world.addProp(stage, id: "stage")
        for (index, side) in [-1, 1].enumerated() {
            let curtain = ModelEntity(mesh: .generateBox(size: [0.16, 0.9, 0.05], cornerRadius: 0.01), materials: [Materials.carpet(Color(red: 0.7, green: 0.15, blue: 0.2), repeats: 2)])
            curtain.position = [Float(side) * 0.62, 0.45, -0.25]
            world.addProp(curtain, id: "curtain_\(index)")
        }
        let stand = ModelEntity(mesh: .generateCylinder(height: 0.3, radius: 0.012), materials: [Materials.metal(Color.gray)])
        stand.position = [-0.3, 0.17, 0.35]
        world.addProp(stand, id: "mic_stand")
        let mic = ModelEntity(mesh: .generateSphere(radius: 0.04), materials: [Materials.matte(Color(red: 0.3, green: 0.3, blue: 0.35))])
        mic.position = [-0.3, 0.34, 0.35]
        mic.components.set(GroundingShadowComponent(castsShadow: true))
        world.addProp(mic, id: "mic")
        world.cat.lookAt([-0.3, 0.34, 0.35])
        world.onFrame = { [weak self] dt in self?.frame(dt) }
        updateProgress()
    }

    private func setMicGlow(_ on: Bool) {
        guard let mic = world.prop(id: "mic") as? ModelEntity else { return }
        mic.model?.materials = [on ? Materials.glowing(Color(red: 1, green: 0.4, blue: 0.4), intensity: 1.6) : Materials.matte(Color(red: 0.3, green: 0.3, blue: 0.35))]
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
        if let tokens { session.progress = Double(tokens.roundIndex) / Double(max(tokens.rounds.count, 1)) }
        if let nextWord { session.progress = Double(nextWord.answers.count) / Double(max(nextWord.rounds.count, 1)) }
        if let talk { session.progress = Double(talk.utterances.count) / Double(talk.required) }
        if let chat { session.progress = Double(chat.revealedCount) / Double(max(chat.turns.count, 1)) }
    }

    private func react() {
        updateProgress()
        world.cat.set(emotion: isSolved ? .proud : .curious)
    }

    // MARK: Tokens

    func tapChip(_ chip: String) {
        guard !isDone, var challenge = tokens else { return }
        guard let result = challenge.tap(chip) else { return }
        tokens = challenge
        switch result {
        case .accepted:
            feedback = nil
        case .wrong:
            feedback = .wrongChip
            world.cat.play(gesture: .headTilt)
            app.say(.wrong)
        case .roundComplete:
            feedback = .roundDone
            world.cat.play(gesture: .nod)
            app.say(.correct)
        case .allComplete:
            feedback = .roundDone
            world.cat.play(gesture: .jump)
            app.say(.aiLearned)
        }
        react()
    }

    // MARK: Next word

    func pickWord(_ word: String) {
        guard !isDone, var challenge = nextWord, let round = challenge.current else { return }
        guard let right = challenge.pick(word) else { return }
        nextWord = challenge
        feedback = right ? .pickRight : .pickWrong(round.answer)
        world.cat.play(gesture: right ? .nod : .headTilt)
        app.say(right ? .correct : .encouragement)
        react()
    }

    // MARK: Talk

    func approveParent() {
        guard listeningState == .needsParent else { return }
        listeningState = speechSupported ? .idle : .unavailable
    }

    func listen() {
        guard !isDone, listeningState == .idle, talk != nil else { return }
        app.hush()
        listeningState = .listening
        setMicGlow(true)
        world.cat.set(emotion: .curious)
        Task { [weak self] in
            guard let self else { return }
            let text = await self.listener.listen(language: self.app.language)
            self.setMicGlow(false)
            if let text {
                self.lastTranscript = text
                self.talk?.record(text)
                self.listeningState = .idle
                self.world.cat.play(gesture: .nod)
                self.app.say(self.talk?.isSolved == true ? .aiLearned : .correct)
            } else if self.listener.isDenied {
                self.listeningState = .unavailable
            } else {
                self.listeningState = .idle
                self.app.say(.aiNeedsMore)
            }
            self.react()
        }
    }

    func pretend(_ text: String) {
        guard !isDone, talk != nil else { return }
        lastTranscript = text
        talk?.record(text)
        world.cat.play(gesture: .nod)
        app.say(talk?.isSolved == true ? .aiLearned : .correct)
        react()
    }

    func tokens(of text: String) -> [String] { talk?.tokens(of: text) ?? [] }

    // MARK: Chat

    func judge(_ turnID: String, believes: Bool) {
        guard !isDone, var challenge = chat, let turn = challenge.turns.first(where: { $0.id == turnID }) else { return }
        guard let right = challenge.judge(turnID, believes: believes) else { return }
        chat = challenge
        switch (turn.isWrong, believes) {
        case (true, false): feedback = .caught
        case (true, true): feedback = .missed
        case (false, true): feedback = .trustedRight
        case (false, false): feedback = .doubtedRight
        }
        world.cat.play(gesture: right ? .nod : .headTilt)
        app.say(right ? .correct : .encouragement)
        react()
    }

    /// Creative mode: the child picks one of three questions and the on-device model answers (filtered).
    func ask(_ question: String) {
        guard !isDone, creativeModeOn, !isAsking else { return }
        askedQuestion = question
        modelAnswer = nil
        modelDeclined = false
        isAsking = true
        let context = app.context
        askTask?.cancel()
        askTask = Task { [weak self] in
            guard let self else { return }
            let answer = await self.app.brain.answer(question: question, context: context)
            guard !Task.isCancelled else { return }
            self.modelAnswer = answer
            self.modelDeclined = answer == nil
            self.isAsking = false
            if let answer {
                self.app.say(text: answer, emotion: .thinking, gesture: .headTilt)
            }
        }
    }

    // MARK: Hints and finishing

    func requestHint() {
        guard canRequestHint else { return }
        hintsLeft -= 1
        session.noteHint()
        app.say(.hint)
        if var challenge = tokens, let piece = challenge.nextPiece {
            challenge.tap(piece)
            tokens = challenge
        } else if var challenge = nextWord, let round = challenge.current {
            challenge.pick(round.answer)
            nextWord = challenge
            feedback = .pickRight
        }
        react()
    }

    func stopListening() {
        listener.stop()
        setMicGlow(false)
        if listeningState == .listening { listeningState = .idle }
    }

    func confirm() {
        guard canConfirm else { return }
        isDone = true
        session.progress = 1
        stopListening()
        world.cat.lookAt(nil)
        world.cat.play(gesture: .jump)
        world.celebrate()
        app.say(.aiSorted)
        finishCountdown = 1.8
    }
}
