import Foundation

/// Everything the game remembers about one player. Persisted by the app as JSON.
/// No personal data: the child names the cat, never themselves.
public struct PlayerProfile: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var catName: String
    public var ageBand: AgeBand
    public var languageCode: String          // "en" | "es"
    public var totalXP: Int
    public var difficulty: AdaptiveDifficulty
    public var results: [ChallengeResult]
    public var passedChallenges: Set<String>
    public var unlockedKnowledge: [KnowledgeItem]
    public var voiceEnabled: Bool
    public var creativeModeEnabled: Bool     // parent opt-in for generative lines
    public var reduceEffects: Bool
    public var onboardingDone: Bool
    public var createdAt: Date

    public init(catName: String, ageBand: AgeBand, languageCode: String, createdAt: Date = Date()) {
        schemaVersion = Self.schemaVersion
        self.catName = catName
        self.ageBand = ageBand
        self.languageCode = languageCode
        totalXP = 0
        difficulty = AdaptiveDifficulty(band: ageBand)
        results = []
        passedChallenges = []
        unlockedKnowledge = []
        voiceEnabled = true
        creativeModeEnabled = false
        reduceEffects = false
        onboardingDone = false
        self.createdAt = createdAt
    }

    // MARK: Derived

    public var growth: Double { GrowthModel.normalizedGrowth(xp: Double(totalXP)) }
    public var stage: Int { GrowthModel.stage(xp: Double(totalXP)) }
    public var morphology: CatMorphology { CatMorphology.interpolated(growth: growth) }
    public var stageProgress: Double { GrowthModel.progressWithinStage(xp: Double(totalXP)) }
    public var xpToNextStage: Int {
        let next = min(stage + 1, GrowthModel.stageCount)
        return max(0, Int(GrowthModel.xpForStage(next)) - totalXP)
    }

    public func isPassed(_ challengeID: String) -> Bool {
        passedChallenges.contains(challengeID)
    }

    public func bestResult(for challengeID: String) -> ChallengeResult? {
        results.filter { $0.challengeID == challengeID }.max { $0.accuracy < $1.accuracy }
    }

    /// A scenario is complete when its three core challenges are passed.
    public func isCompleted(_ id: ScenarioID) -> Bool {
        Curriculum.scenario(id).coreChallenges.allSatisfy { passedChallenges.contains($0.id) }
    }

    /// Scenario 1 is always open; scenario n opens when n−1 is complete. Non-playable scenarios stay locked.
    public func isUnlocked(_ id: ScenarioID) -> Bool {
        guard Curriculum.scenario(id).isPlayable else { return false }
        guard let previous = id.previous else { return true }
        return isCompleted(previous)
    }

    /// Challenge k of a scenario opens after challenge k−1 is passed; the master challenge after the three core ones.
    public func isUnlocked(challenge spec: ChallengeSpec) -> Bool {
        guard isUnlocked(spec.scenario) else { return false }
        let scenario = Curriculum.scenario(spec.scenario)
        if spec.isMaster { return isCompleted(spec.scenario) }
        guard spec.index > 1 else { return true }
        guard let previous = scenario.challenges.first(where: { $0.index == spec.index - 1 }) else { return true }
        return passedChallenges.contains(previous.id)
    }

    public var completedScenarioCount: Int {
        ScenarioID.allCases.filter { isCompleted($0) }.count
    }

    // MARK: Recording

    public struct RecordOutcome: Equatable, Sendable {
        public var xpGained: Int
        public var passed: Bool
        public var previousStage: Int
        public var newStage: Int
        public var scenarioJustCompleted: ScenarioID?
        public var knowledgeUnlocked: KnowledgeItem?
        public var nextScenarioUnlocked: ScenarioID?

        public var stageIncreased: Bool { newStage > previousStage }
    }

    /// Apply a finished challenge: XP, difficulty, unlocks. Replays of a passed challenge still grant XP
    /// (growth is effort), but only the first pass unlocks content.
    public mutating func record(_ result: ChallengeResult, spec: ChallengeSpec) -> RecordOutcome {
        let before = stage
        let wasCompleted = isCompleted(spec.scenario)
        let passed = Scoring.isPassed(accuracy: result.accuracy)
        let gained = passed ? Scoring.xp(tier: spec.tier, accuracy: result.accuracy) : Scoring.xp(tier: 1, accuracy: 0.5) / 2
        totalXP += gained
        results.append(result)
        difficulty.update(accuracy: result.accuracy)
        if passed { passedChallenges.insert(spec.id) }

        var outcome = RecordOutcome(xpGained: gained, passed: passed, previousStage: before, newStage: stage,
                                    scenarioJustCompleted: nil, knowledgeUnlocked: nil, nextScenarioUnlocked: nil)
        if !wasCompleted, isCompleted(spec.scenario) {
            outcome.scenarioJustCompleted = spec.scenario
            let item = Curriculum.scenario(spec.scenario).knowledgeReward
            if !unlockedKnowledge.contains(item) {
                unlockedKnowledge.append(item)
                outcome.knowledgeUnlocked = item
            }
            if let next = spec.scenario.next, isUnlocked(next) {
                outcome.nextScenarioUnlocked = next
            }
        }
        return outcome
    }
}
