#!/usr/bin/env python3
"""Reference implementation (Python) of AI CAT's mathematical models.

The Swift package AICatCore mirrors these formulas exactly. This script
  1. validates the models' invariants (monotonic growth, bounded difficulty, …),
  2. prints human-readable tables for the GDD,
  3. writes Packages/AICatCore/Tests/AICatCoreTests/GoldenValues.swift so the
     Swift tests can assert the very same numbers on a Mac (`swift test`).

Rounding: every "round" is floor(x + 0.5) in both languages (no banker's rounding).
"""
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Packages", "AICatCore", "Tests", "AICatCoreTests", "GoldenValues.swift")

# ---------------------------------------------------------------- growth ----
# Growth is LINEAR in accumulated XP, normalised to 80 % of the theoretical
# maximum (10 scenarios x 900 XP = 9000) so that imperfect play still reaches
# adulthood. A logistic curve was evaluated first and rejected: it kept the
# kitten at stage 0 for ~2.4 scenarios, which hides progress from the child.
# Morphology applies smoothstep(g) for a gentle ease-in/ease-out of the shapes.
MAX_XP = 9000.0
NORMALIZATION_XP = 7200.0
STAGE_COUNT = 10


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def normalized_growth(xp: float) -> float:
    return clamp(xp / NORMALIZATION_XP, 0.0, 1.0)


def stage(xp: float) -> int:
    return min(STAGE_COUNT, int(math.floor(normalized_growth(xp) * STAGE_COUNT + 1e-9)))


def xp_for_stage(s: int) -> float:
    """Smallest xp whose stage is s (0 -> 0, 10 -> 7200)."""
    return clamp(s, 0, STAGE_COUNT) * NORMALIZATION_XP / STAGE_COUNT


def progress_within_stage(xp: float) -> float:
    if xp >= NORMALIZATION_XP:
        return 1.0
    width = NORMALIZATION_XP / STAGE_COUNT
    return clamp((xp - xp_for_stage(stage(xp))) / width, 0.0, 1.0)


def smoothstep(t: float) -> float:
    t = clamp(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# (name, kitten, adult) — metres unless noted
MORPHOLOGY = [
    ("bodyLength", 0.18, 0.45),
    ("headRadiusRatio", 0.42, 0.30),   # head radius / body length
    ("legLength", 0.05, 0.16),
    ("earScale", 1.30, 1.00),
    ("tailLength", 0.10, 0.30),
    ("eyeRadiusRatio", 0.28, 0.18),    # eye radius / head radius
]


def morphology(g_hat: float) -> dict:
    s = smoothstep(g_hat)
    return {name: a + (b - a) * s for name, a, b in MORPHOLOGY}


# ------------------------------------------------------------ difficulty ----
TARGET_SUCCESS = 0.75
GAIN = 0.15
BAND_INITIAL = {"explorer": 0.20, "apprentice": 0.45, "master": 0.70}


def difficulty_update(d: float, accuracy: float) -> float:
    return clamp(d + GAIN * (accuracy - TARGET_SUCCESS), 0.0, 1.0)


def round_half_up(x: float) -> int:
    return int(math.floor(x + 0.5))


def item_count(lo: int, hi: int, d: float) -> int:
    return round_half_up(lo + (hi - lo) * d)


# ---------------------------------------------------------------- scoring ----
def xp_for(tier: int, accuracy: float) -> int:
    return round_half_up(100.0 * tier * clamp(accuracy, 0.5, 1.0))


def stars(accuracy: float) -> int:
    return 3 if accuracy >= 0.95 else 2 if accuracy >= 0.75 else 1


# ------------------------------------------------------------- learners ----
def entropy(labels):
    n = len(labels)
    if n == 0:
        return 0.0
    counts = {}
    for l in labels:
        counts[l] = counts.get(l, 0) + 1
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


def information_gain(examples, attribute):
    """examples: list of (attrs: dict, label)"""
    total = entropy([l for _, l in examples])
    groups = {}
    for attrs, label in examples:
        groups.setdefault(attrs.get(attribute), []).append(label)
    n = len(examples)
    remainder = sum(len(g) / n * entropy(g) for g in groups.values())
    return total - remainder


def knn_predict(examples, query, k=3):
    """examples: list of (features: list[float], label). Returns (label, votes)."""
    dists = sorted(((math.dist(f, query), l) for f, l in examples), key=lambda t: t[0])[:k]
    votes, dsum = {}, {}
    for d, l in dists:
        votes[l] = votes.get(l, 0) + 1
        dsum[l] = dsum.get(l, 0.0) + d
    best = max(votes.values())
    tied = [l for l, v in votes.items() if v == best]
    if len(tied) == 1:
        return tied[0], votes
    return min(tied, key=lambda l: (dsum[l], l)), votes


# ---------------------------------------------------------------- checks ----
def validate():
    xs = [i * 50.0 for i in range(0, 181)]
    assert abs(progress_within_stage(360.0) - 0.5) < 1e-12
    gs = [normalized_growth(x) for x in xs]
    assert all(b >= a for a, b in zip(gs, gs[1:])), "growth must be monotonic"
    assert abs(gs[0]) < 1e-12 and abs(gs[-1] - 1.0) < 1e-12, "growth must span [0, 1]"
    assert stage(0) == 0 and stage(NORMALIZATION_XP) == 10 and stage(MAX_XP) == 10
    for s in range(0, 11):
        x = xp_for_stage(s)
        assert stage(x) == s, (s, x, stage(x))
        if s > 0:
            assert stage(x - 1.0) == s - 1, (s, x)
    d = 0.45
    for _ in range(200):
        d = difficulty_update(d, 1.0)
    assert d == 1.0
    for _ in range(200):
        d = difficulty_update(d, 0.0)
    assert d == 0.0
    assert xp_for(1, 1.0) == 100 and xp_for(3, 0.5) == 150 and xp_for(2, 0.2) == 100
    assert abs(entropy(["a", "b"]) - 1.0) < 1e-12 and entropy(["a", "a"]) == 0.0
    print("invariants: ok")


# ---------------------------------------------------------------- golden ----
GROWTH_XPS = [0, 100, 250, 500, 719, 720, 1000, 1500, 2000, 3000, 3600, 4000, 4500, 5000, 6000, 7000, 7199, 7200, 8000, 9000, 9500]
DIFF_SERIES = [1.0, 1.0, 0.5, 0.25, 0.9, 0.75, 0.6, 1.0, 1.0, 1.0, 0.0]
XP_CASES = [(1, 1.0), (1, 0.5), (1, 0.0), (2, 0.8), (3, 0.95), (3, 1.0), (2, 0.749), (1, 0.8)]
ENTROPY_CASES = [["a", "b"], ["a", "a", "a"], ["a", "a", "b", "c"], ["x"], ["a", "b", "c", "d"], []]
IG_EXAMPLES = [
    ({"color": "red", "shape": "round"}, "A"),
    ({"color": "red", "shape": "long"}, "A"),
    ({"color": "green", "shape": "round"}, "B"),
    ({"color": "green", "shape": "long"}, "B"),
    ({"color": "red", "shape": "round"}, "A"),
    ({"color": "green", "shape": "round"}, "B"),
]
KNN_EXAMPLES = [
    ([0.30, 0.90, 0.20], "cat"), ([0.35, 0.85, 0.25], "cat"), ([0.28, 0.95, 0.15], "cat"),
    ([0.60, 0.40, 0.60], "dog"), ([0.70, 0.35, 0.65], "dog"), ([0.55, 0.45, 0.55], "dog"),
    ([0.10, 0.00, 0.90], "bird"), ([0.12, 0.05, 0.95], "bird"), ([0.08, 0.02, 0.85], "bird"),
]
KNN_QUERIES = [[0.31, 0.88, 0.22], [0.65, 0.38, 0.62], [0.11, 0.03, 0.9], [0.45, 0.6, 0.4], [0.2, 0.5, 0.55]]


def swift_double(x: float) -> str:
    return repr(float(x))


def write_golden():
    lines = []
    lines.append("// GENERATED by Tools/reference_model.py — do not edit by hand.")
    lines.append("// Golden values shared between the Python reference model and AICatCore.")
    lines.append("import Foundation")
    lines.append("")
    lines.append("enum GoldenValues {")
    lines.append("    struct Growth { let xp: Double; let normalized: Double; let stage: Int; let bodyLength: Double; let headRadiusRatio: Double; let legLength: Double; let earScale: Double; let tailLength: Double; let eyeRadiusRatio: Double }")
    lines.append("    static let growth: [Growth] = [")
    for x in GROWTH_XPS:
        g = normalized_growth(float(x))
        m = morphology(g)
        lines.append(
            f"        Growth(xp: {swift_double(x)}, normalized: {swift_double(g)}, stage: {stage(float(x))}, "
            f"bodyLength: {swift_double(m['bodyLength'])}, headRadiusRatio: {swift_double(m['headRadiusRatio'])}, "
            f"legLength: {swift_double(m['legLength'])}, earScale: {swift_double(m['earScale'])}, "
            f"tailLength: {swift_double(m['tailLength'])}, eyeRadiusRatio: {swift_double(m['eyeRadiusRatio'])}),"
        )
    lines.append("    ]")
    lines.append("    static let xpForStage: [Double] = [" + ", ".join(swift_double(xp_for_stage(s)) for s in range(11)) + "]")
    lines.append("")
    d = BAND_INITIAL["apprentice"]
    seq = []
    for acc in DIFF_SERIES:
        d = difficulty_update(d, acc)
        seq.append(d)
    lines.append("    static let difficultyInputs: [Double] = [" + ", ".join(swift_double(a) for a in DIFF_SERIES) + "]")
    lines.append("    static let difficultyApprenticeTrace: [Double] = [" + ", ".join(swift_double(v) for v in seq) + "]")
    lines.append("    static let itemCounts: [(lo: Int, hi: Int, d: Double, n: Int)] = [" + ", ".join(
        f"(lo: {lo}, hi: {hi}, d: {swift_double(dd)}, n: {item_count(lo, hi, dd)})" for lo, hi, dd in [(4, 12, 0.0), (4, 12, 0.5), (4, 12, 1.0), (6, 9, 0.33), (3, 10, 0.5), (5, 5, 0.9)]) + "]")
    lines.append("")
    lines.append("    static let xpCases: [(tier: Int, accuracy: Double, xp: Int, stars: Int)] = [" + ", ".join(
        f"(tier: {t}, accuracy: {swift_double(a)}, xp: {xp_for(t, a)}, stars: {stars(a)})" for t, a in XP_CASES) + "]")
    lines.append("")
    lines.append("    static let entropyCases: [(labels: [String], entropy: Double)] = [" + ", ".join(
        "(labels: [" + ", ".join(f'"{l}"' for l in labels) + f"], entropy: {swift_double(entropy(labels))})" for labels in ENTROPY_CASES) + "]")
    lines.append("    static let informationGainColor: Double = " + swift_double(information_gain(IG_EXAMPLES, "color")))
    lines.append("    static let informationGainShape: Double = " + swift_double(information_gain(IG_EXAMPLES, "shape")))
    lines.append("")
    lines.append("    static let knnExamples: [(features: [Double], label: String)] = [" + ", ".join(
        "(features: [" + ", ".join(swift_double(v) for v in f) + f'], label: "{l}")' for f, l in KNN_EXAMPLES) + "]")
    lines.append("    static let knnQueries: [(features: [Double], label: String)] = [" + ", ".join(
        "(features: [" + ", ".join(swift_double(v) for v in q) + f'], label: "{knn_predict(KNN_EXAMPLES, q)[0]}")' for q in KNN_QUERIES) + "]")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {os.path.relpath(OUT, ROOT)}")


def print_tables():
    print("\nGrowth stages (xp → ĝ, stage, body length m, head ratio, leg m):")
    for x in [0, 360, 720, 1440, 2160, 3600, 5040, 6480, 7200, 9000]:
        g = normalized_growth(float(x))
        m = morphology(g)
        print(f"  xp={x:5d}  ĝ={g:.3f}  stage={stage(float(x)):2d}  body={m['bodyLength']:.3f}  head={m['headRadiusRatio']:.3f}  legs={m['legLength']:.3f}")
    print("\nStage boundaries (xp):", ", ".join(f"{s}:{xp_for_stage(s):.0f}" for s in range(11)))
    print("\nDifficulty trace (apprentice, accuracies → d):")
    d = BAND_INITIAL["apprentice"]
    for acc in DIFF_SERIES:
        d = difficulty_update(d, acc)
        print(f"  acc={acc:.2f} → d={d:.4f}  items(4..12)={item_count(4, 12, d)}")


if __name__ == "__main__":
    validate()
    print_tables()
    write_golden()
