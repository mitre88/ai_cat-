import Foundation

/// The interaction a challenge uses. Only `.sorting` and `.labeling` have playable boards in this release;
/// the others render a "coming soon" board.
public enum ChallengeMechanic: String, Codable, Sendable, CaseIterable {
    case sorting        // 1 · drag fruits into baskets, AI CAT learns the rule
    case labeling       // 2 · label animal cards, k-NN accuracy meter
    case scatterBoard   // 3 · place examples on a 2-D board, centroids & decision boundary
    case sequencing     // 4 · instruction blocks guide AI CAT
    case rewardMaze     // 5 · place rewards, watch Q-values
    case neuronDials    // 6 · tune weights of a tiny network
    case cameraVision   // 7 · on-device vision with the camera
    case voiceChat      // 8 · talk to AI CAT (speech + on-device model)
    case fairness       // 9 · repair a biased dataset
    case creativeLab    // 10 · generative project & graduation

    /// Whether this release ships a playable board for the mechanic.
    public var isPlayable: Bool {
        switch self {
        case .sorting, .labeling, .scatterBoard, .sequencing, .rewardMaze, .neuronDials, .fairness, .creativeLab: return true
        default: return false
        }
    }
}

/// Static description of one challenge. Numbers that depend on the child (item count, distractors)
/// are resolved at runtime through `AdaptiveDifficulty`.
public struct ChallengeSpec: Codable, Hashable, Sendable, Identifiable {
    public let id: String                 // "s1.c1" … "s1.c4" (c4 = master challenge)
    public let scenario: ScenarioID
    public let index: Int                 // 1…4
    public let tier: Int                  // 1, 2, 3 (master = 3)
    public let isMaster: Bool
    public let mechanic: ChallengeMechanic
    public let titleKey: TextKey
    public let goalKey: TextKey
    public let conceptKey: TextKey
    public let itemRange: ClosedRange<Int>
    public let params: [String: Int]

    public init(id: String, scenario: ScenarioID, index: Int, tier: Int, isMaster: Bool, mechanic: ChallengeMechanic,
                titleKey: TextKey, goalKey: TextKey, conceptKey: TextKey, itemRange: ClosedRange<Int>, params: [String: Int]) {
        self.id = id
        self.scenario = scenario
        self.index = index
        self.tier = tier
        self.isMaster = isMaster
        self.mechanic = mechanic
        self.titleKey = titleKey
        self.goalKey = goalKey
        self.conceptKey = conceptKey
        self.itemRange = itemRange
        self.params = params
    }

    public func param(_ name: String, default value: Int) -> Int {
        params[name] ?? value
    }
}
