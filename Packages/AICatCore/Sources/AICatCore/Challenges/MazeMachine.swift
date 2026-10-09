import Foundation

// MARK: - Grid world

public struct MazeCell: Hashable, Codable, Sendable, CustomStringConvertible {
    public let x: Int
    public let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public func manhattan(to other: MazeCell) -> Int { abs(x - other.x) + abs(y - other.y) }
    public var description: String { "(\(x),\(y))" }
}

public enum MazeAction: Int, CaseIterable, Codable, Sendable {
    case north = 0, east, south, west

    public var dx: Int { self == .east ? 1 : (self == .west ? -1 : 0) }
    public var dy: Int { self == .north ? 1 : (self == .south ? -1 : 0) }
}

public enum MazeTile: Int, Codable, Sendable, Hashable {
    case free = 0, wall, treat, puddle
}

/// A square grid of tiles. `y` grows northwards; the ASCII layouts list the top row first.
public struct MazeWorld: Hashable, Sendable {
    public let size: Int
    public let start: MazeCell
    public private(set) var tiles: [MazeTile]

    public init(size: Int, start: MazeCell, tiles: [MazeTile]) {
        precondition(tiles.count == size * size, "tiles must be size × size")
        self.size = size
        self.start = start
        self.tiles = tiles
    }

    /// Parses a square ASCII map (top line = highest y): `#` wall, `S` start, `T` treat, `~` puddle, `.` free.
    public static func parse(_ lines: [String]) -> MazeWorld {
        let size = lines.count
        var tiles = Array(repeating: MazeTile.free, count: size * size)
        var start = MazeCell(0, 0)
        for (row, line) in lines.enumerated() {
            let y = size - 1 - row
            for (x, character) in line.enumerated() where x < size {
                switch character {
                case "#": tiles[y * size + x] = .wall
                case "S": start = MazeCell(x, y)
                case "T": tiles[y * size + x] = .treat
                case "~": tiles[y * size + x] = .puddle
                default: break
                }
            }
        }
        return MazeWorld(size: size, start: start, tiles: tiles)
    }

    public func contains(_ cell: MazeCell) -> Bool {
        cell.x >= 0 && cell.y >= 0 && cell.x < size && cell.y < size
    }

    public subscript(cell: MazeCell) -> MazeTile {
        get { tiles[cell.y * size + cell.x] }
        set { tiles[cell.y * size + cell.x] = newValue }
    }

    public var allCells: [MazeCell] {
        (0..<size).flatMap { y in (0..<size).map { x in MazeCell(x, y) } }
    }

    public func cells(of tile: MazeTile) -> [MazeCell] { allCells.filter { self[$0] == tile } }
    public var treat: MazeCell? { cells(of: .treat).first }
    public var puddles: [MazeCell] { cells(of: .puddle) }

    /// Where `action` leads from `cell`; the border and walls bump (the agent stays where it is).
    public func step(from cell: MazeCell, _ action: MazeAction) -> (cell: MazeCell, bumped: Bool) {
        let next = MazeCell(cell.x + action.dx, cell.y + action.dy)
        guard contains(next), self[next] != .wall else { return (cell, true) }
        return (next, false)
    }

    /// Cells reachable from `origin` without crossing walls or puddles. A treat is reached but not crossed.
    public func safeReachable(from origin: MazeCell) -> Set<MazeCell> {
        var seen: Set<MazeCell> = [origin]
        var queue = [origin]
        while !queue.isEmpty {
            let cell = queue.removeFirst()
            if self[cell] == .treat && cell != origin { continue }
            for action in MazeAction.allCases {
                let (next, bumped) = step(from: cell, action)
                if bumped || seen.contains(next) || self[next] == .puddle { continue }
                seen.insert(next)
                queue.append(next)
            }
        }
        return seen
    }

    public var isTreatReachable: Bool {
        guard let treat else { return false }
        return safeReachable(from: start).contains(treat)
    }
}

// MARK: - Q-table

/// Action values Q(s, a) for every cell and the four moves.
public struct QTable: Hashable, Sendable {
    public let size: Int
    public private(set) var values: [Double]

    public init(size: Int) {
        self.size = size
        values = Array(repeating: 0, count: size * size * MazeAction.allCases.count)
    }

    private func index(_ cell: MazeCell, _ action: MazeAction) -> Int {
        (cell.y * size + cell.x) * MazeAction.allCases.count + action.rawValue
    }

    public subscript(cell: MazeCell, action: MazeAction) -> Double {
        get { values[index(cell, action)] }
        set { values[index(cell, action)] = newValue }
    }

    public func actionValues(at cell: MazeCell) -> [Double] { MazeAction.allCases.map { self[cell, $0] } }

    /// argmax over the actions; ties go to the first action in N, E, S, W order.
    public func bestAction(at cell: MazeCell) -> MazeAction {
        var best = MazeAction.north
        var bestValue = -Double.infinity
        for action in MazeAction.allCases {
            let value = self[cell, action]
            if value > bestValue {
                bestValue = value
                best = action
            }
        }
        return best
    }

    /// V(s) = max_a Q(s, a): the "warmth" shown on a tile.
    public func value(at cell: MazeCell) -> Double { actionValues(at: cell).max() ?? 0 }
}

// MARK: - Episodes and the learner

public struct MazeStep: Hashable, Sendable {
    public let from: MazeCell
    public let action: MazeAction
    public let to: MazeCell
    public let reward: Double
    public let isTerminal: Bool

    public var bumped: Bool { from == to }
}

public enum MazeOutcome: Hashable, Sendable {
    case treat, puddle, wandered
}

public struct MazeEpisode: Hashable, Sendable {
    public let steps: [MazeStep]
    public let outcome: MazeOutcome

    /// Cells visited, starting with the start cell.
    public var path: [MazeCell] {
        guard let first = steps.first else { return [] }
        return [first.from] + steps.map(\.to)
    }

    public var totalReward: Double { steps.reduce(0) { $0 + $1.reward } }
}

public struct MazeRewards: Hashable, Sendable {
    public var step: Double = -0.04
    public var bump: Double = -0.10
    public var treat: Double = 1.0
    public var puddle: Double = -1.0

    public init() {}
    public static let standard = MazeRewards()
}

/// Tabular Q-learning: Q(s,a) ← Q(s,a) + α · (r + γ · max_a' Q(s',a') − Q(s,a)), ε-greedy exploration.
public struct MazeLearner: Hashable, Sendable {
    public var alpha: Double = 0.5
    public var gamma: Double = 0.9
    public var epsilon: Double
    public var maxSteps: Int = 60
    public var rewards = MazeRewards.standard
    public private(set) var q: QTable
    public private(set) var episodesRun = 0

    public init(size: Int, epsilon: Double) {
        q = QTable(size: size)
        self.epsilon = epsilon
    }

    /// Forgets everything (the map changed, so the old values are no longer true).
    public mutating func reset() {
        q = QTable(size: q.size)
        episodesRun = 0
    }

    func reward(for tile: MazeTile, bumped: Bool) -> (reward: Double, terminal: Bool) {
        if bumped { return (rewards.bump, false) }
        switch tile {
        case .treat: return (rewards.treat, true)
        case .puddle: return (rewards.puddle, true)
        case .free, .wall: return (rewards.step, false)
        }
    }

    /// One learning episode from the start: explore with probability ε, otherwise follow the best known action.
    public mutating func runEpisode(in world: MazeWorld, using rng: inout SeededGenerator) -> MazeEpisode {
        var cell = world.start
        var steps: [MazeStep] = []
        var outcome = MazeOutcome.wandered
        for _ in 0..<maxSteps {
            let action: MazeAction
            if rng.nextUnit() < epsilon {
                action = MazeAction(rawValue: min(3, Int(rng.nextUnit() * 4))) ?? .north
            } else {
                action = q.bestAction(at: cell)
            }
            let (next, bumped) = world.step(from: cell, action)
            let (reward, terminal) = reward(for: world[next], bumped: bumped)
            let target = terminal ? reward : reward + gamma * q.value(at: next)
            q[cell, action] += alpha * (target - q[cell, action])
            steps.append(MazeStep(from: cell, action: action, to: next, reward: reward, isTerminal: terminal))
            cell = next
            if terminal {
                outcome = world[next] == .treat ? .treat : .puddle
                break
            }
        }
        episodesRun += 1
        return MazeEpisode(steps: steps, outcome: outcome)
    }

    /// Follows the best known action from the start without learning. Stops on a bump or a revisit
    /// (the policy is not ready yet) so the replay never loops.
    public func greedyEpisode(in world: MazeWorld, maxSteps: Int = 100) -> MazeEpisode {
        var cell = world.start
        var steps: [MazeStep] = []
        var visited: Set<MazeCell> = [cell]
        for _ in 0..<maxSteps {
            let action = q.bestAction(at: cell)
            let (next, bumped) = world.step(from: cell, action)
            let (reward, terminal) = reward(for: world[next], bumped: bumped)
            steps.append(MazeStep(from: cell, action: action, to: next, reward: reward, isTerminal: terminal))
            cell = next
            if terminal {
                return MazeEpisode(steps: steps, outcome: world[next] == .treat ? .treat : .puddle)
            }
            if bumped || !visited.insert(next).inserted { break }
        }
        return MazeEpisode(steps: steps, outcome: .wandered)
    }
}

// MARK: - Challenge

public struct MazeBatch: Hashable, Sendable {
    public let episodes: [MazeEpisode]
    public let greedy: MazeEpisode
    public let solved: Bool

    public func count(_ outcome: MazeOutcome) -> Int { episodes.filter { $0.outcome == outcome }.count }
}

public struct MazeChallenge: Sendable {
    public enum PlacementResult: Hashable, Sendable {
        case placed, removed, blocked, budgetExhausted, tooClose
    }

    public let spec: ChallengeSpec
    public let initialWorld: MazeWorld
    public private(set) var world: MazeWorld
    public let treatBudget: Int
    public let puddleBudget: Int
    public let minTreatDistance: Int
    public let requiresDetour: Bool
    public let episodesPerBatch: Int
    public let epsilonOptions: [Double]
    public private(set) var learner: MazeLearner
    public private(set) var batches = 0
    public private(set) var hintsUsed = 0
    public private(set) var lastBatch: MazeBatch?
    public private(set) var isSolved = false

    public init(spec: ChallengeSpec, world: MazeWorld, treatBudget: Int, puddleBudget: Int, minTreatDistance: Int,
                requiresDetour: Bool, episodesPerBatch: Int, epsilonOptions: [Double]) {
        self.spec = spec
        self.initialWorld = world
        self.world = world
        self.treatBudget = treatBudget
        self.puddleBudget = puddleBudget
        self.minTreatDistance = minTreatDistance
        self.requiresDetour = requiresDetour
        self.episodesPerBatch = episodesPerBatch
        self.epsilonOptions = epsilonOptions
        learner = MazeLearner(size: world.size, epsilon: epsilonOptions.count > 1 ? epsilonOptions[1] : (epsilonOptions.first ?? 0.3))
    }

    public var placedTreats: Int { world.cells(of: .treat).count - initialWorld.cells(of: .treat).count }
    public var placedPuddles: Int { world.puddles.count - initialWorld.puddles.count }
    public var treatsLeft: Int { treatBudget - placedTreats }
    public var puddlesLeft: Int { puddleBudget - placedPuddles }
    public var hasTreat: Bool { world.treat != nil }
    public var canExplore: Bool { !isSolved && world.isTreatReachable }
    public var epsilon: Double { learner.epsilon }

    /// Whether the child placed the tile at `cell` (the level's own tiles cannot be removed).
    public func isPlacedByChild(_ cell: MazeCell) -> Bool {
        world.contains(cell) && initialWorld[cell] == .free && world[cell] != .free
    }

    /// Taps a cell with a tool: places the tile, or removes the child's own tile already there.
    /// Any change to the map resets what AI CAT learned, because the old values are no longer true.
    @discardableResult
    public mutating func tap(_ cell: MazeCell, tool: MazeTile) -> PlacementResult {
        guard !isSolved, world.contains(cell), cell != world.start, initialWorld[cell] == .free else { return .blocked }
        if world[cell] != .free {
            world[cell] = .free
            forget()
            return .removed
        }
        switch tool {
        case .treat:
            guard treatsLeft > 0 else { return .budgetExhausted }
            guard cell.manhattan(to: world.start) >= minTreatDistance else { return .tooClose }
        case .puddle:
            guard puddlesLeft > 0 else { return .budgetExhausted }
        case .free, .wall:
            return .blocked
        }
        world[cell] = tool
        forget()
        return .placed
    }

    private mutating func forget() {
        learner.reset()
        lastBatch = nil
    }

    public mutating func setEpsilon(_ epsilon: Double) {
        learner.epsilon = max(0, min(1, epsilon))
    }

    /// One batch of exploration episodes followed by a greedy test run. Counts towards the score.
    public mutating func explore(using rng: inout SeededGenerator) -> MazeBatch? {
        guard canExplore else { return nil }
        batches += 1
        return runBatch(using: &rng)
    }

    /// A hint is a free batch: AI CAT explores a little more without it counting against the score.
    public mutating func hint(using rng: inout SeededGenerator) -> MazeBatch? {
        guard canExplore else { return nil }
        hintsUsed += 1
        return runBatch(using: &rng)
    }

    private mutating func runBatch(using rng: inout SeededGenerator) -> MazeBatch {
        var episodes: [MazeEpisode] = []
        for _ in 0..<episodesPerBatch {
            episodes.append(learner.runEpisode(in: world, using: &rng))
        }
        let greedy = learner.greedyEpisode(in: world)
        let solved = Self.isSuccess(greedy, in: world, requiresDetour: requiresDetour)
        let batch = MazeBatch(episodes: episodes, greedy: greedy, solved: solved)
        lastBatch = batch
        if solved { isSolved = true }
        return batch
    }

    /// Success: the greedy path reaches the treat; the master level also demands a real detour
    /// (longer than the straight-line distance), i.e. the child made the short way unsafe.
    static func isSuccess(_ greedy: MazeEpisode, in world: MazeWorld, requiresDetour: Bool) -> Bool {
        guard greedy.outcome == .treat, let treat = world.treat else { return false }
        return !requiresDetour || greedy.steps.count > world.start.manhattan(to: treat)
    }

    /// Solved within three batches = 1; each extra batch costs 0.06, never below 0.6. Unsolved = 0.
    public var scoreAccuracy: Double {
        guard isSolved else { return 0 }
        return max(0.6, 1 - 0.06 * Double(max(0, batches - 3)))
    }
}

// MARK: - Content

public enum MazeContent {
    /// Hand-authored layouts, two per level, chosen by `seed % 2`. Levels 1 and 3 let the child place the treat.
    static let layouts: [Int: [[String]]] = [
        1: [
            ["....",
             ".#..",
             ".#..",
             "S..."],
            ["..#.",
             "....",
             ".##.",
             "S..."],
        ],
        2: [
            ["....T",
             ".##..",
             ".....",
             ".###.",
             "S...."],
            ["..#.T",
             "..#..",
             "..#..",
             ".....",
             "S#..."],
        ],
        3: [
            ["...#..",
             ".#.#..",
             ".#...#",
             ".###..",
             "...#..",
             "S#...."],
            ["..#...",
             "..#.#.",
             ".##.#.",
             "....#.",
             "###...",
             "S....."],
        ],
        4: [
            [".......",
             ".......",
             "...#...",
             "...#...",
             "...#...",
             "...#...",
             "S.....T"],
            ["T......",
             ".......",
             ".......",
             ".####..",
             ".......",
             ".......",
             "S......"],
        ],
    ]

    public static func layout(level: Int, variant: Int) -> MazeWorld {
        let variants = layouts[max(1, min(4, level))] ?? layouts[1]!
        return MazeWorld.parse(variants[((variant % variants.count) + variants.count) % variants.count])
    }

    /// params: "grid" (informative), "penalties" (puddles the child may place), "episodes" (1 = master rules).
    public static func make(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> MazeChallenge {
        let level = max(1, min(4, spec.index))
        let world = layout(level: level, variant: Int(seed % 2))
        let penalties = spec.param("penalties", default: 0)
        let items = difficulty.itemCount(in: spec.itemRange)
        let extraEpisodes = level >= 3 ? 4 : (level == 2 ? 2 : 0)
        let master = spec.param("episodes", default: 0) == 1
        return MazeChallenge(spec: spec, world: world,
                             treatBudget: world.treat == nil ? 1 : 0,
                             puddleBudget: penalties,
                             minTreatDistance: level == 1 ? 2 : 4,
                             requiresDetour: master,
                             episodesPerBatch: items + extraEpisodes,
                             epsilonOptions: master ? [0.05, 0.3, 0.8] : [0.3])
    }
}
