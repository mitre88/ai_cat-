import Foundation

// MARK: - Pixel images

public struct PixelPoint: Hashable, Sendable, Codable {
    public let x: Int
    public let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}

/// A tiny grey-scale image: one digit per pixel, 0 = black … 9 = white, rows from the top.
public struct PixelImage: Hashable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var values: [Int]

    public init(width: Int, height: Int, values: [Int]) {
        precondition(values.count == width * height, "values must be width × height")
        self.width = width
        self.height = height
        self.values = values
    }

    /// Parses rows of digits, e.g. "0011" (all rows the same length).
    public static func parse(_ rows: [String]) -> PixelImage {
        let height = rows.count
        let width = rows.first?.count ?? 0
        var values: [Int] = []
        for row in rows {
            for character in row {
                values.append(Int(String(character)) ?? 0)
            }
        }
        return PixelImage(width: width, height: height, values: values)
    }

    public func contains(_ point: PixelPoint) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < width && point.y < height
    }

    public subscript(point: PixelPoint) -> Int {
        get { values[point.y * width + point.x] }
        set { values[point.y * width + point.x] = newValue }
    }

    public var allPoints: [PixelPoint] {
        (0..<height).flatMap { y in (0..<width).map { x in PixelPoint(x, y) } }
    }

    public var maxValue: Int { values.max() ?? 0 }

    /// Every pixel holding the maximum value.
    public var brightestPixels: Set<PixelPoint> {
        let top = maxValue
        return Set(allPoints.filter { self[$0] == top })
    }

    public func neighbours(of point: PixelPoint) -> [PixelPoint] {
        [PixelPoint(point.x + 1, point.y), PixelPoint(point.x - 1, point.y), PixelPoint(point.x, point.y + 1), PixelPoint(point.x, point.y - 1)]
            .filter(contains)
    }

    /// Biggest change to any 4-neighbour: a simple gradient magnitude.
    public func gradient(at point: PixelPoint) -> Int {
        neighbours(of: point).map { abs(self[$0] - self[point]) }.max() ?? 0
    }

    /// Pixels whose gradient reaches the threshold (threshold 0 marks everything).
    public func edges(threshold: Int) -> Set<PixelPoint> {
        Set(allPoints.filter { gradient(at: $0) >= threshold })
    }

    /// Ground truth: pixels next to a pixel on the other side of `foregroundLevel`.
    public func boundary(foregroundLevel: Int) -> Set<PixelPoint> {
        Set(allPoints.filter { point in
            let inside = self[point] >= foregroundLevel
            return neighbours(of: point).contains { (self[$0] >= foregroundLevel) != inside }
        })
    }

    /// Pixels where both images are "close" (difference ≤ tolerance): the clues a matcher counts.
    public func matchingPixels(with other: PixelImage, tolerance: Int = 2) -> Int {
        guard other.width == width, other.height == height else { return 0 }
        return zip(values, other.values).filter { abs($0 - $1) <= tolerance }.count
    }
}

// MARK: - Level 1: pixels

/// Zoom into the picture until the numbers appear, then tap every brightest pixel.
public struct PixelChallenge: Sendable {
    public let spec: ChallengeSpec
    public let image: PixelImage
    public let targets: Set<PixelPoint>
    public private(set) var picks: Set<PixelPoint> = []
    public private(set) var wrongPicks = 0
    public private(set) var zoom = 1
    public static let maxZoom = 3

    public init(spec: ChallengeSpec, image: PixelImage) {
        self.spec = spec
        self.image = image
        targets = image.brightestPixels
    }

    public var isSolved: Bool { targets.isSubset(of: picks) }
    public var remaining: Int { targets.subtracting(picks).count }

    public mutating func setZoom(_ level: Int) {
        zoom = max(1, min(Self.maxZoom, level))
    }

    /// Returns whether the tapped pixel is one of the brightest. Needs full zoom (the numbers are visible).
    @discardableResult
    public mutating func tap(_ point: PixelPoint) -> Bool {
        guard !isSolved, image.contains(point), zoom == Self.maxZoom, !picks.contains(point) else { return targets.contains(point) }
        picks.insert(point)
        if targets.contains(point) { return true }
        wrongPicks += 1
        return false
    }

    public var scoreAccuracy: Double { isSolved ? max(0.5, 1 - 0.15 * Double(wrongPicks)) : 0 }
}

// MARK: - Level 2: edges

/// Turn the threshold dial until the detected edges match the outline of the shape.
public struct EdgeChallenge: Sendable {
    public let spec: ChallengeSpec
    public let image: PixelImage
    public let foregroundLevel: Int
    public let boundary: Set<PixelPoint>
    public private(set) var threshold = 0
    public private(set) var adjustments = 0
    public static let targetF1 = 0.8

    public init(spec: ChallengeSpec, image: PixelImage, foregroundLevel: Int) {
        self.spec = spec
        self.image = image
        self.foregroundLevel = foregroundLevel
        boundary = image.boundary(foregroundLevel: foregroundLevel)
    }

    public var edges: Set<PixelPoint> { image.edges(threshold: threshold) }

    /// F1 between the detected edges and the true outline (precision and recall in one number).
    public var f1: Double {
        let detected = edges
        let hits = detected.intersection(boundary).count
        guard hits > 0 else { return 0 }
        let precision = Double(hits) / Double(detected.count)
        let recall = Double(hits) / Double(max(boundary.count, 1))
        return 2 * precision * recall / (precision + recall)
    }

    public var isSolved: Bool { f1 >= Self.targetF1 }

    public mutating func setThreshold(_ value: Int) {
        let clamped = max(0, min(9, value))
        guard clamped != threshold else { return }
        threshold = clamped
        adjustments += 1
    }

    /// Solved = 1 minus 0.03 per adjustment beyond six (never below 0.7); unsolved = half the F1.
    public var scoreAccuracy: Double {
        guard isSolved else { return f1 * 0.5 }
        return max(0.7, 1 - 0.03 * Double(max(0, adjustments - 6)))
    }
}

// MARK: - Level 3: shapes

public struct PixelTemplate: Hashable, Sendable, Identifiable {
    public let id: String
    public let image: PixelImage

    public init(id: String, image: PixelImage) {
        self.id = id
        self.image = image
    }

    public var nameKey: String { "vision.shape.\(id)" }
}

public struct ShapeRound: Hashable, Sendable {
    public let query: PixelImage
    public let answerID: String
    /// Clues (matching pixels) per template id, as AI CAT counts them.
    public let clues: [String: Int]

    public init(query: PixelImage, answerID: String, clues: [String: Int]) {
        self.query = query
        self.answerID = answerID
        self.clues = clues
    }
}

/// A noisy picture against four templates: the template with the most clues is what AI CAT recognises.
public struct ShapeMatchChallenge: Sendable {
    public let spec: ChallengeSpec
    public let templates: [PixelTemplate]
    public let rounds: [ShapeRound]
    public private(set) var answers: [String] = []

    public init(spec: ChallengeSpec, templates: [PixelTemplate], rounds: [ShapeRound]) {
        self.spec = spec
        self.templates = templates
        self.rounds = rounds
    }

    public var currentIndex: Int { answers.count }
    public var current: ShapeRound? { rounds.indices.contains(currentIndex) ? rounds[currentIndex] : nil }
    public var isComplete: Bool { answers.count >= rounds.count }
    public var correctCount: Int { zip(answers, rounds).filter { $0 == $1.answerID }.count }
    public var isSolved: Bool { isComplete }

    @discardableResult
    public mutating func pick(_ templateID: String) -> Bool? {
        guard let round = current, templates.contains(where: { $0.id == templateID }) else { return nil }
        answers.append(templateID)
        return templateID == round.answerID
    }

    public var scoreAccuracy: Double { isComplete ? Double(correctCount) / Double(max(rounds.count, 1)) : 0 }
}

// MARK: - Level 4: live checks

public struct LiveCheck: Hashable, Sendable, Identifiable {
    public let id: Int
    public let label: String
    public let confidence: Double
    public let agreed: Bool

    public init(id: Int, label: String, confidence: Double, agreed: Bool) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.agreed = agreed
    }
}

/// The child checks AI CAT's guesses about real things (camera) or sample pictures.
public struct LiveCheckChallenge: Sendable {
    public let spec: ChallengeSpec
    public let required: Int
    public private(set) var checks: [LiveCheck] = []

    public init(spec: ChallengeSpec, required: Int) {
        self.spec = spec
        self.required = max(1, required)
    }

    public var isSolved: Bool { checks.count >= required }
    public var disagreements: Int { checks.filter { !$0.agreed }.count }

    public mutating func record(label: String, confidence: Double, agreed: Bool) {
        guard !isSolved else { return }
        checks.append(LiveCheck(id: checks.count, label: label, confidence: max(0, min(1, confidence)), agreed: agreed))
    }

    public var scoreAccuracy: Double { isSolved ? 1 : 0.5 * Double(checks.count) / Double(required) }
}

// MARK: - Content

public enum VisionContent {
    /// 10×10 shapes: dark background (0–2), bright foreground (6–8). Level 1 adds a few 9s to find.
    static let shapes: [String: [String]] = [
        "fish": ["0000000000",
                 "0001110000",
                 "0017771000",
                 "0177777100",
                 "1777877710",
                 "1777777710",
                 "0177777100",
                 "0017771000",
                 "0001110000",
                 "0000000000"],
        "ball": ["0000000000",
                 "0001111000",
                 "0017777100",
                 "0177887710",
                 "0178887710",
                 "0177887710",
                 "0177777710",
                 "0017777100",
                 "0001111000",
                 "0000000000"],
        "cup":  ["0000000000",
                 "0111111000",
                 "0177777100",
                 "0177777110",
                 "0177777171",
                 "0177777171",
                 "0177777110",
                 "0177777100",
                 "0111111000",
                 "0000000000"],
        "star": ["0000100000",
                 "0000710000",
                 "0001771000",
                 "1117777111",
                 "0177777710",
                 "0017777100",
                 "0017777100",
                 "0177117710",
                 "0171001710",
                 "0100000010"],
        "house": ["0000110000",
                  "0001771000",
                  "0017777100",
                  "0177777710",
                  "1777777771",
                  "0177777710",
                  "0177117710",
                  "0177117710",
                  "0177117710",
                  "0111111110"],
        "heart": ["0000000000",
                  "0110000110",
                  "1771001771",
                  "1777117771",
                  "1777777771",
                  "0177777710",
                  "0017777100",
                  "0001771000",
                  "0000110000",
                  "0000000000"],
    ]

    public static let shapeIDs = ["fish", "ball", "cup", "star", "house", "heart"]

    public static func image(_ id: String) -> PixelImage {
        PixelImage.parse(shapes[id] ?? shapes["fish"]!)
    }

    /// Level 1: a shape with 1–3 pixels at 9 to find; the rest never reaches 9.
    public static func makePixels(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> PixelChallenge {
        var rng = SeededGenerator(seed: seed)
        let id = shapeIDs[Int(rng.next() % UInt64(shapeIDs.count))]
        var image = self.image(id)
        let brightCount = max(1, min(3, difficulty.itemCount(in: spec.itemRange) / 2))
        let candidates = image.allPoints.filter { image[$0] >= 7 }.shuffled(using: &rng)
        for point in candidates.prefix(brightCount) {
            image[point] = 9
        }
        return PixelChallenge(spec: spec, image: image)
    }

    /// Level 2: the same shapes with a little shading, so only a band of thresholds matches the outline.
    public static func makeEdges(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> EdgeChallenge {
        var rng = SeededGenerator(seed: seed)
        let id = shapeIDs[Int(rng.next() % UInt64(shapeIDs.count))]
        var image = self.image(id)
        for point in image.allPoints {
            let value = image[point]
            if value >= 6 {
                image[point] = 6 + Int(rng.next() % 3)          // 6…8 inside
            } else if value <= 2 {
                image[point] = Int(rng.next() % 3)              // 0…2 outside
            }
        }
        return EdgeChallenge(spec: spec, image: image, foregroundLevel: 5)
    }

    /// Level 3: three or four rounds; each query is a template with a few pixels flipped.
    public static func makeShapes(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> ShapeMatchChallenge {
        var rng = SeededGenerator(seed: seed)
        var ids = shapeIDs
        ids.shuffle(using: &rng)
        let templates = ids.prefix(4).map { PixelTemplate(id: $0, image: image($0)) }
        let roundCount = max(3, min(4, difficulty.itemCount(in: spec.itemRange) / 2))
        let flips = 4 + difficulty.tier * 3
        var rounds: [ShapeRound] = []
        for round in 0..<roundCount {
            let answer = templates[round % templates.count]
            var query = answer.image
            let points = query.allPoints.shuffled(using: &rng).prefix(flips)
            for point in points {
                query[point] = query[point] >= 5 ? Int(rng.next() % 3) : 6 + Int(rng.next() % 3)
            }
            var clues: [String: Int] = [:]
            for template in templates {
                clues[template.id] = query.matchingPixels(with: template.image)
            }
            rounds.append(ShapeRound(query: query, answerID: answer.id, clues: clues))
        }
        return ShapeMatchChallenge(spec: spec, templates: Array(templates), rounds: rounds)
    }

    public static func makeLive(spec: ChallengeSpec, difficulty: AdaptiveDifficulty, seed: UInt64) -> LiveCheckChallenge {
        LiveCheckChallenge(spec: spec, required: max(3, min(6, difficulty.itemCount(in: spec.itemRange) / 2 + 1)))
    }
}
