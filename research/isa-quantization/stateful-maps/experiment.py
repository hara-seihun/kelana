#!/usr/bin/env python3
"""One observed channel of a two-state linear recurrence; reproducible small search."""
import itertools
import json
from fractions import Fraction
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

CODES = tuple(itertools.product((-1, 0, 1), repeat=2))
HORIZON = 128


def impulse(matrix, horizon=HORIZON):
    state = np.array([1., 0.])
    out = np.empty(horizon)
    for i in range(horizon):
        out[i] = state[0]
        state = matrix @ state
    return out


def radius(matrix):
    return float(np.max(np.abs(np.linalg.eigvals(matrix))))


def row_fit(row, code):
    code = np.asarray(code)
    return max(0., float(np.dot(row, code) / np.dot(code, code))) if np.any(code) else 0.


def local(matrix):
    chosen = []
    for row in matrix:
        chosen.append(min(((float(np.sum((row - row_fit(row, code) * np.asarray(code)) ** 2)), code,
                            row_fit(row, code)) for code in CODES if any(code)), key=lambda v: v[0]))
    return np.array([np.array(c) * s for _, c, s in chosen]), [list(c) for _, c, _ in chosen], [s for _, _, s in chosen]


def objective(reference_impulse, code, scales):
    candidate = np.asarray(code, dtype=float) * np.asarray(scales)[:, None]
    if radius(candidate) >= 0.999:
        return 1e6 + 1e6 * (radius(candidate) - 0.999)
    delta = impulse(candidate) - reference_impulse
    return float(delta @ delta)


def joint_search(reference):
    ref_impulse = impulse(reference)
    best = None
    for code in itertools.product(CODES, repeat=2):
        code = np.asarray(code, dtype=float)
        fit = [row_fit(reference[i], code[i]) for i in range(2)]
        for start in (fit, [.5, .5], [1., 1.], [2., .5]):
            solution = minimize(lambda s: objective(ref_impulse, code, s), start,
                                bounds=((0., 2.5), (0., 2.5)), method="Nelder-Mead",
                                options={"maxiter": 110, "xatol": 1e-7, "fatol": 1e-11})
            scales = np.asarray(solution.x, dtype=np.float16).astype(float)
            value = objective(ref_impulse, code, scales)
            record = (value, tuple(tuple(map(int, row)) for row in code), tuple(map(float, scales)))
            if best is None or record < best:
                best = record
    score, code, scales = best
    return {"code": code, "scales_fp16": scales, "matrix": (np.asarray(code) * np.asarray(scales)[:, None]).tolist(),
            "finite_white_input_output_error_over_variance": score}


def rational_certificate():
    # z=(x_0,x_1/4), with B=(1,0), C=(1,0) in both representations.
    f = Fraction
    source = ((f(1, 2), f(1, 8)), (f(-2), f(1, 2)))
    encoded = ((f(1, 2), f(1, 2)), (f(-1, 2), f(1, 2)))
    e = (f(1), f(1, 4))
    assert all(encoded[i][j] * e[j] == e[i] * source[i][j] for i in range(2) for j in range(2))
    assert all(encoded[0][j] == f(1, 2) for j in range(2))
    return {"source": [[str(x) for x in row] for row in source],
            "encoded": [[str(x) for x in row] for row in encoded],
            "state_encoding_diagonal": [str(x) for x in e],
            "certificate": "encoded*E=E*source; E*B=B and C*E=C; exact for every input word and horizon"}


def measure(matrix):
    reference = impulse(matrix)
    local_matrix, local_code, local_scales = local(matrix)
    control = joint_search(matrix)
    returned = {}
    for name, candidate in (("coefficient_fit", local_matrix), ("all_codes_impulse_fit", np.array(control["matrix"]))):
        delta = impulse(candidate) - reference
        returned[name] = {"matrix": candidate.tolist(), "radius": radius(candidate),
                          "coefficient_frobenius_error": float(np.linalg.norm(candidate - matrix)),
                          "finite_white_input_output_error_over_variance": float(delta @ delta),
                          "first_four_impulses": impulse(candidate, 4).tolist()}
    returned["coefficient_fit"]["codes"] = local_code
    returned["coefficient_fit"]["scales"] = local_scales
    returned["all_codes_impulse_fit"]["codes"] = control["code"]
    returned["all_codes_impulse_fit"]["scales_fp16"] = control["scales_fp16"]
    returned["teacher"] = {"matrix": matrix.tolist(), "radius": radius(matrix),
                           "first_four_impulses": impulse(matrix, 4).tolist()}
    return returned


def main():
    exact = np.array([[.5, .125], [-2., .5]])
    rng = np.random.default_rng(20260924)
    perturbation = rng.uniform(-.025, .025, size=(2, 2))
    # The second teacher is a seeded perturbation, not constructed by a similarity.
    unstructured = rng.uniform(-.8, .8, size=(2, 2))
    while radius(unstructured) >= .95:
        unstructured = rng.uniform(-.8, .8, size=(2, 2))
    results = {"contract": {"state": "real 2-vector, initially zero", "input": "real scalar into coordinate 0",
                            "output": "coordinate 0 each step", "score": "sum of 128 squared impulse-output differences, equivalently white-input output error / input variance over 128 lags",
                            "scale_family": "nonnegative real per-row scale fitted by multistart Nelder-Mead across all 81 ternary 2x2 codes, then FP16-rounded",
                            "one_step_family": "all nine ternary row codes with individually least-squares fitted nonnegative real scales",
                            "fp16_rounding": "all-code search only; local LS scale values shown at ideal precision",
                            "stability": "search candidates must have spectral radius < .999"},
               "rational_certificate": rational_certificate(),
               "perturbation_seed": 20260924, "perturbation": perturbation.tolist(),
               "exact_teacher": measure(exact), "perturbed_teacher": measure(exact + perturbation),
               "unstructured_teacher": measure(unstructured)}
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps({key: {name: arm["finite_white_input_output_error_over_variance"] for name, arm in value.items() if "finite_white_input_output_error_over_variance" in arm}
                      for key, value in results.items() if key.endswith("teacher")}, indent=2))


if __name__ == "__main__":
    main()
