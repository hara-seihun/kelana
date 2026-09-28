#!/usr/bin/env python3
"""Small exhaustive scalar control for an instruction-shaped one-dot map."""

import itertools
import json
from fractions import Fraction

import numpy as np


CODES = np.array(list(itertools.product(range(-8, 8), repeat=4)), dtype=np.int64)
NORMS = 2 * np.sum(CODES * CODES, axis=1) + 3 * np.sum(CODES, axis=1) ** 2


def energy(vector):
    return (2 / 3) * float(vector @ vector) + float(sum(vector) ** 2)


def scalar_row(row):
    integer_row = np.rint(64 * row).astype(np.int64)
    assert np.array_equal(integer_row / 64, row)
    projections = 2 * (CODES @ integer_row) + 3 * CODES.sum(axis=1) * integer_row.sum()
    row_norm = 2 * (integer_row @ integer_row) + 3 * integer_row.sum() ** 2
    positive = NORMS > 0
    numerators = row_norm * NORMS[positive] - projections[positive] ** 2
    denominators = NORMS[positive]
    approximate = numerators / denominators
    candidate = int(np.argmin(approximate))
    assert np.all(numerators * denominators[candidate] >= numerators[candidate] * denominators)
    index = np.flatnonzero(positive)[candidate]
    loss = Fraction(int(numerators[candidate]), int(3 * 64 ** 2 * denominators[candidate]))
    scale = Fraction(int(projections[index]), int(64 * NORMS[index]))
    return {"codes": CODES[index].tolist(), "ideal_scale": str(scale), "loss_exact": str(loss), "loss": float(loss)}


def panel(name, teacher, code, decoder):
    estimate = np.outer(decoder, code)
    identity = np.eye(4)
    root = np.sqrt(2 / 3) * identity + (np.sqrt(14 / 3) - np.sqrt(2 / 3)) * np.ones((4, 4)) / 4
    singular = np.linalg.svd(teacher @ root, compute_uv=False)
    return {
        "name": name,
        "teacher": teacher.tolist(),
        "one_dot_codes": code.tolist(),
        "one_dot_fp16_decoder": decoder.tolist(),
        "one_dot_loss": sum(energy(row) for row in teacher - estimate),
        "scalar_q4_ideal_real_scales": [scalar_row(row) for row in teacher],
        "any_rank_one_input_mse_lower_bound": float(singular[-1] ** 2),
    }


def main():
    code = np.array([1, 3, 9, 27], dtype=np.float64)
    perturb = np.array([0, 1, -1, 2], dtype=np.float64) / 64
    near = np.array([code, 0.75 * code + perturb])
    far = np.array([code, [7, -4, 13, -2]], dtype=np.float64)
    result = [
        panel("near_rank_one", near, code, np.array([1, 0.75])),
        panel("noncollinear_control", far, code, np.array([1, 0.75])),
    ]
    for item in result:
        item["scalar_q4_loss"] = sum(row["loss"] for row in item["scalar_q4_ideal_real_scales"])
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
