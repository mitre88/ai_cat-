import Foundation

// MARK: - Points & models

/// An animal on the 2-D board: two features in [0, 1] (size, fluffiness) and its true class.
public struct ScatterPoint: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let x: Double
    public let y: Double
    public let label: Int
    public let isOutlier: Bool
    public let variant: Int

    public init(id: String, x: Double, y: Double, label: Int, isOutlier: Bool = false, variant: Int = 0) {
        self.id = id
        self.x = GrowthModel.clamp(x, 0, 1)
        self.y = GrowthModel.clamp(y, 0, 1)
        self.label = label
        self.isOutlier = isOutlier
        self.variant = variant
    }
}

public struct ScatterCentroid: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public var label: Int

    public init(x: Double, y: Double, label: Int) {
        self.x = x
        self.y = y
        self.label = label
    }
}

/// The classifier the child shapes by hand.
public enum ScatterModel: Hashable, Codable, Sendable {
    /// Vertical boundary on the size axis: left = class 0, right = class 1 (polarity chosen by the data).
    case threshold(x: Double)
    /// Straight boundary through two handle points; the side of each class is chosen by the data.
    case line(x1: Double, y1: Double, x2: Double, y2: Double)
    /// Nearest centroid.
    case centroids([ScatterCentroid])

    public var kindName: String {
        switch self {
        case .threshold: return "threshold"
        case .line: return "line"
        case .centroids: return "centroids"
        }
    }
}

public enum ScatterLearner {
    /// Signed side of the line for a point (positive on one side, negative on the other).
    public static func side(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) -> Double {
        (x2 - x1) * (y - y1) - (y2 - y1) * (x - x1)
    }

    /// Which class lives on the "positive" side of a two-class boundary, decided by majority over the points.
    /// Returns (classForPositive, classForNegative).
    public static func polarity(_ model: ScatterModel, points: [ScatterPoint]) -> (positive: Int, negative: Int) {
        var positiveCounts = [0, 0]
        var negativeCounts = [0, 0]
        for p in points where p.label < 2 {
            if rawSide(model, x: p.x, y: p.y) >= 0 {
                positiveCounts[p.label] += 1
            } else {
                negativeCounts[p.label] += 1
            }
        }
        // Option A: positive side = class 1. Option B: positive side = class 0.
        let scoreA = positiveCounts[1] + negativeCounts[0]
        let scoreB = positiveCounts[0] + negativeCounts[1]
        return scoreA >= scoreB ? (1, 0) : (0, 1)
    }

    private static func rawSide(_ model: ScatterModel, x: Double, y: Double) -> Double {
        switch model {
        case .threshold(let t): return x - t
        case .line(let x1, let y1, let x2, let y2): return side(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y)
        case .centroids: return 0
        }
    }

    public static func predict(_ model: ScatterModel, x: Double, y: Double, points: [ScatterPoint]) -> Int {
        switch model {
        case .threshold, .line:
            let polarity = polarity(model, points: points)
            return rawSide(model, x: x, y: y) >= 0 ? polarity.positive : polarity.negative
        case .centroids(let centroids):
            guard !centroids.isEmpty else { return 0 }
            var best = centroids[0]
            var bestDistance = Double.greatestFiniteMagnitude
            for c in centroids {
                let d = (c.x - x) * (c.x - x) + (c.y - y) * (c.y - y)
                if d < bestDistance {
                    bestDistance = d
                    best = c
                }
            }
            return best.label
        }
    }

    public static func accuracy(_ model: ScatterModel, points: [ScatterPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        var correct = 0
        for p in points where predict(model, x: p.x, y: p.y, points: points) == p.label { correct += 1 }
        return Double(correct) / Double(points.count)
    }

    /// Mean of each class (the "ideal" centroids AI CAT would compute).
    public static func centroids(of points: [ScatterPoint], classes: Int) -> [ScatterCentroid] {
        (0..<classes).map { label in
            let members = points.filter { $0.label == label }
            guard !members.isEmpty else { return ScatterCentroid(x: 0.5, y: 0.5, label: label) }
            let sx = members.reduce(0.0) { $0 + $1.x }
            let sy = members.reduce(0.0) { $0 + $1.y }
            return ScatterCentroid(x: sx / Double(members.count), y: sy / Double(members.count), label: label)
        }
    }
}

// MARK: - Challenge state

/// Pure state of one Classifier Workshop challenge.
public struct ScatterChallenge: Codable, Sendable {
    public let spec: ChallengeSpec
    public let classes: Int
    public let points: [ScatterPoint]
    public let testPoints: [ScatterPoint]
    public let targetAccuracy: Double
    public let allowsFlagging: Bool

    public private(set) var model: ScatterModel
    public private(set) var flagged: Set<String> = []
    public private(set) var adjustments = 0
    public private(set) var hintsUsed = 0

    public init(spec: ChallengeSpec, classes: Int, points: [ScatterPoint], testPoints: [ScatterPoint],
                targetAccuracy: Double, allowsFlagging: Bool, model: ScatterModel) {
        self.spec = spec
        self.classes = classes
        self.points = points
        self.testPoints = testPoints
        self.targetAccuracy = targetAccuracy
        self.allowsFlagging = allowsFlagging
        self.model = model
    }

    /// Points that count for the score: unflagged ones. Flagging a non-outlier is a mistake and counts as wrong.
    public var scoringPoints: [ScatterPoint] { points.filter { !flagged.contains($0.id) } }

    public var wronglyFlaggedCount: Int { flagged.filter { id in points.first { $0.id == id }?.isOutlier == false }.count }

    public var accuracy: Double {
        let scored = scoringPoints
        guard !scored.isEmpty else { return 0 }
        let correct = scored.filter { predict($0) == $0.label }.count
        return Double(correct) / Double(scored.count + wronglyFlaggedCount)
    }

    public var isSolved: Bool { accuracy >= targetAccuracy }

    public func predict(_ point: ScatterPoint) -> Int {
        ScatterLearner.predict(model, x: point.x, y: point.y, points: scoringPoints)
    }

    public func predict(x: Double, y: Double) -> Int {
        ScatterLearner.predict(model, x: x, y: y, points: scoringPoints)
    }

    /// Predictions for the hidden "new animals" (shown after solving).
    public var testPredictions: [(point: ScatterPoint, predicted: Int)] {
        testPoints.map { ($0, predict($0)) }
    }

    public var testAccuracy: Double {
        guard !testPoints.isEmpty else { return 0 }
        return Double(testPredictions.filter { $0.predicted == $0.point.label }.count) / Double(testPoints.count)
    }

    public mutating func setThreshold(_ x: Double) {
        guard case .threshold = model else { return }
        model = .threshold(x: GrowthModel.clamp(x, 0, 1))
        adjustments += 1
    }

    public mutating func setLine(x1: Double, y1: Double, x2: Double, y2: Double) {
        guard case .line = model else { return }
        model = .line(x1: GrowthModel.clamp(x1, 0, 1), y1: GrowthModel.clamp(y1, 0, 1), x2: GrowthModel.clamp(x2, 0, 1), y2: GrowthModel.clamp(y2, 0, 1))
        adjustments += 1
    }

    public mutating func moveCentroid(label: Int, x: Double, y: Double) {
        guard case .centroids(var centroids) = model, let index = centroids.firstIndex(where: { $0.label == label }) else { return }
        centroids[index].x = GrowthModel.clamp(x, 0, 1)
        centroids[index].y = GrowthModel.clamp(y, 0, 1)
        model = .centroids(centroids)
        adjustments += 1
    }

    @discardableResult
    public mutating func toggleFlag(pointID: String) -> Bool {
        guard allowsFlagging, points.contains(where: { $0.id == pointID }) else { return false }
        if flagged.contains(pointID) { flagged.remove(pointID) } else { flagged.insert(pointID) }
        return true
    }

    /// A hint nudges the model toward the ideal one and counts as a hint.
    public mutating func applyHint() {
        hintsUsed += 1
        let ideal = ScatterContent.idealModel(for: self)
        switch (model, ideal) {
        case (.threshold(let t), .threshold(let it)):
            model = .threshold(x: t + (it - t) * 0.5)
        case (.line(let x1, let y1, let x2, let y2), .line(let ix1, let iy1, let ix2, let iy2)):
            model = .line(x1: x1 + (ix1 - x1) * 0.5, y1: y1 + (iy1 - y1) * 0.5, x2: x2 + (ix2 - x2) * 0.5, y2: y2 + (iy2 - y2) * 0.5)
        case (.centroids(var current), .centroids(let target)):
            for i in current.indices {
                if let t = target.first(where: { $0.label == current[i].label }) {
                    current[i].x += (t.x - current[i].x) * 0.5
                    current[i].y += (t.y - current[i].y) * 0.5
                }
            }
            model = .centroids(current)
        default:
            break
        }
    }

    /// Score used for XP: accuracy when solved, otherwise a fraction of it.
    public var scoreAccuracy: Double { isSolved ? accuracy : accuracy * 0.5 }
}

// MARK: - Content generation

public enum ScatterContent {
    static let twoClassThresholdCenters: [(Double, Double)] = [(0.25, 0.5), (0.75, 0.5)]
    static let twoClassLineCenters: [(Double, Double)] = [(0.30, 0.74), (0.72, 0.28)]
    static let threeClassCenters: [(Double, Double)] = [(0.22, 0.30), (0.76, 0.26), (0.50, 0.78)]

    /// params: "classes" (2|3), "boundary" (1 = line model), "outliers" (n), target accuracy 0.9.
    public static func make(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> ScatterChallenge {
        var rng = SeededGenerator(seed: seed)
        let classes = max(2, min(3, spec.param("classes", default: 2)))
        let useLine = spec.param("boundary", default: 0) == 1
        let outliers = spec.param("outliers", default: 0)
        let centers = classes == 3 ? threeClassCenters : (useLine ? twoClassLineCenters : twoClassThresholdCenters)
        let total = max(difficulty.itemCount(in: spec.itemRange), classes * 3)
        let spread = 0.11

        var points: [ScatterPoint] = []
        for i in 0..<total {
            let label = i % classes
            let c = centers[label]
            points.append(ScatterPoint(id: "p\(i + 1)", x: c.0 + rng.nextDouble(in: -spread..<spread), y: c.1 + rng.nextDouble(in: -spread..<spread), label: label, variant: (i / classes) % 3))
        }
        if outliers > 0 {
            for k in 0..<min(outliers, points.count / 3) {
                let index = k * 3
                let p = points[index]
                let other = centers[(p.label + 1) % classes]
                points[index] = ScatterPoint(id: p.id, x: other.0 + rng.nextDouble(in: -0.05..<0.05), y: other.1 + rng.nextDouble(in: -0.05..<0.05), label: p.label, isOutlier: true, variant: p.variant)
            }
        }
        points.shuffle(using: &rng)

        var tests: [ScatterPoint] = []
        for label in 0..<classes {
            for j in 0..<2 {
                let c = centers[label]
                tests.append(ScatterPoint(id: "t\(label)_\(j)", x: c.0 + rng.nextDouble(in: -0.07..<0.07), y: c.1 + rng.nextDouble(in: -0.07..<0.07), label: label, variant: j))
            }
        }

        let model: ScatterModel
        if classes == 3 {
            model = .centroids((0..<3).map { ScatterCentroid(x: 0.5 + Double($0 - 1) * 0.06, y: 0.5, label: $0) })
        } else if useLine {
            model = .line(x1: 0, y1: 0.12, x2: 1, y2: 0.12)
        } else {
            model = .threshold(x: 0.12)
        }

        return ScatterChallenge(spec: spec, classes: classes, points: points, testPoints: tests,
                                targetAccuracy: 0.9, allowsFlagging: outliers > 0, model: model)
    }

    /// The model AI CAT would build itself (used for hints and for the "compare with AI CAT" moment).
    public static func idealModel(for challenge: ScatterChallenge) -> ScatterModel {
        let points = challenge.points.filter { !$0.isOutlier }
        let centroids = ScatterLearner.centroids(of: points, classes: challenge.classes)
        switch challenge.model {
        case .threshold:
            return .threshold(x: (centroids[0].x + centroids[1].x) / 2)
        case .line:
            // Perpendicular bisector of the segment between the two centroids, clipped to the board.
            let mx = (centroids[0].x + centroids[1].x) / 2
            let my = (centroids[0].y + centroids[1].y) / 2
            let dx = centroids[1].x - centroids[0].x
            let dy = centroids[1].y - centroids[0].y
            let length = max((dx * dx + dy * dy).squareRoot(), 1e-6)
            let px = -dy / length, py = dx / length
            return .line(x1: GrowthModel.clamp(mx - px, 0, 1), y1: GrowthModel.clamp(my - py, 0, 1), x2: GrowthModel.clamp(mx + px, 0, 1), y2: GrowthModel.clamp(my + py, 0, 1))
        case .centroids:
            return .centroids(centroids)
        }
    }
}
