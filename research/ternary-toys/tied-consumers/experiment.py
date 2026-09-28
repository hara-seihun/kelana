"""Closed-form tied-head gauge recovery and exhaustive tiny code controls."""

import itertools
import json
from pathlib import Path

import numpy as np
from scipy.optimize import minimize, minimize_scalar
from scipy.special import logsumexp


CODES = np.array(list(itertools.product((-1, 0, 1), repeat=2)), dtype=np.float64)
BODY_CODES = np.array(list(itertools.product((-1, 0, 1), repeat=4)), dtype=np.float64)


def row_quantize(row):
    candidates = []
    for code in CODES:
        norm = code @ code
        if not norm:
            candidates.append((float(row @ row), tuple(code.astype(int)), 0.0))
            continue
        scale = max(0.0, (row @ code) / norm)
        candidates.append((float(np.sum((row - scale * code) ** 2)), tuple(code.astype(int)), scale))
    error, code, scale = min(candidates)
    return np.array(code), scale, error


def mean_kl(reference, logits):
    logp = reference - logsumexp(reference, axis=1, keepdims=True)
    logq = logits - logsumexp(logits, axis=1, keepdims=True)
    return float(np.mean(np.sum(np.exp(logp) * (logp - logq), axis=1)))


def fit_free_body(embedding, teacher):
    probabilities = np.exp(teacher - logsumexp(teacher, axis=1, keepdims=True))

    def objective(flat):
        logits = embedding @ flat.reshape(2, 2) @ embedding.T
        logq = logits - logsumexp(logits, axis=1, keepdims=True)
        q = np.exp(logq)
        value = -np.mean(np.sum(probabilities * logq, axis=1))
        gradient = embedding.T @ (q - probabilities) @ embedding / len(embedding)
        return value, gradient.ravel()

    result = minimize(objective, np.zeros(4), jac=True, method="BFGS", options={"gtol": 1e-12})
    return result.x.reshape(2, 2), float(np.linalg.norm(result.jac))


def fit_ternary_body(embedding, teacher):
    best = (float("inf"), None, None)
    for code in BODY_CODES:
        matrix = code.reshape(2, 2)
        logits = embedding @ matrix @ embedding.T
        if not np.any(logits):
            continue
        # Wider than any competitive logit scale here. Boundary solutions are rejected.
        result = minimize_scalar(lambda scale: mean_kl(teacher, scale * logits),
                                 bounds=(0, 8), method="bounded",
                                 options={"xatol": 1e-12})
        if result.fun < best[0]:
            best = (float(result.fun), matrix.astype(int).tolist(), float(result.x))
    return best


def run():
    code = np.array([[1, 0], [0, 1], [1, 1], [1, -1], [-1, 1], [-1, -1]], dtype=np.float64)
    shear = np.array([[1, 1], [0, 1]], dtype=np.float64)
    gain = 1.25
    teacher_embedding = code @ shear
    teacher_body = gain * np.linalg.inv(shear) @ np.linalg.inv(shear).T
    teacher_logits = teacher_embedding @ teacher_body @ teacher_embedding.T

    rows = [row_quantize(row) for row in teacher_embedding]
    standalone_codes = np.array([entry[0] for entry in rows])
    standalone_scales = np.array([entry[1] for entry in rows])
    standalone = standalone_codes * standalone_scales[:, None]

    # Anchor rows are (1,0) and (0,1) in the *joint* gauge. Their 2x2 logit
    # block reveals gain; the remaining two columns reveal every ternary row.
    anchor = teacher_logits[:2, :2]
    recovered = teacher_logits[:, :2] @ np.linalg.inv(anchor)
    recovered_rounded = np.rint(recovered).astype(int)
    assert np.allclose(recovered, recovered_rounded, atol=1e-12)
    assert np.array_equal(recovered_rounded, code)
    joint_logits = recovered @ anchor @ recovered.T
    assert np.allclose(joint_logits, teacher_logits, atol=1e-12)

    free_body, gradient_norm = fit_free_body(standalone, teacher_logits)
    free_logits = standalone @ free_body @ standalone.T
    ternary_kl, ternary_codes, ternary_scale = fit_ternary_body(standalone, teacher_logits)

    centering = np.eye(len(code)) - np.ones((len(code), len(code))) / len(code)
    centered_standalone = centering @ standalone
    projection = centered_standalone @ np.linalg.pinv(centered_standalone)
    centered_teacher = centering @ teacher_logits @ centering
    obstruction = np.linalg.norm((np.eye(len(code)) - projection) @ centered_teacher)

    output = {
        "teacher": {"embedding": teacher_embedding.astype(int).tolist(),
                    "body": teacher_body.tolist(), "gain": gain,
                    "logits": teacher_logits.tolist()},
        "standalone": {"codes": standalone_codes.astype(int).tolist(),
                       "row_scales": standalone_scales.tolist(),
                       "embedding_squared_error": float(sum(entry[2] for entry in rows)),
                       "body_ternary_codes": ternary_codes,
                       "body_ternary_scale": ternary_scale,
                       "body_ternary_teacher_kl": ternary_kl,
                       "free_body": free_body.tolist(),
                       "free_body_gradient_norm": gradient_norm,
                       "free_body_teacher_kl": mean_kl(teacher_logits, free_logits),
                       "centered_column_space_obstruction_frobenius": float(obstruction)},
        "joint": {"codes": recovered_rounded.tolist(), "row_scales": [1] * len(code),
                  "body_codes": [[1, 0], [0, 1]], "body_scale": gain,
                  "embedding_squared_error": float(np.sum((teacher_embedding - code) ** 2)),
                  "teacher_kl": mean_kl(teacher_logits, joint_logits)},
        "payload_bytes_each_fixed_radix243": 18,
    }
    return output


if __name__ == "__main__":
    result = run()
    target = Path(__file__).with_name("results.json")
    target.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"standalone_ternary_kl": result["standalone"]["body_ternary_teacher_kl"],
                      "standalone_free_body_kl": result["standalone"]["free_body_teacher_kl"],
                      "joint_kl": result["joint"]["teacher_kl"],
                      "centered_obstruction": result["standalone"]["centered_column_space_obstruction_frobenius"]}, indent=2))
