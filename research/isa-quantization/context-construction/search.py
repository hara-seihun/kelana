#!/usr/bin/env python3
"""Backward context-width DP, exact exhaustive control and separator failure."""
import itertools
import json
from collections import defaultdict
from functools import lru_cache
from pathlib import Path

HORIZON = 4
ASSETS = ("a", "b", "c")
# A and B are model-specific reusable assets; C is paid by some prefixes but
# no remaining instruction uses it. Every identity has one byte of payload.
ACTIONS = (("plain", 0, 1, 0), ("use_a", 1, 0, 1), ("use_b", 2, 0, 1))


def initial_state(seed):
    return tuple(seed ^ (x << 4) for x in range(4))


def alpha(h, state):
    return tuple((value >> h) & 3 for value in state)


def transition(state, high):
    return tuple((value >> 1) | (high << 7) for value in state)


def skyline(pairs):
    pairs = tuple(pairs)
    return tuple(sorted({p for p in pairs if not any(
        q != p and q[0] <= p[0] and q[1] <= p[1] for q in pairs)}))


@lru_cache(None)
def abstract_dp(h, label, paid_future):
    if h == 0:
        return ((0, 0),)
    options = []
    for _, used, work, _ in ACTIONS:
        extra = (used & ~paid_future).bit_count()
        for later_bytes, later_work in abstract_dp(
                h - 1, label, (paid_future | used) & (3 if h > 1 else 0)):
            options.append((extra + later_bytes, work + later_work))
    return skyline(options)


def brute(state, paid):
    outcomes = []
    for word in itertools.product(ACTIONS, repeat=HORIZON):
        live = state
        used_total = paid
        work = 0
        for _, used, cost, high in word:
            live = transition(live, high)
            used_total |= used
            work += cost
        outcomes.append((alpha(0, live), used_total.bit_count(), work))
    responses = {response for response, _, _ in outcomes}
    if len(responses) != 1:
        raise AssertionError("proposed separator changed observed response")
    response = responses.pop()
    return response, skyline((static, work) for _, static, work in outcomes)


def dynamic(state, paid):
    label = alpha(HORIZON, state)
    return label, skyline((paid.bit_count() + extra, work)
                          for extra, work in abstract_dp(HORIZON, label, paid & 3))


def main():
    # This verifies the *one-step congruence* rather than merely coincident
    # terminal observations. The future-high bit never reaches the observed
    # two low bits within this horizon.
    for h in range(1, HORIZON + 1):
        for seed in range(256):
            state = initial_state(seed)
            for _, _, _, high in ACTIONS:
                assert alpha(h - 1, transition(state, high)) == alpha(h, state)
    nodes = 0
    signatures = defaultdict(list)
    for seed in range(256):
        state = initial_state(seed)
        for paid in range(8):
            compact = dynamic(state, paid)
            assert compact == brute(state, paid), (seed, paid, compact, brute(state, paid))
            signatures[compact].append((seed, paid))
            nodes += 1

    # A legal instruction which exposes a forgotten bit destroys the separator.
    # alpha_1(0)=alpha_1(1), but the probe's low two bits differ at the endpoint.
    def probe(value):
        return (value >> 1) ^ ((value & 1) << 1)
    assert ((0 >> 1) & 3) == ((1 >> 1) & 3)
    assert (probe(0) & 3) != (probe(1) & 3)

    # A sufficient same-word separator is not the maximal residual quotient:
    # identity/flip instructions interchange the two suffix witnesses.
    residual_zero = {(0 ^ action, 0, 1) for action in (0, 1)}
    residual_one = {(1 ^ action, 0, 1) for action in (0, 1)}
    assert residual_zero == residual_one
    assert (0 ^ 0) != (1 ^ 0)

    result = {
        "domain": "256 four-input byte-state maps, eight paid-asset subsets, horizon 4",
        "all_prefixes": nodes,
        "possible_suffix_words_per_prefix": len(ACTIONS) ** HORIZON,
        "brute_suffix_executions": nodes * len(ACTIONS) ** HORIZON,
        "memoized_abstract_subproblems": abstract_dp.cache_info().currsize,
        "separator_classes_at_initial_stage": len(signatures),
        "all_2048_frontiers_match_exhaustive": True,
        "future_assets": ["a", "b"],
        "ignored_in_profile_but_charged_in_base": ["c"],
        "sample_paid_a": dynamic(initial_state(0), 1),
        "sample_paid_b": dynamic(initial_state(0), 2),
        "sample_paid_c": dynamic(initial_state(0), 4),
        "probe_failure": {"states": [0, 1], "equal_alpha_1": 0,
                          "probe_outputs": [probe(0) & 3, probe(1) & 3]},
        "suffix_substitution": {"distinct_states": [0, 1],
                                "actions": ["identity", "flip"],
                                "equal_residual_outcomes": sorted(residual_zero),
                                "same_action_outputs_differ": True},
    }
    Path(__file__).with_name("results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({key: result[key] for key in
                      ("all_prefixes", "brute_suffix_executions",
                       "memoized_abstract_subproblems", "separator_classes_at_initial_stage")}))


if __name__ == "__main__":
    main()
