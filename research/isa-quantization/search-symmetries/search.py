#!/usr/bin/env python3
"""Exact four-input joint quantizer/program search; no external dependencies."""

from itertools import product
import json

INPUTS = tuple(range(4))
FEATURES = (0, 1, 2)  # zero, input bit 0, input bit 1
OPS = tuple((kind, lane) for kind in ("xor", "mix", "meet") for lane in (0, 1))
MAX_STEPS = 3


def swap_word(word):
    return ((word & 1) << 1) | (word >> 1)


def swap_state(state):
    return tuple(map(swap_word, state))


def quantizer(features):
    return tuple(sum((((x >> (f - 1)) & 1) if f else 0) << lane
                     for lane, f in enumerate(features)) for x in INPUTS)


def execute(word, op):
    kind, lane = op
    bit = (word >> lane) & 1
    other = (word >> (1 - lane)) & 1
    if kind == "xor":
        value = bit ^ 1
    elif kind == "mix":
        value = bit ^ other
    else:
        value = bit & other
    return (word & ~(1 << lane)) | (value << lane)


def step(state, op):
    return tuple(execute(word, op) for word in state)


def observe(state, port):
    return tuple((word >> port) & 1 for word in state)


def charge(features):
    return sum(f != 0 for f in features)


def dominated(points):
    """Pareto minima in (static symbols, dynamic instructions, errors)."""
    return sorted(p for p in points if not any(
        q != p and all(a <= b for a, b in zip(q, p)) for q in points))


def candidates():
    """Raw labeled objects, including program sequences with identical maps."""
    for fs in product(FEATURES, repeat=2):
        start = quantizer(fs)
        for length in range(MAX_STEPS + 1):
            for program in product(OPS, repeat=length):
                state = start
                for op in program:
                    state = step(state, op)
                for port in (0, 1):
                    yield fs, program, port, state


def orbit_key(fs, program, port):
    ordinary = (fs, program, port)
    swapped = ((fs[1], fs[0]), tuple((kind, 1 - lane)
                 for kind, lane in program), 1 - port)
    return min(ordinary, swapped)


def dynamic_program():
    """State keys retain exact numerical bits, not merely output fibers."""
    layers = []
    current = {}
    for fs in product(FEATURES, repeat=2):
        state = quantizer(fs)
        key = min(state, swap_state(state))
        current[key] = min(current.get(key, 3), charge(fs))
    for depth in range(MAX_STEPS + 1):
        # A lower-cost, shorter prefix at the same state has every continuation.
        live = {state: q for state, q in current.items()
                if not any(state in previous and previous[state] <= q
                           for previous in layers)}
        layers.append(live)
        if depth == MAX_STEPS:
            break
        following = {}
        for state, q in live.items():
            for op in OPS:
                next_state = step(state, op)
                key = min(next_state, swap_state(next_state))
                following[key] = min(following.get(key, 3), q)
        current = following
    return layers


def loss(state, port, target):
    return sum(a != b for a, b in zip(observe(state, port), target))


def point_set(items, target):
    return {(q, depth, loss(state, port, target))
            for q, depth, state, port in items}


def main():
    for fs in product(FEATURES, repeat=2):
        assert quantizer(fs[1::-1]) == swap_state(quantizer(fs))
        assert charge(fs[1::-1]) == charge(fs)
    for word in range(4):
        for kind, lane in OPS:
            op = (kind, lane)
            assert execute(swap_word(word), (kind, 1 - lane)) == swap_word(execute(word, op))
            for port in (0, 1):
                assert ((swap_word(word) >> (1 - port)) & 1) == ((word >> port) & 1)
    raw = list(candidates())
    orbits = {orbit_key(fs, program, port) for fs, program, port, _ in raw}
    layers = dynamic_program()
    brute = [(charge(fs), len(program), state, port)
             for fs, program, port, state in raw]
    reduced = [(q, depth, state, port)
               for depth, layer in enumerate(layers)
               for state, q in layer.items() for port in (0, 1)]
    canonical = [(charge(fs), len(program), state, port)
                 for fs, program, port, state in raw
                 if (fs, program, port) == orbit_key(fs, program, port)]
    # Symmetry maps the swapped quantizer and word back to the same response.
    assert len(orbits) == len(raw) // 2
    assert len(canonical) == len(orbits)
    reports = {}
    for name, target in (('parity', (0, 1, 1, 0)),
                         ('and', (0, 0, 0, 1)),
                         ('or', (0, 1, 1, 1))):
        full = dominated(point_set(brute, target))
        gauge = dominated(point_set(canonical, target))
        dp = dominated(point_set(reduced, target))
        assert full == gauge == dp, (name, full, gauge, dp)
        reports[name] = [list(p) for p in full]
    # All sixteen targets, not just the three reported ones, exercise the proof.
    for target in product((0, 1), repeat=4):
        expected = dominated(point_set(brute, target))
        assert expected == dominated(point_set(canonical, target))
        assert expected == dominated(point_set(reduced, target))
    print(json.dumps({"domain": 4, "quantizers": len(FEATURES) ** 2,
                      "ops": len(OPS), "max_steps": MAX_STEPS,
                      "labeled_complete_objects": len(raw),
                      "exact_gauge_orbits": len(orbits),
                      "live_numeric_state_keys_by_depth": [len(x) for x in layers],
                      "live_numeric_labels_total": sum(map(len, layers)),
                      "pareto_static_online_error": reports}, indent=2))


if __name__ == '__main__':
    main()
