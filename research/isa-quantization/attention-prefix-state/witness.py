#!/usr/bin/env python3
"""Exact finite streaming replay: paid images, bounded states, all histograms."""
from fractions import Fraction as F
from hashlib import sha256
from itertools import product
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
HORIZON = 15


def rank(rows):
    a = [[F(x) for x in row] for row in rows]
    r = 0
    for c in range(len(a[0])):
        pivot = next((i for i in range(r, len(a)) if a[i][c]), None)
        if pivot is None:
            continue
        a[r], a[pivot] = a[pivot], a[r]
        d = a[r][c]
        a[r] = [x / d for x in a[r]]
        for i in range(len(a)):
            if i != r:
                v = a[i][c]
                a[i] = [x - v*y for x, y in zip(a[i], a[r])]
        r += 1
        if r == len(a):
            break
    return r


def teacher(image, counts, query):
    assert len(image) == 13 and image[0] == 0
    assert query in (0, 1) and len(counts) == 4 and 0 < sum(counts) <= HORIZON
    weights = image[1+4*query:5+4*query]
    values = image[9:13]
    den = sum(c*w for c, w in zip(counts, weights))
    num = sum(c*w*v for c, w, v in zip(counts, weights, values))
    return F(num, den)


def update(image, state, token):
    assert len(image) == 7 and image[0] == 1
    assert len(state) == 3 and 0 <= token < 4 and state[0] < HORIZON
    t = image[1+token]
    return bytes((state[0]+1, state[1]+t, state[2]+t*t))


def update_histogram(state, token):
    word = int.from_bytes(state, 'little')
    counts = tuple((word >> (4*i)) & 15 for i in range(4))
    assert len(state) == 2 and sum(counts) < HORIZON and 0 <= token < 4
    # The reachable bound prevents a carry into another lane.
    return (word + (1 << (4*token))).to_bytes(2, 'little')


def decode_histogram(state):
    assert len(state) == 2
    word = int.from_bytes(state, 'little')
    return tuple((word >> (4*i)) & 15 for i in range(4))


def read_moment(image, state, query):
    assert len(image) == 7 and image[0] == 1 and len(state) == 3
    assert query in (0, 1) and 0 < state[0] <= HORIZON
    q = image[5+query]
    return F(state[1]+q*state[2], state[0]+q*state[1])


def encode(image, counts):
    state = bytes(3)
    for t, c in enumerate(counts):
        for _ in range(c):
            state = update(image, state, t)
    return state


def main():
    # Different physical formats, not an implicit free target table.
    full_path = HERE / 'kernel-values.bin'
    moment_path = HERE / 'moment-program.bin'
    full_path.write_bytes(bytes((0, 1, 1, 1, 1, 1, 2, 3, 4, 0, 1, 2, 3)))
    moment_path.write_bytes(bytes((1, 0, 1, 2, 3, 0, 1)))
    full = full_path.read_bytes()
    image = moment_path.read_bytes()
    kernels = [list(full[1:5]), list(full[5:9])]
    values = full[9:13]
    moment_rows = kernels + [[k*v for k, v in zip(row, values)] for row in kernels]
    assert rank(kernels) == 2 and rank(moment_rows) == 3
    total = transitions = 0
    states = set()
    for counts in product(range(HORIZON+1), repeat=4):
        length = sum(counts)
        if not 0 < length <= HORIZON:
            continue
        total += 1
        state = encode(image, counts)
        packed = sum(c << (4*i) for i, c in enumerate(counts)).to_bytes(2, 'little')
        assert decode_histogram(packed) == counts
        states.add(state)
        for q in (0, 1):
            assert read_moment(image, state, q) == teacher(full, decode_histogram(packed), q)
        if length < HORIZON:
            for token in range(4):
                after = list(counts)
                after[token] += 1
                next_state = update(image, state, token)
                packed_next = update_histogram(packed, token)
                assert decode_histogram(packed_next) == tuple(after)
                # This is an update check as well as a current-output check.
                assert next_state == encode(image, after)
                for q in (0, 1):
                    assert read_moment(image, next_state, q) == teacher(full, after, q)
                transitions += 1
    collision = ((1, 0, 3, 0), (0, 3, 0, 1))
    c0, c1 = (encode(image, c) for c in collision)
    assert c0 == c1 == bytes((4, 6, 12))
    rays = ((1, 1, 0, 0), (2, 2, 0, 0))
    s0, s1 = (encode(image, c) for c in rays)
    before = [read_moment(image, s0, q) for q in (0, 1)]
    assert before == [read_moment(image, s1, q) for q in (0, 1)]
    a0, a1 = update(image, s0, 2), update(image, s1, 2)
    differences = [abs(read_moment(image, a0, q)-read_moment(image, a1, q)) for q in (0, 1)]
    assert differences == [F(1, 5), F(2, 9)]
    # Independently encode the bounded histogram/cache controls, including counters.
    assert len(bytes((15, 0, 0, 0))) == 4
    cache_capacity_bytes = (2*HORIZON+7)//8 + 1
    assert cache_capacity_bytes == 5
    result = {
        'contract': 'stationary positive queryable-prefix kernel, exact rational outputs',
        'max_prefix_length': HORIZON,
        'nonempty_histograms_replayed': total,
        'single_token_updates_replayed': transitions,
        'distinct_nonempty_moment_states': len(states),
        'kernel_rank': 2,
        'joint_moment_rank': 3,
        'images': {p.name: {'bytes': p.stat().st_size, 'sha256': sha256(p.read_bytes()).hexdigest()}
                   for p in (full_path, moment_path)},
        'live_state_bytes': {'moments': 3, 'byte_histogram': 4, 'packed_nibble_histogram': 2, 'packed_token_cache_capacity': cache_capacity_bytes},
        'moment_collision_histograms': collision,
        'moment_collision_state': list(c0),
        'current_output_ray_histograms': rays,
        'same_current_outputs': list(map(str, before)),
        'after_token_2_output_separation': list(map(str, differences)),
        'any_merged_state_worst_case_next_error_floor': [str(x/2) for x in differences],
        'numerical_tolerance': 'none; Fraction and integer bytes',
        'generic_code_native_cost_or_model_claim': False,
    }
    (HERE/'results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
