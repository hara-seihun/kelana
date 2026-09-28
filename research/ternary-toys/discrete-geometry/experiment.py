"""Exact discrete loss geometry of a two-unit ternary gated classifier.

Run: OPENBLAS_NUM_THREADS=1 python3 experiment.py --output results.json
"""

import argparse
import itertools
import json
from pathlib import Path

import numpy as np


TRITS = np.array(list(itertools.product((-1, 0, 1), repeat=8)), dtype=np.int8)
POWERS = 3 ** np.arange(7, -1, -1)
DOWN = np.array([1.25, -1.1])


def index(code):
    return int((np.asarray(code) + 1) @ POWERS)


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def logits(codes, x):
    codes = np.asarray(codes).reshape(-1, 2, 2, 2)
    gates = np.einsum("ni,bji->bnj", x, codes[:, 0])
    ups = np.einsum("ni,bji->bnj", x, codes[:, 1])
    return 0.3 * x[:, 0][None, :] + np.sum(sigmoid(gates) * ups * DOWN, axis=2)


def loss(codes, x, teacher_p):
    z = logits(codes, x)
    return np.mean(np.logaddexp(0, z) - teacher_p[None, :] * z, axis=1)


def gradient(code, x, teacher_p):
    c = np.asarray(code).reshape(2, 2, 2)
    g = x @ c[0].T
    u = x @ c[1].T
    s = sigmoid(g)
    z = 0.3 * x[:, 0] + (s * u) @ DOWN
    residual = (sigmoid(z) - teacher_p)[:, None, None]
    grad_gate = np.mean(residual * ((s * (1 - s) * u) * DOWN)[:, :, None] * x[:, None, :], axis=0)
    grad_up = np.mean(residual * (s * DOWN)[:, :, None] * x[:, None, :], axis=0)
    return np.stack((grad_gate, grad_up)).ravel()


def neighbors(code, radius):
    code = np.asarray(code)
    for positions in itertools.combinations(range(8), radius):
        options = [[v for v in (-1, 0, 1) if v != code[i]] for i in positions]
        for values in itertools.product(*options):
            candidate = code.copy()
            candidate[list(positions)] = values
            yield index(candidate)


def descent(start, losses, radii):
    current = start
    calls = 0
    moves = []
    while True:
        candidates = [i for radius in radii for i in neighbors(TRITS[current], radius)]
        calls += len(candidates)
        best = min(candidates, key=lambda i: (losses[i], i))
        if losses[best] >= losses[current] - 1e-12:
            return current, calls, moves
        moves.append((current, best))
        current = best


def ste_descent(start, losses, x, teacher_p):
    current = start
    calls = 0
    moves = []
    while True:
        grad = gradient(TRITS[current], x, teacher_p)
        choices = list(neighbors(TRITS[current], 1))
        best = min(choices, key=lambda i: (grad @ (TRITS[i] - TRITS[current]), i))
        calls += 1
        if losses[best] >= losses[current] - 1e-12:
            return current, calls, moves, best, float(grad @ (TRITS[best] - TRITS[current]))
        moves.append((current, best))
        current = best


def problem(seed):
    rng = np.random.default_rng(seed)
    anchor = rng.integers(-1, 2, size=8)
    weights = anchor + rng.normal(0, 0.52, size=8)
    start = np.clip(np.rint(weights), -1, 1).astype(np.int8)
    def samples(n):
        a, b = rng.normal(size=(2, n))
        return np.stack((1.7 * a, 1.0 * a + 0.5 * b), axis=1)
    train = samples(48)
    held = samples(384)
    def teacher(x):
        return sigmoid(logits(weights[None, :], x)[0])
    return weights, index(start), train, teacher(train), held, teacher(held)


def analyze(seed):
    weights, start, train, p_train, held, p_held = problem(seed)
    fit = loss(TRITS, train, p_train)
    best = int(np.argmin(fit))
    single, single_calls, single_moves = descent(start, fit, (1,))
    pair, pair_calls, pair_moves = descent(start, fit, (2,))
    hybrid, hybrid_calls, hybrid_moves = descent(single, fit, (2,))
    radius_two, radius_two_calls, radius_two_moves = descent(start, fit, (1, 2))
    ste, ste_calls, ste_moves, rejected, predicted = ste_descent(start, fit, train, p_train)
    indices = [start, ste, single, pair, hybrid, radius_two, best]
    single_neighbors = list(neighbors(TRITS[single], 1))
    best_pair = min(neighbors(TRITS[single], 2), key=lambda i: (fit[i], i))
    changed = np.flatnonzero(TRITS[best_pair] != TRITS[single])
    first = TRITS[single].copy()
    second = TRITS[single].copy()
    first[changed[0]] = TRITS[best_pair, changed[0]]
    second[changed[1]] = TRITS[best_pair, changed[1]]
    first_delta = fit[index(first)] - fit[single]
    second_delta = fit[index(second)] - fit[single]
    joint_delta = fit[best_pair] - fit[single]
    held_losses = loss(TRITS[indices], held, p_held)
    return {
        "seed": seed,
        "real_weights": [round(float(v), 5) for v in weights],
        "start": TRITS[start].tolist(),
        "train": {name: round(float(fit[i]), 8) for name, i in zip(("start", "ste", "single", "pair", "single_then_pair", "radius_two", "oracle"), indices)},
        "held": {name: round(float(v), 8) for name, v in zip(("start", "ste", "single", "pair", "single_then_pair", "radius_two", "oracle"), held_losses)},
        "codes": {name: TRITS[i].tolist() for name, i in zip(("ste", "single", "pair", "single_then_pair", "radius_two", "oracle"), indices[1:])},
        "evaluations": {"ste": ste_calls, "single": single_calls, "pair": pair_calls, "single_then_pair_extra": hybrid_calls, "radius_two": radius_two_calls, "oracle": len(TRITS)},
        "moves": {"ste": [[TRITS[a].tolist(), TRITS[b].tolist()] for a, b in ste_moves], "single": [[TRITS[a].tolist(), TRITS[b].tolist()] for a, b in single_moves], "single_then_pair": [[TRITS[a].tolist(), TRITS[b].tolist()] for a, b in hybrid_moves], "radius_two": [[TRITS[a].tolist(), TRITS[b].tolist()] for a, b in radius_two_moves]},
        "ste_first_rejection": {"code": TRITS[rejected].tolist(), "predicted_delta": round(predicted, 8), "actual_delta": round(float(fit[rejected] - fit[ste]), 8)},
        "single_pair_barrier": round(float(min(fit[i] for i in single_neighbors) - fit[single]), 8),
        "single_best_pair_gain": round(float(-joint_delta), 8),
        "best_pair_witness": {"positions": changed.tolist(), "new_values": TRITS[best_pair, changed].tolist(), "single_deltas": [round(float(first_delta), 8), round(float(second_delta), 8)], "joint_delta": round(float(joint_delta), 8), "interaction": round(float(joint_delta - first_delta - second_delta), 8)},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("results.json"))
    parser.add_argument("--seeds", type=int, default=40)
    args = parser.parse_args()
    cases = [analyze(seed) for seed in range(args.seeds)]
    names = ("start", "ste", "single", "pair", "single_then_pair", "radius_two", "oracle")
    held_gain = np.array([c["held"]["single"] - c["held"]["radius_two"] for c in cases])
    bootstrap = np.random.default_rng(2026).choice(held_gain, size=(10000, len(cases)), replace=True).mean(axis=1)
    summary = {
        "seeds": args.seeds,
        "held_gain_radius_two_vs_single": {"mean": round(float(held_gain.mean()), 8), "bootstrap_95_percentile": [round(float(v), 8) for v in np.quantile(bootstrap, [0.025, 0.975])]},
        "train_mean": {name: round(float(np.mean([c["train"][name] for c in cases])), 8) for name in names},
        "held_mean": {name: round(float(np.mean([c["held"][name] for c in cases])), 8) for name in names},
        "oracle_reached": {name: sum(abs(c["train"][name] - c["train"]["oracle"]) < 1e-7 for c in cases) for name in names},
        "held_beats_single": {name: sum(c["held"][name] < c["held"]["single"] - 1e-8 for c in cases) for name in ("ste", "pair", "single_then_pair", "radius_two", "oracle")},
        "single_pair_escape": sum(c["single_best_pair_gain"] > 1e-8 for c in cases),
        "strict_barrier_and_pair_escape": sum(c["single_pair_barrier"] > 1e-8 and c["single_best_pair_gain"] > 1e-8 for c in cases),
        "ste_rejected_despite_predicted_gain": sum(c["ste_first_rejection"]["predicted_delta"] < -1e-8 and c["ste_first_rejection"]["actual_delta"] > 1e-8 for c in cases),
        "mean_evaluations": {name: round(float(np.mean([c["evaluations"][name] for c in cases])), 2) for name in ("ste", "single", "pair", "single_then_pair_extra", "radius_two", "oracle")},
    }
    compact = [{k: c[k] for k in ("seed", "train", "held", "evaluations", "single_pair_barrier", "single_best_pair_gain")} for c in cases]
    args.output.write_text(json.dumps({"summary": summary, "cases": compact, "example_seed_27": cases[27] if args.seeds > 27 else None}, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
