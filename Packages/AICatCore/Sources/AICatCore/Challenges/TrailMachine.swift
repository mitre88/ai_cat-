import Foundation

// MARK: - World

public enum TrailDirection: Int, Codable, Sendable, CaseIterable, Equatable {
    case north = 0, east, south, west

    public var turnedLeft: TrailDirection { TrailDirection(rawValue: (rawValue + 3) % 4) ?? .north }
    public var turnedRight: TrailDirection { TrailDirection(rawValue: (rawValue + 1) % 4) ?? .north }

    /// Grid delta: x grows to the east, y grows to the north.
    public var delta: (dx: Int, dy: Int) {
        switch self {
        case .north: return (0, 1)
        case .east: return (1, 0)
        case .south: return (0, -1)
        case .west: return (-1, 0)
        }
    }
}

public struct TrailCell: Hashable, Codable, Sendable {
    public var x: Int
    public var y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    public func moved(_ direction: TrailDirection, steps: Int = 1) -> TrailCell {
        TrailCell(x + direction.delta.dx * steps, y + direction.delta.dy * steps)
    }
}

public struct TrailWorld: Hashable, Codable, Sendable {
    public let width: Int
    public let height: Int
    public let start: TrailCell
    public let startDirection: TrailDirection
    public let goal: TrailCell
    public let puddles: Set<TrailCell>

    public init(width: Int, height: Int, start: TrailCell, startDirection: TrailDirection, goal: TrailCell, puddles: Set<TrailCell>) {
        self.width = width
        self.height = height
        self.start = start
        self.startDirection = startDirection
        self.goal = goal
        self.puddles = puddles
    }

    public func contains(_ cell: TrailCell) -> Bool {
        cell.x >= 0 && cell.y >= 0 && cell.x < width && cell.y < height
    }

    public func isPuddle(_ cell: TrailCell) -> Bool { puddles.contains(cell) }
}

// MARK: - Program

public enum TrailBlockKind: String, Codable, Sendable, CaseIterable {
    case forward, turnLeft, turnRight, jump, ifPuddleAhead, repeatTimes
}

/// Blocks the child snaps together. Control blocks have fixed bodies to stay readable for children:
/// "if there is a puddle ahead → jump", "repeat n times → forward".
public enum TrailBlock: Hashable, Codable, Sendable {
    case forward
    case turnLeft
    case turnRight
    case jump
    case ifPuddleAhead
    case repeatForward(Int)

    public var kind: TrailBlockKind {
        switch self {
        case .forward: return .forward
        case .turnLeft: return .turnLeft
        case .turnRight: return .turnRight
        case .jump: return .jump
        case .ifPuddleAhead: return .ifPuddleAhead
        case .repeatForward: return .repeatTimes
        }
    }

    /// Blocks "spent" from the budget: control blocks cost two (the block and its body).
    public var cost: Int {
        switch self {
        case .ifPuddleAhead, .repeatForward: return 2
        default: return 1
        }
    }
}

// MARK: - Interpreter

public enum TrailEvent: Equatable, Sendable {
    case moved(to: TrailCell)
    case turned(TrailDirection)
    case jumped(over: TrailCell, to: TrailCell)
    case bumped(at: TrailCell)
    case splashed(at: TrailCell)
    case reachedGoal(at: TrailCell)
    case stepLimit
}

public enum TrailOutcome: Equatable, Sendable {
    case goal, splash, lost, tooLong
}

public struct TrailRun: Equatable, Sendable {
    public var events: [TrailEvent]
    public var finalCell: TrailCell
    public var finalDirection: TrailDirection
    public var outcome: TrailOutcome
}

public enum TrailInterpreter {
    public static let maxSteps = 60

    public static func run(_ program: [TrailBlock], in world: TrailWorld) -> TrailRun {
        var cell = world.start
        var direction = world.startDirection
        var events: [TrailEvent] = []
        var steps = 0

        func finish(_ outcome: TrailOutcome) -> TrailRun {
            TrailRun(events: events, finalCell: cell, finalDirection: direction, outcome: outcome)
        }

        /// Executes one primitive; returns an outcome when the run must stop.
        func step(_ primitive: TrailBlock) -> TrailOutcome? {
            steps += 1
            if steps > maxSteps {
                events.append(.stepLimit)
                return .tooLong
            }
            switch primitive {
            case .turnLeft:
                direction = direction.turnedLeft
                events.append(.turned(direction))
            case .turnRight:
                direction = direction.turnedRight
                events.append(.turned(direction))
            case .forward:
                let next = cell.moved(direction)
                guard world.contains(next) else {
                    events.append(.bumped(at: cell))
                    return nil
                }
                cell = next
                if world.isPuddle(next) {
                    events.append(.splashed(at: next))
                    return .splash
                }
                events.append(.moved(to: next))
                if next == world.goal {
                    events.append(.reachedGoal(at: next))
                    return .goal
                }
            case .jump:
                let over = cell.moved(direction)
                let landing = cell.moved(direction, steps: 2)
                guard world.contains(landing) else {
                    events.append(.bumped(at: cell))
                    return nil
                }
                cell = landing
                if world.isPuddle(landing) {
                    events.append(.jumped(over: over, to: landing))
                    events.append(.splashed(at: landing))
                    return .splash
                }
                events.append(.jumped(over: over, to: landing))
                if landing == world.goal {
                    events.append(.reachedGoal(at: landing))
                    return .goal
                }
            case .ifPuddleAhead, .repeatForward:
                break
            }
            return nil
        }

        for block in program {
            switch block {
            case .ifPuddleAhead:
                if world.isPuddle(cell.moved(direction)) {
                    if let outcome = step(.jump) { return finish(outcome) }
                }
            case .repeatForward(let times):
                for _ in 0..<max(1, min(times, 9)) {
                    if let outcome = step(.forward) { return finish(outcome) }
                }
            default:
                if let outcome = step(block) { return finish(outcome) }
            }
        }
        return finish(cell == world.goal ? .goal : .lost)
    }

    public static func cost(of program: [TrailBlock]) -> Int {
        program.reduce(0) { $0 + $1.cost }
    }
}

// MARK: - Challenge state

public struct TrailChallenge: Codable, Sendable {
    public let spec: ChallengeSpec
    public let world: TrailWorld
    public let palette: [TrailBlockKind]
    public let maxCost: Int
    public let solution: [TrailBlock]

    public private(set) var program: [TrailBlock] = []
    public private(set) var runs = 0
    public private(set) var hintsUsed = 0
    public private(set) var isSolved = false

    public init(spec: ChallengeSpec, world: TrailWorld, palette: [TrailBlockKind], maxCost: Int, solution: [TrailBlock]) {
        self.spec = spec
        self.world = world
        self.palette = palette
        self.maxCost = maxCost
        self.solution = solution
    }

    public var cost: Int { TrailInterpreter.cost(of: program) }
    public var remainingBudget: Int { maxCost - cost }

    @discardableResult
    public mutating func append(_ block: TrailBlock) -> Bool {
        guard !isSolved, palette.contains(block.kind), cost + block.cost <= maxCost else { return false }
        program.append(block)
        return true
    }

    public mutating func removeLast() {
        guard !isSolved, !program.isEmpty else { return }
        program.removeLast()
    }

    public mutating func clear() {
        guard !isSolved else { return }
        program.removeAll()
    }

    /// Execute the program. Returns the run; marks the challenge solved on reaching the goal.
    public mutating func run() -> TrailRun {
        runs += 1
        let result = TrailInterpreter.run(program, in: world)
        if result.outcome == .goal { isSolved = true }
        return result
    }

    /// The next block of the known solution that the program does not have yet (nil when the prefix diverged).
    public mutating func hint() -> TrailBlock? {
        hintsUsed += 1
        guard program.count < solution.count else { return nil }
        for (index, block) in program.enumerated() where solution[index] != block {
            return nil
        }
        return solution[program.count]
    }

    /// Solved on the first run = 1.0; each extra run costs 0.15, never below 0.6 (the pass mark). Unsolved = 0.
    public var scoreAccuracy: Double {
        guard isSolved else { return 0 }
        return max(0.6, 1 - 0.15 * Double(max(runs - 1, 0)))
    }
}

public enum TrailContent {
    /// Hand-authored layouts (two variants per level, chosen by the seed). Every layout ships its solution.
    public static func make(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> TrailChallenge {
        let variant = Int(seed % 2)
        switch spec.index {
        case 1:
            if variant == 0 {
                let world = TrailWorld(width: 5, height: 3, start: TrailCell(0, 1), startDirection: .east, goal: TrailCell(3, 1), puddles: [])
                return TrailChallenge(spec: spec, world: world, palette: [.forward, .turnLeft, .turnRight], maxCost: 6, solution: [.forward, .forward, .forward])
            }
            let world = TrailWorld(width: 5, height: 3, start: TrailCell(0, 0), startDirection: .east, goal: TrailCell(2, 2), puddles: [])
            return TrailChallenge(spec: spec, world: world, palette: [.forward, .turnLeft, .turnRight], maxCost: 6, solution: [.forward, .forward, .turnLeft, .forward, .forward])
        case 2:
            if variant == 0 {
                let world = TrailWorld(width: 5, height: 3, start: TrailCell(0, 1), startDirection: .east, goal: TrailCell(4, 1), puddles: [TrailCell(2, 1)])
                return TrailChallenge(spec: spec, world: world, palette: [.forward, .turnLeft, .turnRight, .jump, .ifPuddleAhead], maxCost: 7, solution: [.forward, .ifPuddleAhead, .forward])
            }
            let world = TrailWorld(width: 5, height: 3, start: TrailCell(0, 0), startDirection: .east, goal: TrailCell(3, 2), puddles: [TrailCell(3, 1)])
            return TrailChallenge(spec: spec, world: world, palette: [.forward, .turnLeft, .turnRight, .jump, .ifPuddleAhead], maxCost: 8, solution: [.forward, .forward, .forward, .turnLeft, .ifPuddleAhead])
        case 3:
            if variant == 0 {
                let world = TrailWorld(width: 6, height: 3, start: TrailCell(0, 1), startDirection: .east, goal: TrailCell(5, 1), puddles: [])
                return TrailChallenge(spec: spec, world: world, palette: [.forward, .turnLeft, .turnRight, .repeatTimes], maxCost: 3, solution: [.repeatForward(5)])
            }
            let world = TrailWorld(width: 5, height: 5, start: TrailCell(0, 0), startDirection: .east, goal: TrailCell(4, 4), puddles: [])
            return TrailChallenge(spec: spec, world: world, palette: [.forward, .turnLeft, .turnRight, .repeatTimes], maxCost: 6, solution: [.repeatForward(4), .turnLeft, .repeatForward(4)])
        default:
            if variant == 0 {
                let world = TrailWorld(width: 6, height: 4, start: TrailCell(0, 0), startDirection: .east, goal: TrailCell(5, 2), puddles: [TrailCell(2, 0), TrailCell(4, 1)])
                return TrailChallenge(spec: spec, world: world, palette: TrailBlockKind.allCases, maxCost: 10, solution: [.forward, .ifPuddleAhead, .forward, .forward, .turnLeft, .repeatForward(2)])
            }
            let world = TrailWorld(width: 6, height: 4, start: TrailCell(0, 3), startDirection: .east, goal: TrailCell(5, 0), puddles: [TrailCell(1, 3), TrailCell(5, 2)])
            return TrailChallenge(spec: spec, world: world, palette: TrailBlockKind.allCases, maxCost: 10, solution: [.ifPuddleAhead, .repeatForward(3), .turnRight, .ifPuddleAhead, .forward])
        }
    }
}
