"""Exact one-trit coding of a four-state softmax producer and its continuation."""

from __future__ import annotations

import itertools
import json
import math
from pathlib import Path

WEIGHTS = (0.7, 0.3)
STATES = tuple(itertools.product((-2.0, 2.0), (-1.5, 1.5)))
# Each state is (current logit gap m, common-mode coordinate c).
# z = (c+m/2, c-m/2), A = diag(1,-1); D z = m, D A z = 2c.


def sigmoid(t: float) -> float:
    return 1.0 / (1.0 + math.exp(-t))


def logit(p: float) -> float:
    return math.log(p / (1.0 - p))


def kl(p: float, q: float) -> float:
    return p * math.log(p / q) + (1.0 - p) * math.log((1.0 - p) / (1.0 - q))


def logits(state: tuple[float, float]) -> tuple[float, float]:
    m, c = state
    return (c + m / 2.0, c - m / 2.0)


def canonical_partitions(k: int):
    for labels in itertools.product(range(k), repeat=len(STATES)):
        if labels[0] != 0 or set(labels) != set(range(k)):
            continue
        first_occurrences = tuple(labels.index(i) for i in range(k))
        if first_occurrences == tuple(sorted(first_occurrences)):
            yield labels


def fit(labels: tuple[int, ...], criterion: str) -> dict:
    codebook = {}
    for code in set(labels):
        points = [STATES[i] for i, label in enumerate(labels) if label == code]
        if criterion == "raw-logit-mse":
            z = [sum(logits(s)[j] for s in points) / len(points) for j in range(2)]
        else:
            first = sum(sigmoid(m) for m, _ in points) / len(points)
            second = sum(sigmoid(2.0 * c) for _, c in points) / len(points)
            m_hat, c_hat = logit(first), logit(second) / 2.0
            z = [c_hat + m_hat / 2.0, c_hat - m_hat / 2.0]
        codebook[code] = z
    excess = [0.0, 0.0]
    accuracy = [0.0, 0.0]
    mse = 0.0
    for i, (m, c) in enumerate(STATES):
        z = codebook[labels[i]]
        original = logits((m, c))
        mse += sum((z[j] - original[j]) ** 2 for j in range(2)) / len(STATES)
        for t, (truth, inferred) in enumerate(((m, z[0] - z[1]), (2.0 * c, z[0] + z[1]))):
            excess[t] += kl(sigmoid(truth), sigmoid(inferred)) / len(STATES)
            accuracy[t] += (1.0 if (truth > 0) == (inferred > 1e-12) else 0.0) / len(STATES)
    return {
        "labels": list(labels),
        "codebook": [[round(value, 10) for value in codebook[i]] for i in sorted(codebook)],
        "excess_nll": excess,
        "weighted_excess_nll": sum(w * x for w, x in zip(WEIGHTS, excess)),
        "top1_agreement": accuracy,
        "raw_logit_mse": mse,
    }


def optimal(k: int, criterion: str) -> dict:
    candidates = [fit(labels, criterion) for labels in canonical_partitions(k)]
    key = "raw_logit_mse" if criterion == "raw-logit-mse" else "weighted_excess_nll"
    return min(candidates, key=lambda candidate: (candidate[key], candidate["labels"]))


def main() -> None:
    pointwise_labels = tuple(0 if m < 0 else 1 for m, _ in STATES)
    # 2u+v has values -3,-1,+1,+3. Thresholds -2 and 0 give
    # (-1,-1)->-1, (-1,+1)->0, (+1,-1)/(+1,+1)->+1.
    affine_labels = tuple(0 if 2*m/2+c/1.5 < -2 else
                          1 if 2*m/2+c/1.5 < 0 else 2 for m, c in STATES)
    mse_affine_labels = tuple(0 if 2*c/1.5+m/2 < 0 else
                              1 if 2*c/1.5+m/2 < 2 else 2 for m, c in STATES)
    results = {
        "states_m_c": STATES,
        "stage_weights": WEIGHTS,
        "continuation": "A=diag(1,-1); D=(1,-1)",
        "pointwise_one_trit": fit(pointwise_labels, "observed-nll"),
        "affine_threshold_one_trit": fit(affine_labels, "observed-nll"),
        "best_three_code_observed_nll": optimal(3, "observed-nll"),
        "best_three_code_raw_logit_mse": optimal(3, "raw-logit-mse"),
        "affine_raw_logit_mse": fit(mse_affine_labels, "raw-logit-mse"),
        "best_two_code_observed_nll": optimal(2, "observed-nll"),
        "exact_four_code": optimal(4, "observed-nll"),
    }
    assert abs(
        results["affine_threshold_one_trit"]["weighted_excess_nll"]
        - results["best_three_code_observed_nll"]["weighted_excess_nll"]
    ) < 1e-12
    assert abs(
        results["affine_raw_logit_mse"]["raw_logit_mse"]
        - results["best_three_code_raw_logit_mse"]["raw_logit_mse"]
    ) < 1e-12
    assert results["best_two_code_observed_nll"]["weighted_excess_nll"] > 0
    assert results["exact_four_code"]["weighted_excess_nll"] < 1e-12
    output = Path(__file__).with_name("results.json")
    output.write_text(json.dumps(results, indent=2) + "\n")
    print(f"Wrote {output}")
    for name in ("pointwise_one_trit", "affine_threshold_one_trit",
                 "best_three_code_raw_logit_mse", "exact_four_code"):
        item = results[name]
        print(name, "weighted excess NLL", round(item["weighted_excess_nll"], 9),
              "first/future top1", item["top1_agreement"], "labels", item["labels"])


if __name__ == "__main__":
    main()
