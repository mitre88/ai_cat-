import SwiftUI
import Observation
import AICatCore

/// Global game state: the profile, navigation, AI CAT's current line and the services behind it.
@MainActor
@Observable
final class AppModel {
    private(set) var profile: PlayerProfile
    var path = NavigationPath()
    var isParentZonePresented = false
    /// The line AI CAT is currently saying (shown in bubbles and voiced).
    private(set) var speech: CatLine?

    private let store: ProgressStore
    let voice: CatVoice
    @ObservationIgnored var brain: any CatBrain
    @ObservationIgnored private var speechTask: Task<Void, Never>?

    init(store: ProgressStore = ProgressStore()) {
        self.store = store
        let loaded = store.load()
        let initial = loaded ?? PlayerProfile(catName: "AI CAT", ageBand: .apprentice, languageCode: L10n.Language.preferred.rawValue)
        profile = initial
        L10n.current = L10n.Language(rawValue: initial.languageCode) ?? .english
        voice = CatVoice()
        voice.isEnabled = initial.voiceEnabled
        brain = BrainRouter()
    }

    // MARK: Derived

    var language: L10n.Language { L10n.Language(rawValue: profile.languageCode) ?? .english }

    var context: BrainContext {
        BrainContext(language: language, ageBand: profile.ageBand, catName: profile.catName, creativeMode: profile.creativeModeEnabled)
    }

    var reduceMotion: Bool {
        profile.reduceEffects || UIAccessibility.isReduceMotionEnabled
    }

    // MARK: Profile changes

    func update(_ change: (inout PlayerProfile) -> Void) {
        change(&profile)
        L10n.current = language
        voice.isEnabled = profile.voiceEnabled
        save()
    }

    func setLanguage(_ language: L10n.Language) {
        update { $0.languageCode = language.rawValue }
    }

    func completeOnboarding(catName: String) {
        let trimmed = catName.trimmingCharacters(in: .whitespacesAndNewlines)
        update {
            $0.catName = trimmed.isEmpty ? "AI CAT" : String(trimmed.prefix(14))
            $0.onboardingDone = true
        }
        say(.greeting)
    }

    func resetProgress() {
        var fresh = PlayerProfile(catName: profile.catName, ageBand: profile.ageBand, languageCode: profile.languageCode)
        fresh.onboardingDone = true
        fresh.voiceEnabled = profile.voiceEnabled
        fresh.creativeModeEnabled = profile.creativeModeEnabled
        fresh.reduceEffects = profile.reduceEffects
        profile = fresh
        path = NavigationPath()
        save()
    }

    func save() {
        store.save(profile)
    }

    /// Record a finished challenge and return what changed (XP, stage, unlocks).
    @discardableResult
    func finishChallenge(_ spec: ChallengeSpec, accuracy: Double, hintsUsed: Int, duration: TimeInterval) -> PlayerProfile.RecordOutcome {
        let result = ChallengeResult(challengeID: spec.id, accuracy: accuracy, hintsUsed: hintsUsed, durationSeconds: duration)
        let outcome = profile.record(result, spec: spec)
        save()
        return outcome
    }

    // MARK: AI CAT speaks

    func say(_ moment: DialogMoment, scenario: ScenarioID? = nil) {
        speechTask?.cancel()
        let ctx = context
        speechTask = Task { [weak self] in
            guard let self else { return }
            let line = await self.brain.line(for: moment, scenario: scenario, context: ctx)
            guard !Task.isCancelled else { return }
            self.present(line)
        }
    }

    func say(text: String, emotion: CatEmotion = .happy, gesture: CatGesture = .none) {
        speechTask?.cancel()
        present(CatLine(text: text, emotion: emotion, gesture: gesture, lineID: nil))
    }

    func hush() {
        speechTask?.cancel()
        voice.stop()
    }

    private func present(_ line: CatLine) {
        speech = line
        voice.speak(line.text, language: language)
    }
}
