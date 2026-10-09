import Foundation

/// The ten worlds, in curriculum order.
public enum ScenarioID: Int, Codable, CaseIterable, Comparable, Sendable, Identifiable {
    case patternGarden = 1
    case dataLibrary = 2
    case classifierWorkshop = 3
    case algorithmTrail = 4
    case rewardMaze = 5
    case neuronFactory = 6
    case catEyes = 7
    case catVoice = 8
    case fairScale = 9
    case creativeLab = 10

    public var id: Int { rawValue }

    public static func < (lhs: ScenarioID, rhs: ScenarioID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var next: ScenarioID? { ScenarioID(rawValue: rawValue + 1) }
    public var previous: ScenarioID? { ScenarioID(rawValue: rawValue - 1) }

    /// Stable string used in challenge identifiers and localization keys ("s1" … "s10").
    public var code: String { "s\(rawValue)" }
}
