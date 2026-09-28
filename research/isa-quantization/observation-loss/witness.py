#!/usr/bin/env python3
"""Deterministic binary-softmax witnesses; only the Python standard library is needed."""

import json
import math


def softmax(logits):
    shift = max(logits)
    terms = [math.exp(value - shift) for value in logits]
    return [term / sum(terms) for term in terms]


def metrics(logits, delta, gold):
    p = softmax(logits)
    mean = sum(prob * edit for prob, edit in zip(p, delta))
    variance = sum(prob * (edit - mean) ** 2 for prob, edit in zip(p, delta))
    anchor = max(delta)
    log_partition = anchor + math.log(sum(prob * math.exp(edit - anchor) for prob, edit in zip(p, delta)))
    kl = log_partition - mean
    gold_increase = log_partition - delta[gold]
    spread = max(delta) - min(delta)
    if spread:
        upper = variance * math.expm1(spread) / spread**2 - variance / spread
        lower = variance * (spread + math.expm1(-spread)) / spread**2
        hoeffding = spread**2 / 8
    else:
        upper = lower = hoeffding = 0.0
    return {
        "p": p,
        "delta": delta,
        "coordinate_mse": sum(edit**2 for edit in delta) / len(delta),
        "teacher_variance": variance,
        "half_fisher": variance / 2,
        "teacher_kl_exact": kl,
        "teacher_kl_lower": lower,
        "teacher_kl_upper": min(upper, hoeffding),
        "gold_nll_increase": gold_increase,
    }


def main():
    logits = [math.log(99), 0.0]
    shift = metrics(logits, [0.8, 0.8], gold=0)
    rare = metrics(logits, [0, 1], gold=0)
    sharp_rare_gold = metrics([0, -20], [0, -10], gold=1)
    rare_positive_spike = metrics([0, -20], [0, 10], gold=1)
    future = metrics([0, 0], [10, 0], gold=1)
    assert shift["coordinate_mse"] > rare["coordinate_mse"]
    assert shift["teacher_kl_exact"] == 0
    assert rare["teacher_kl_exact"] > 0
    for case in (rare, sharp_rare_gold, rare_positive_spike, future):
        assert case["teacher_kl_lower"] - 1e-12 <= case["teacher_kl_exact"]
        assert case["teacher_kl_exact"] <= case["teacher_kl_upper"] + 1e-12
    print(json.dumps({
        "mse_reversal": {"common_shift": shift, "rare_logit": rare},
        "rare_gold": sharp_rare_gold,
        "rare_positive_spike": rare_positive_spike,
        "two_step_state": {
            "teacher_first_state": 0,
            "candidate_first_state": 1e-6,
            "first_step_logits_both": [0, 0],
            "second_step_gain": 1e7,
            "second_step": future,
        },
    }, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
