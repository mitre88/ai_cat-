import Foundation

/// AI4K12 "Five Big Ideas in AI".
public enum BigIdea: String, Codable, Sendable, CaseIterable {
    case perception
    case representation
    case learning
    case naturalInteraction
    case societalImpact

    public var titleKey: TextKey {
        switch self {
        case .perception: return TextKey("bigidea.perception")
        case .representation: return TextKey("bigidea.representation")
        case .learning: return TextKey("bigidea.learning")
        case .naturalInteraction: return TextKey("bigidea.natural_interaction")
        case .societalImpact: return TextKey("bigidea.societal_impact")
        }
    }
}

/// Visual theme of a world (palette and props are built procedurally from it).
public enum WorldTheme: String, Codable, Sendable, CaseIterable {
    case garden, library, workshop, trail, maze, factory, lookout, theater, plaza, lab
}

/// Knowledge accessories AI CAT earns, one per completed scenario.
public enum KnowledgeItem: String, Codable, Sendable, CaseIterable, Identifiable {
    case collar        // 1
    case bandana       // 2
    case glasses       // 3
    case backpack      // 4
    case compass       // 5
    case headband      // 6
    case goggles       // 7
    case headphones    // 8
    case badge         // 9
    case graduationCap // 10

    public var id: String { rawValue }

    public var titleKey: TextKey {
        switch self {
        case .collar: return TextKey("knowledge.collar")
        case .bandana: return TextKey("knowledge.bandana")
        case .glasses: return TextKey("knowledge.glasses")
        case .backpack: return TextKey("knowledge.backpack")
        case .compass: return TextKey("knowledge.compass")
        case .headband: return TextKey("knowledge.headband")
        case .goggles: return TextKey("knowledge.goggles")
        case .headphones: return TextKey("knowledge.headphones")
        case .badge: return TextKey("knowledge.badge")
        case .graduationCap: return TextKey("knowledge.graduation_cap")
        }
    }
}

public struct Scenario: Identifiable, Hashable, Sendable {
    public let id: ScenarioID
    public let titleKey: TextKey
    public let subtitleKey: TextKey
    public let conceptKey: TextKey
    public let introKey: TextKey
    public let bigIdea: BigIdea
    public let theme: WorldTheme
    public let challenges: [ChallengeSpec]
    public let knowledgeReward: KnowledgeItem

    public init(id: ScenarioID, titleKey: TextKey, subtitleKey: TextKey, conceptKey: TextKey, introKey: TextKey,
                bigIdea: BigIdea, theme: WorldTheme, challenges: [ChallengeSpec], knowledgeReward: KnowledgeItem) {
        self.id = id
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.conceptKey = conceptKey
        self.introKey = introKey
        self.bigIdea = bigIdea
        self.theme = theme
        self.challenges = challenges
        self.knowledgeReward = knowledgeReward
    }

    /// A scenario is playable when all of its challenges have a playable mechanic.
    public var isPlayable: Bool { challenges.allSatisfy { $0.mechanic.isPlayable } }

    /// The three regular challenges (the master challenge is optional for progression).
    public var coreChallenges: [ChallengeSpec] { challenges.filter { !$0.isMaster } }
    public var masterChallenge: ChallengeSpec? { challenges.first { $0.isMaster } }
}
