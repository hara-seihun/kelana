#!/usr/bin/env python3
"""Exact finite-codebook and stochastic-rollout experiment for a gated recurrence."""
import itertools
import json
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

W = np.array([[1.0436, .0415], [-.7816, .8131]], dtype=np.float64)
GATE = .5
B = np.array([1., 0.]) * GATE
CODES = np.array(list(itertools.product((-1., 0., 1.), repeat=2)))
SIGMA = .005
HORIZON = 512


def transition(w):
    return (1 - GATE) * np.eye(2) + GATE * w


def radius(w):
    return float(np.max(np.abs(np.linalg.eigvals(transition(w)))))


def row_fit(row, code):
    return max(0., float(np.dot(row, code) / np.dot(code, code))) if np.any(code) else 0.


def encoded(code, scale):
    return code * np.asarray(scale)[:, None]


def impulse_error(w):
    """Infinite-horizon expected squared state error / input variance."""
    a, ref = transition(w), transition(W)
    if radius(w) >= 1:
        return 1e5 + 1e5 * (radius(w) - 1)
    block = np.block([[ref, np.zeros((2, 2))], [np.zeros((2, 2)), a]])
    inp = np.concatenate((B, B))
    cov = np.linalg.solve(np.eye(16) - np.kron(block, block), np.outer(inp, inp).reshape(-1)).reshape(4, 4)
    diff = cov[:2, :2] + cov[2:, 2:] - cov[:2, 2:] - cov[2:, :2]
    return float(np.trace(diff))


def one_step_fit():
    code = np.zeros_like(W)
    scale = np.zeros(2)
    for row in range(2):
        options = [(np.linalg.norm(W[row] - row_fit(W[row], c) * c) ** 2, tuple(c), row_fit(W[row], c)) for c in CODES if np.any(c)]
        _, best, scale[row] = min(options)
        code[row] = best
    return code, scale


def optimize_codebook(codes):
    solutions = []
    for code in codes:
        code = np.asarray(code)
        initial = np.array([row_fit(W[i], code[i]) for i in range(2)])
        starts = [initial, initial * .9, np.array([.7, .7]), np.array([1., .5])]
        for start in starts:
            result = minimize(lambda scale: impulse_error(encoded(code, scale)), start, bounds=[(0, 1.5)] * 2,
                              method="Nelder-Mead", options={"maxiter": 180, "xatol": 1e-7, "fatol": 1e-9})
            matrix = encoded(code, result.x)
            if radius(matrix) < 1:
                solutions.append((impulse_error(matrix), code.copy(), result.x.copy()))
    return min(solutions, key=lambda item: item[0])


def rollout(w, drives, nonlinear=False):
    state = np.zeros(2)
    states = np.empty((len(drives), 2))
    a = transition(w)
    for t, drive in enumerate(drives):
        state = ((1 - GATE) * state + GATE * np.tanh(w @ state + np.array([drive, 0.]))) if nonlinear else a @ state + B * drive
        states[t] = state
    return states


def summary(w, stochastic, pulse, release, truth_stochastic, truth_pulse, truth_release, truth_nonlinear_pulse):
    st = rollout(w, stochastic)
    pl = rollout(w, pulse)
    nl = rollout(w, release, nonlinear=True)
    nonlinear_pulse = rollout(w, pulse, nonlinear=True)
    return {
        "matrix": w.tolist(),
        "spectral_radius": radius(w),
        "relative_one_step_matrix_error": float(np.linalg.norm(w - W) / np.linalg.norm(W)),
        "infinite_white_input_error_over_variance": impulse_error(w) if radius(w) < 1 else None,
        "stochastic_rmse_all_steps": float(np.sqrt(np.mean((st - truth_stochastic) ** 2))),
        "stochastic_rmse_last_128": float(np.sqrt(np.mean((st[-128:] - truth_stochastic[-128:]) ** 2))),
        "pulse_rmse_last_128": float(np.sqrt(np.mean((pl[-128:] - truth_pulse[-128:]) ** 2))),
        "pulse_final": pl[-1].tolist(),
        "nonlinear_release_rmse_last_128": float(np.sqrt(np.mean((nl[-128:] - truth_release[-128:]) ** 2))),
        "nonlinear_constant_rmse_last_128": float(np.sqrt(np.mean((nonlinear_pulse[-128:] - truth_nonlinear_pulse[-128:]) ** 2))),
        "nonlinear_release_final": nl[-1].tolist(),
        "constant_input_fixed_point_if_stable": np.linalg.solve(np.eye(2) - w, np.array([.005, 0.])).tolist() if radius(w) < 1 else None,
    }


def main():
    local_code, local_scale = one_step_fit()
    local_scale = np.asarray(local_scale, dtype=np.float16).astype(np.float64)
    local = encoded(local_code, local_scale)
    scale_loss, _, scale = optimize_codebook([local_code])
    scale = np.asarray(scale, dtype=np.float16).astype(np.float64)
    same_rate = encoded(local_code, scale)
    all_codes = (np.array(pair) for pair in itertools.product(CODES, repeat=2))
    global_loss, global_code, global_scale = optimize_codebook(all_codes)
    global_scale = np.asarray(global_scale, dtype=np.float16).astype(np.float64)
    global_oracle = encoded(global_code, global_scale)
    exception = local.copy()
    exception[0, 1] = float(np.float16(W[0, 1]))
    rng = np.random.default_rng(20260923)
    stochastic = SIGMA * rng.standard_normal(HORIZON)
    pulse = np.full(HORIZON, .005)
    release = np.zeros(HORIZON)
    release[:32] = .005
    truth_stochastic = rollout(W, stochastic)
    truth_pulse = rollout(W, pulse)
    truth_release = rollout(W, release, nonlinear=True)
    truth_nonlinear_pulse = rollout(W, pulse, nonlinear=True)
    candidates = {"reference": W, "dense_fp16": W.astype(np.float16).astype(np.float64),
                  "one_step": local, "same_codes_scale_search": same_rate,
                  "whole_codebook_scale_search": global_oracle, "one_fp16_exception": exception}
    output = {
        "setup": {"W": W.tolist(), "gate": GATE, "input": B.tolist(), "sigma": SIGMA,
                  "horizon": HORIZON, "seed": 20260923,
                  "fit": "isotropic Frobenius; exact infinite-horizon white-noise objective, enumerated trits and multi-start continuous scale search, then FP16 rounding",
                  "nonlinear_probe": "tanh recurrence; +.005 input for 32 steps, then zero for 480"},
        "codes": {"one_step": local_code.astype(int).tolist(), "whole_codebook_scale_search": global_code.astype(int).tolist()},
        "scales": {"one_step": local_scale.tolist(), "same_codes_scale_search": scale.tolist(),
                   "whole_codebook_scale_search": global_scale.tolist()},
        "candidates": {name: summary(w, stochastic, pulse, release, truth_stochastic, truth_pulse, truth_release, truth_nonlinear_pulse)
                       for name, w in candidates.items()},
        "search_values": {"same_codes": scale_loss, "all_codes": global_loss},
        "storage_bits": {"dense_fp16": 64, "ternary_two_fp16_scales": 39,
                         "exception_one_fp16_and_two_bit_position": 57},
    }
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(output, indent=2) + "\n")
    print(json.dumps({name: {k: value for k, value in row.items() if k not in ("matrix", "pulse_final", "constant_input_fixed_point_if_stable", "nonlinear_release_final")}
                      for name, row in output["candidates"].items()}, indent=2))
    print("wrote", path)


if __name__ == "__main__":
    main()
