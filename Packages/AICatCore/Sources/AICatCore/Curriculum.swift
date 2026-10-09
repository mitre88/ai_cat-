import Foundation

/// The whole curriculum as compiler-checked literals (no JSON to fail at runtime).
/// Localization keys follow fixed patterns that `Tools/validate_project.py` enumerates:
///   scenario.<n>.{title,subtitle,concept,intro}   and   challenge.s<n>.c<k>.{title,goal,concept}
public enum Curriculum {
    public static let scenarios: [Scenario] = [
        make(.patternGarden, bigIdea: .perception, theme: .garden, reward: .collar, challenges: [
            challenge(.patternGarden, 1, tier: 1, mechanic: .sorting, items: 4...8, params: ["attributes": 1, "rule": 0]),
            challenge(.patternGarden, 2, tier: 2, mechanic: .sorting, items: 6...10, params: ["attributes": 2, "rule": 1]),
            challenge(.patternGarden, 3, tier: 3, mechanic: .sorting, items: 6...10, params: ["attributes": 2, "rule": 2]),
            challenge(.patternGarden, 4, tier: 3, mechanic: .sorting, items: 8...12, params: ["attributes": 3, "rule": 3]),
        ]),
        make(.dataLibrary, bigIdea: .learning, theme: .library, reward: .bandana, challenges: [
            challenge(.dataLibrary, 1, tier: 1, mechanic: .labeling, items: 4...8, params: ["species": 2, "traps": 0]),
            challenge(.dataLibrary, 2, tier: 2, mechanic: .labeling, items: 6...9, params: ["species": 3, "traps": 0]),
            challenge(.dataLibrary, 3, tier: 3, mechanic: .labeling, items: 6...10, params: ["species": 3, "traps": 1]),
            challenge(.dataLibrary, 4, tier: 3, mechanic: .labeling, items: 9...12, params: ["species": 3, "traps": 2, "noise": 1]),
        ]),
        make(.classifierWorkshop, bigIdea: .learning, theme: .workshop, reward: .glasses, challenges: [
            challenge(.classifierWorkshop, 1, tier: 1, mechanic: .scatterBoard, items: 4...8, params: ["classes": 2]),
            challenge(.classifierWorkshop, 2, tier: 2, mechanic: .scatterBoard, items: 6...10, params: ["classes": 2, "boundary": 1]),
            challenge(.classifierWorkshop, 3, tier: 3, mechanic: .scatterBoard, items: 8...12, params: ["classes": 3]),
            challenge(.classifierWorkshop, 4, tier: 3, mechanic: .scatterBoard, items: 10...14, params: ["classes": 3, "outliers": 2]),
        ]),
        make(.algorithmTrail, bigIdea: .representation, theme: .trail, reward: .backpack, challenges: [
            challenge(.algorithmTrail, 1, tier: 1, mechanic: .sequencing, items: 3...5, params: ["blocks": 3]),
            challenge(.algorithmTrail, 2, tier: 2, mechanic: .sequencing, items: 4...7, params: ["blocks": 4, "conditionals": 1]),
            challenge(.algorithmTrail, 3, tier: 3, mechanic: .sequencing, items: 5...8, params: ["blocks": 5, "loops": 1]),
            challenge(.algorithmTrail, 4, tier: 3, mechanic: .sequencing, items: 6...10, params: ["blocks": 6, "conditionals": 1, "loops": 1]),
        ]),
        make(.rewardMaze, bigIdea: .learning, theme: .maze, reward: .compass, challenges: [
            challenge(.rewardMaze, 1, tier: 1, mechanic: .rewardMaze, items: 3...5, params: ["grid": 4]),
            challenge(.rewardMaze, 2, tier: 2, mechanic: .rewardMaze, items: 4...6, params: ["grid": 5, "penalties": 1]),
            challenge(.rewardMaze, 3, tier: 3, mechanic: .rewardMaze, items: 5...7, params: ["grid": 6, "penalties": 2]),
            challenge(.rewardMaze, 4, tier: 3, mechanic: .rewardMaze, items: 6...8, params: ["grid": 7, "penalties": 3, "episodes": 1]),
        ]),
        make(.neuronFactory, bigIdea: .learning, theme: .factory, reward: .headband, challenges: [
            challenge(.neuronFactory, 1, tier: 1, mechanic: .neuronDials, items: 2...3, params: ["inputs": 2, "layers": 1]),
            challenge(.neuronFactory, 2, tier: 2, mechanic: .neuronDials, items: 3...4, params: ["inputs": 3, "layers": 1]),
            challenge(.neuronFactory, 3, tier: 3, mechanic: .neuronDials, items: 3...5, params: ["inputs": 3, "layers": 2]),
            challenge(.neuronFactory, 4, tier: 3, mechanic: .neuronDials, items: 4...6, params: ["inputs": 4, "layers": 2, "autoTrain": 1]),
        ]),
        make(.catEyes, bigIdea: .perception, theme: .lookout, reward: .goggles, challenges: [
            challenge(.catEyes, 1, tier: 1, mechanic: .cameraVision, items: 3...5, params: ["pixels": 1]),
            challenge(.catEyes, 2, tier: 2, mechanic: .cameraVision, items: 4...6, params: ["edges": 1]),
            challenge(.catEyes, 3, tier: 3, mechanic: .cameraVision, items: 5...8, params: ["objects": 1]),
            challenge(.catEyes, 4, tier: 3, mechanic: .cameraVision, items: 6...10, params: ["objects": 1, "live": 1]),
        ]),
        make(.catVoice, bigIdea: .naturalInteraction, theme: .theater, reward: .headphones, challenges: [
            challenge(.catVoice, 1, tier: 1, mechanic: .voiceChat, items: 3...5, params: ["tokens": 1]),
            challenge(.catVoice, 2, tier: 2, mechanic: .voiceChat, items: 4...6, params: ["nextWord": 1]),
            challenge(.catVoice, 3, tier: 3, mechanic: .voiceChat, items: 5...8, params: ["speech": 1]),
            challenge(.catVoice, 4, tier: 3, mechanic: .voiceChat, items: 6...10, params: ["speech": 1, "model": 1]),
        ]),
        make(.fairScale, bigIdea: .societalImpact, theme: .plaza, reward: .badge, challenges: [
            challenge(.fairScale, 1, tier: 1, mechanic: .fairness, items: 6...8, params: ["bias": 1]),
            challenge(.fairScale, 2, tier: 2, mechanic: .fairness, items: 8...10, params: ["bias": 1, "fix": 1]),
            challenge(.fairScale, 3, tier: 3, mechanic: .fairness, items: 8...12, params: ["privacy": 1]),
            challenge(.fairScale, 4, tier: 3, mechanic: .fairness, items: 10...14, params: ["bias": 1, "privacy": 1, "mistakes": 1]),
        ]),
        make(.creativeLab, bigIdea: .naturalInteraction, theme: .lab, reward: .graduationCap, challenges: [
            challenge(.creativeLab, 1, tier: 1, mechanic: .creativeLab, items: 3...5, params: ["story": 1]),
            challenge(.creativeLab, 2, tier: 2, mechanic: .creativeLab, items: 4...6, params: ["remix": 1]),
            challenge(.creativeLab, 3, tier: 3, mechanic: .creativeLab, items: 5...8, params: ["design": 1]),
            challenge(.creativeLab, 4, tier: 3, mechanic: .creativeLab, items: 6...10, params: ["project": 1, "graduation": 1]),
        ]),
    ]

    public static func scenario(_ id: ScenarioID) -> Scenario {
        scenarios[id.rawValue - 1]
    }

    public static func challenge(id: String) -> ChallengeSpec? {
        for scenario in scenarios {
            if let spec = scenario.challenges.first(where: { $0.id == id }) { return spec }
        }
        return nil
    }

    /// Scenarios in order with their playability (for the map).
    public static var playableScenarioIDs: [ScenarioID] { scenarios.filter { $0.isPlayable }.map { $0.id } }

    // MARK: - Builders (keys follow the patterns checked by the validator)

    private static func make(_ id: ScenarioID, bigIdea: BigIdea, theme: WorldTheme, reward: KnowledgeItem, challenges: [ChallengeSpec]) -> Scenario {
        let n = id.rawValue
        return Scenario(
            id: id,
            titleKey: TextKey("scenario.\(n).title"),
            subtitleKey: TextKey("scenario.\(n).subtitle"),
            conceptKey: TextKey("scenario.\(n).concept"),
            introKey: TextKey("scenario.\(n).intro"),
            bigIdea: bigIdea,
            theme: theme,
            challenges: challenges,
            knowledgeReward: reward
        )
    }

    private static func challenge(_ scenario: ScenarioID, _ index: Int, tier: Int, mechanic: ChallengeMechanic,
                                  items: ClosedRange<Int>, params: [String: Int]) -> ChallengeSpec {
        let code = "\(scenario.code).c\(index)"
        return ChallengeSpec(
            id: code,
            scenario: scenario,
            index: index,
            tier: tier,
            isMaster: index == 4,
            mechanic: mechanic,
            titleKey: TextKey("challenge.\(code).title"),
            goalKey: TextKey("challenge.\(code).goal"),
            conceptKey: TextKey("challenge.\(code).concept"),
            itemRange: items,
            params: params
        )
    }
}
