#!/usr/bin/env python3
"""Exhaustive three-expert ternary-code oracle for a conditional routed sum."""
import argparse
import itertools
import json

import numpy as np

TRITS = tuple(itertools.product((-1, 0, 1), repeat=3))
G2 = np.array([0.65, -0.75, 0.85])
U2 = np.array([0.8, 0.55, -0.7])
SCALE = np.array([1.0, 1.2, 0.9])
TEACHER_G = np.array([0.92, -0.78, 0.42])
TEACHER_U = np.array([-0.82, 0.72, 1.08])
TEACHER_D = np.array([1.08, -0.94, 0.86])
ROUTER = np.array([[1.0, 0.25], [-0.6, 0.9], [-0.45, -1.0]])
BIAS = np.array([0.12, 0.03, -0.06])
P = np.array([[1.0, 0.35], [-0.35, 1.0]])
Q = np.array([[0.83, 0.0], [0.0, 0.83]])


def silu(x):
    return x / (1.0 + np.exp(-x))


def routes(z):
    logits = z @ ROUTER.T + BIAS
    top = np.argsort(logits, axis=1, kind="stable")[:, -2:]
    scores = np.exp(logits - logits.max(axis=1, keepdims=True))
    scores /= np.take_along_axis(scores, top, axis=1).sum(axis=1, keepdims=True)
    mask = np.zeros_like(scores)
    np.put_along_axis(mask, top, 1.0, axis=1)
    return scores * mask


def teacher(z):
    gate = z[:, :1] * TEACHER_G + z[:, 1:] * G2
    up = z[:, :1] * TEACHER_U + z[:, 1:] * U2
    return silu(gate) * up * TEACHER_D


def candidates(z):
    codes = np.asarray(TRITS)
    gate = z[:, :1, None] * codes[None, :, :1] + z[:, 1:, None] * G2[None, None, :]
    up = z[:, :1, None] * codes[None, :, 1:2] + z[:, 1:, None] * U2[None, None, :]
    # Shape n x candidate x expert; each expert has its own 27-code book.
    return silu(gate) * up * codes[None, :, 2:] * SCALE[None, None, :]


def joint_exact(features, target):
    """Enumerate all 27^3 triples via exact quadratic expansion of sum error."""
    f = [features[:, :, e] for e in range(3)]
    diag = [np.sum(a * a, axis=0) - 2 * target @ a for a in f]
    pair = [2 * f[a].T @ f[b] for a, b in ((0, 1), (0, 2), (1, 2))]
    scores = (diag[0][:, None, None] + diag[1][None, :, None] + diag[2][None, None, :]
              + pair[0][:, :, None] + pair[1][:, None, :] + pair[2][None, :, :])
    return tuple(int(i) for i in np.unravel_index(np.argmin(scores), scores.shape))


def local_fit(book, teacher_expert, route_weights):
    return tuple(int(np.argmin(np.sum(
        (route_weights[:, e:e + 1] * (book[:, :, e] - teacher_expert[:, e:e + 1])) ** 2,
        axis=0))) for e in range(3))


def prediction(book, weights, codes):
    return np.sum(weights * np.stack([book[:, codes[e], e] for e in range(3)], axis=1), axis=1)


def evaluate(seed, ntrain, nheld):
    rng = np.random.default_rng(seed)
    x = rng.uniform(-1.7, 1.7, (ntrain + nheld, 2))
    original, quant = x @ P.T, x @ Q.T
    original_routes, quant_routes = routes(original), routes(quant)
    expert = teacher(original)
    target = np.sum(original_routes * expert, axis=1)
    book = candidates(quant)
    train = slice(None, ntrain)
    held = slice(ntrain, None)
    joint_fixed = joint_exact(book[train] * original_routes[train, None, :], target[train])
    joint_conditional = joint_exact(book[train] * quant_routes[train, None, :], target[train])
    independent = local_fit(book[train], expert[train], original_routes[train])
    independent_conditional = local_fit(book[train], expert[train], quant_routes[train])
    # Held oracle is only a capacity diagnostic and cannot select a deployable code.
    oracle_held = joint_exact(book[held] * quant_routes[held, None, :], target[held])
    code_sets = {"independent": independent, "independent_conditional": independent_conditional,
                 "joint_fixed_routes": joint_fixed, "joint_conditional": joint_conditional,
                 "held_oracle": oracle_held}
    predictions = {name: prediction(book, quant_routes, codes) for name, codes in code_sets.items()}
    selected_original = original_routes > 0
    selected_quant = quant_routes > 0
    shifted = np.any(selected_original != selected_quant, axis=1)
    route_only = np.sum(quant_routes * expert, axis=1)
    route_drift = route_only[held] - target[held]
    errors = {}
    for name, codes in code_sets.items():
        pred = predictions[name]
        local = quant_routes[held] * (np.stack([book[held, codes[e], e] for e in range(3)], axis=1)
                                      - expert[held])
        local_sum = local.sum(axis=1)
        errors[name] = {
            "train_mse": float(np.mean((pred[train] - target[train]) ** 2)),
            "held_mse": float(np.mean((pred[held] - target[held]) ** 2)),
            "held_stable_mse": float(np.mean((pred[held][~shifted[held]] - target[held][~shifted[held]]) ** 2)),
            "held_shifted_mse": float(np.mean((pred[held][shifted[held]] - target[held][shifted[held]]) ** 2)),
            "held_local_diagonal": float(np.mean(np.sum(local ** 2, axis=1))),
            "held_local_cross": float(np.mean(local_sum ** 2 - np.sum(local ** 2, axis=1))),
            "held_route_local_cross": float(np.mean(2 * route_drift * local_sum)),
            "trits": [list(TRITS[i]) for i in codes],
        }
    return {"seed": seed, "train": ntrain, "held": nheld,
            "route_set_change_train": float(np.mean(shifted[train])),
            "route_set_change_held": float(np.mean(shifted[held])),
            "route_only_held_mse": float(np.mean((route_only[held] - target[held]) ** 2)),
            "teacher_held_power": float(np.mean(target[held] ** 2)), "fits": errors}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", type=int, default=12)
    parser.add_argument("--train", type=int, default=96)
    parser.add_argument("--held", type=int, default=1024)
    args = parser.parse_args()
    runs = [evaluate(seed, args.train, args.held) for seed in range(args.seeds)]
    print(json.dumps({"construction": {"P": P.tolist(), "Q": Q.tolist(),
         "router": ROUTER.tolist(), "router_bias": BIAS.tolist(), "gate_second": G2.tolist(),
         "up_second": U2.tolist(), "down_scale": SCALE.tolist(), "teacher_gate_first": TEACHER_G.tolist(),
         "teacher_up_first": TEACHER_U.tolist(), "teacher_down": TEACHER_D.tolist(),
         "input": "uniform independent x coordinates in [-1.7,1.7]; fresh RNG per seed",
         "routing": "top two logits, stable tie rule; softmax over selected logits only",
         "book": "27 triplets (gate first trit, up first trit, down trit) per expert; second coefficients held fixed",
         "objective": "squared error of teacher original-producer routed sum versus quantized-producer routed sum"},
         "runs": runs}, separators=(",", ":")))


if __name__ == "__main__":
    main()
