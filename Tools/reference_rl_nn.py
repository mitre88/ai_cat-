#!/usr/bin/env python3
"""Independent Python reference for the seeded algorithms of worlds 5, 6 and 10:
SplitMix64 (AICatCore.SeededGenerator), tabular Q-learning (MazeLearner), the 4-3-1 sigmoid network
(SigmoidNetwork) and the story grammar sampler (StoryGenerator). Generates
Packages/AICatCore/Tests/AICatCoreTests/GoldenRLValues.swift, which GoldenRLTests compares against Swift.
Run: python3 Tools/reference_rl_nn.py
"""
import math
import os

MASK = (1 << 64) - 1


class Seeded:
    """SplitMix64, bit-for-bit the same as SeededGenerator."""

    def __init__(self, seed):
        self.state = seed & MASK

    def next(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        return (z ^ (z >> 31)) & MASK

    def unit(self):
        return (self.next() >> 11) / float(1 << 53)

    def double(self, lo, hi):
        return lo + (hi - lo) * self.unit()


# ---- Maze (MazeMachine.swift) -------------------------------------------------
DELTA = [(0, 1), (1, 0), (0, -1), (-1, 0)]  # N, E, S, W
REWARD_STEP, REWARD_BUMP, REWARD_TREAT, REWARD_PUDDLE = -0.04, -0.10, 1.0, -1.0


def parse(lines):
    size = len(lines)
    tiles = {}
    start = (0, 0)
    for row, line in enumerate(lines):
        y = size - 1 - row
        for x, ch in enumerate(line):
            tiles[(x, y)] = {"#": "wall", "T": "treat", "~": "puddle"}.get(ch, "free")
            if ch == "S":
                start = (x, y)
    return size, tiles, start


def step(size, tiles, cell, action):
    nx, ny = cell[0] + DELTA[action][0], cell[1] + DELTA[action][1]
    if not (0 <= nx < size and 0 <= ny < size) or tiles[(nx, ny)] == "wall":
        return cell, True
    return (nx, ny), False


def reward(tile, bumped):
    if bumped:
        return REWARD_BUMP, False
    return {"treat": (REWARD_TREAT, True), "puddle": (REWARD_PUDDLE, True)}.get(tile, (REWARD_STEP, False))


class Learner:
    def __init__(self, size, epsilon, alpha=0.5, gamma=0.9, max_steps=60):
        self.size, self.eps, self.alpha, self.gamma, self.max_steps = size, epsilon, alpha, gamma, max_steps
        self.q = {}

    def value(self, cell, action):
        return self.q.get((cell, action), 0.0)

    def best(self, cell):
        best, best_value = 0, -math.inf
        for a in range(4):
            v = self.value(cell, a)
            if v > best_value:
                best, best_value = a, v
        return best

    def state_value(self, cell):
        return max(self.value(cell, a) for a in range(4))

    def run_episode(self, size, tiles, start, rng):
        cell, steps, outcome = start, [], "wandered"
        for _ in range(self.max_steps):
            if rng.unit() < self.eps:
                action = min(3, int(rng.unit() * 4))
            else:
                action = self.best(cell)
            nxt, bumped = step(size, tiles, cell, action)
            r, terminal = reward(tiles[nxt], bumped)
            target = r if terminal else r + self.gamma * self.state_value(nxt)
            self.q[(cell, action)] = self.value(cell, action) + self.alpha * (target - self.value(cell, action))
            steps.append((cell, action, nxt, r))
            cell = nxt
            if terminal:
                outcome = "treat" if tiles[nxt] == "treat" else "puddle"
                break
        return steps, outcome

    def greedy(self, size, tiles, start, max_steps=100):
        cell, path, visited = start, [start], {start}
        for _ in range(max_steps):
            action = self.best(cell)
            nxt, bumped = step(size, tiles, cell, action)
            r, terminal = reward(tiles[nxt], bumped)
            path.append(nxt)
            cell = nxt
            if terminal:
                return path, "treat" if tiles[nxt] == "treat" else "puddle"
            if bumped or nxt in visited:
                break
            visited.add(nxt)
        return path, "wandered"


# ---- Sigmoid network (NeuronMachine.swift) ------------------------------------
def sigmoid(z):
    return 1.0 / (1.0 + math.exp(-max(-60.0, min(60.0, z))))


def all_rows(n):
    return [[(pattern >> (n - 1 - i)) & 1 for i in range(n)] for pattern in range(1 << n)]


class Network:
    def __init__(self, inputs, hidden, seed):
        rng = Seeded(seed)
        self.w1 = [[rng.double(-0.8, 0.8) for _ in range(inputs)] for _ in range(hidden)]
        self.b1 = [rng.double(-0.8, 0.8) for _ in range(hidden)]
        self.w2 = [rng.double(-0.8, 0.8) for _ in range(hidden)]
        self.b2 = rng.double(-0.8, 0.8)

    def forward(self, x):
        h = []
        for j in range(len(self.w1)):
            acc = 0.0
            for w, xi in zip(self.w1[j], x):
                acc = acc + w * xi
            h.append(sigmoid(acc + self.b1[j]))
        acc = 0.0
        for w, hj in zip(self.w2, h):
            acc = acc + w * hj
        return h, sigmoid(acc + self.b2)

    def loss(self, examples):
        total = 0.0
        for x, t in examples:
            o = self.forward(x)[1]
            total = total - (t * math.log(max(o, 1e-12)) + (1 - t) * math.log(max(1 - o, 1e-12)))
        return total / len(examples)

    def correct(self, examples):
        return sum(1 for x, t in examples if (self.forward(x)[1] > 0.5) == (t == 1))

    def train_epoch(self, examples, eta):
        hidden, inputs = len(self.w1), len(self.w1[0])
        g_w1 = [[0.0] * inputs for _ in range(hidden)]
        g_b1, g_w2, g_b2, total = [0.0] * hidden, [0.0] * hidden, 0.0, 0.0
        for x, t in examples:
            h, o = self.forward(x)
            total = total - (t * math.log(max(o, 1e-12)) + (1 - t) * math.log(max(1 - o, 1e-12)))
            d_o = o - t
            for j in range(hidden):
                g_w2[j] += d_o * h[j]
                d_h = d_o * self.w2[j] * h[j] * (1 - h[j])
                for i in range(inputs):
                    g_w1[j][i] += d_h * x[i]
                g_b1[j] += d_h
            g_b2 += d_o
        n = float(len(examples))
        for j in range(hidden):
            for i in range(inputs):
                self.w1[j][i] -= eta * g_w1[j][i] / n
            self.b1[j] -= eta * g_b1[j] / n
            self.w2[j] -= eta * g_w2[j] / n
        self.b2 -= eta * g_b2 / n
        return total / n


def main():
    out = []
    # Maze: level 1 layout A with the treat at (3,3); ε = 0.3; 6 episodes with seed 2024.
    size, tiles, start = parse(["....", ".#..", ".#..", "S..."])
    tiles[(3, 3)] = "treat"
    learner = Learner(size, 0.3)
    rng = Seeded(2024)
    outcomes, lengths = [], []
    for _ in range(6):
        steps, outcome = learner.run_episode(size, tiles, start, rng)
        outcomes.append(outcome)
        lengths.append(len(steps))
    q_start = [learner.value(start, a) for a in range(4)]
    path, greedy_outcome = learner.greedy(size, tiles, start)
    out.append(f"    static let mazeOutcomes: [String] = {outcomes!r}".replace("'", '"'))
    out.append(f"    static let mazeEpisodeLengths: [Int] = {lengths}")
    out.append("    static let mazeStartQ: [Double] = [" + ", ".join(repr(v) for v in q_start) + "]")
    out.append(f"    static let mazeGreedyOutcome = \"{greedy_outcome}\"")
    out.append("    static let mazeGreedyPath: [[Int]] = [" + ", ".join(f"[{x}, {y}]" for x, y in path) + "]")
    out.append(f"    static let mazeRandomDraws: [Double] = [" + ", ".join(repr(Seeded(2024).unit()) for _ in range(1)) + "]")

    # Network: 4-3-1, seed 5, "at least three lamps" target, 10 epochs at η = 3.
    examples = [(row, 1 if sum(row) >= 3 else 0) for row in all_rows(4)]
    net = Network(4, 3, 5)
    first_weights = [net.w1[0][0], net.b1[0], net.w2[0], net.b2]
    initial_loss = net.loss(examples)
    first_epoch_loss = net.train_epoch(examples, 3.0)
    for _ in range(9):
        net.train_epoch(examples, 3.0)
    out.append("    static let networkFirstWeights: [Double] = [" + ", ".join(repr(v) for v in first_weights) + "]")
    out.append(f"    static let networkInitialLoss: Double = {initial_loss!r}")
    out.append(f"    static let networkFirstEpochLoss: Double = {first_epoch_loss!r}")
    out.append(f"    static let networkLossAfterTenEpochs: Double = {net.loss(examples)!r}")
    out.append(f"    static let networkCorrectAfterTenEpochs: Int = {net.correct(examples)}")

    # Story grammar: seed 42 → three variant indices.
    rng = Seeded(42)
    variants = [rng.next() % 3 for _ in range(3)]
    out.append(f"    static let storyVariantsSeed42: [Int] = {variants}")

    # Raw generator: first three outputs of seed 1 (as decimal UInt64 literals).
    rng = Seeded(1)
    out.append("    static let splitMixSeed1: [UInt64] = [" + ", ".join(str(rng.next()) for _ in range(3)) + "]")

    body = "\n".join(out)
    swift = f"""// Generated by Tools/reference_rl_nn.py — do not edit.
// Python reference values for the seeded algorithms of worlds 5, 6 and 10.
import Foundation

enum GoldenRLValues {{
{body}
}}
"""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    path = os.path.join(root, "Packages", "AICatCore", "Tests", "AICatCoreTests", "GoldenRLValues.swift")
    with open(path, "w", encoding="utf-8") as f:
        f.write(swift)
    print(swift)


if __name__ == "__main__":
    main()
