"""Exact shared two-coordinate lattice search and reproducible integer endpoint witness."""
import itertools
import json
import random
from pathlib import Path

PAIRS = 16
ROWS = 8  # Four experts, each with a gate and an up row, all using one input code.
DOMAIN = tuple((a, a + d) for a, d in itertools.product((-1, 0, 1), repeat=2))
rng = random.Random(20260924)
weights = [[[rng.randint(-63, 63), rng.randint(-63, 63)] for _ in range(PAIRS)] for _ in range(ROWS)]


def inverse(u):
    (a, b), (c, d) = u
    det = a * d - b * c
    return ((d // det, -b // det), (-c // det, a // det))


def transform(u, x):
    return tuple(sum(u[i][j] * x[j] for j in range(2)) for i in range(2))


def row_transform(row, u):
    v = inverse(u)
    return tuple(sum(row[j] * v[j][i] for j in range(2)) for i in range(2))


def dot(row, x):
    return sum(a * b for a, b in zip(row, x))


def bits(n):
    return (n - 1).bit_length()


candidates = []
for a, b, c, d in itertools.product(range(-2, 3), repeat=4):
    if abs(a * d - b * c) != 1:
        continue
    u = ((a, b), (c, d))
    ys = [transform(u, x) for x in DOMAIN]
    states = [len({y[i] for y in ys}) for i in range(2)]
    if any(n > 4 for n in states):
        continue
    if any(abs(w) > 127 for row in weights for pair in row for w in row_transform(pair, u)):
        continue
    candidates.append((sum(map(bits, states)), sum(states), sum(t != int(i == j) for i, r in enumerate(u) for j, t in enumerate(r)), u, states))
candidates.sort()
u = ((1, 0), (-1, 1))
assert any(item[3] == u for item in candidates)
assert min(item[0] for item in candidates) == 4
assert [len({transform(u, x)[i] for x in DOMAIN}) for i in range(2)] == [3, 3]
assert [len({x[i] for x in DOMAIN}) for i in range(2)] == [3, 5]

# Fixed signed-byte native dot semantics, including the input code's signed two-bit
# fields. Every expert consumes the very same decoded y array.
for row in weights:
    for pair in row:
        encoded = row_transform(pair, u)
        assert all(-128 <= w <= 127 for w in encoded)
        for x in DOMAIN:
            y = transform(u, x)
            assert all(-1 <= v <= 1 for v in y)
            assert dot(pair, x) == dot(encoded, y)

for _ in range(256):
    x = [rng.choice(DOMAIN) for _ in range(PAIRS)]
    y = [transform(u, pair) for pair in x]
    for row in weights:
        before = sum(dot(w, v) for w, v in zip(row, x))
        after = sum(dot(row_transform(w, u), v) for w, v in zip(row, y))
        assert before == after
        assert abs(after) <= PAIRS * 2 * 127  # signed 32-bit dot accumulation

# A rank-two first-pair witness is enough for the separable numeric-reader bound.
minor = next((i, j, weights[i][0][0] * weights[j][0][1] - weights[i][0][1] * weights[j][0][0])
             for i in range(ROWS) for j in range(i + 1, ROWS)
             if weights[i][0][0] * weights[j][0][1] != weights[i][0][1] * weights[j][0][0])
report = {
    "seed": 20260924, "pairs": PAIRS, "rows": ROWS, "domain_per_pair": [list(x) for x in DOMAIN],
    "common_input_transform": u, "inverse": inverse(u), "first_pair_rank_witness": minor,
    "searched_unimodular_matrices": sum(abs(a*d-b*c)==1 for a,b,c,d in itertools.product(range(-2,3), repeat=4)),
    "feasible_int8_two_bit_candidates": len(candidates), "best_field_bits_per_pair": min(t[0] for t in candidates),
    "chosen_field_bits_per_pair": 4, "original_exact_separable_field_bits_per_pair": 5,
    "chosen_dynamic_packed_bytes": PAIRS * 4 // 8, "original_dynamic_packed_bytes": PAIRS * 5 // 8,
    "static_weight_bytes_each": ROWS * PAIRS * 2,
    "transform_metadata_bytes": 4,
    "source_rows_first_pair": [r[0] for r in weights],
    "transformed_rows_first_pair": [row_transform(r[0], u) for r in weights],
    "sampled_full_endpoints": 256,
}
Path(__file__).with_name("results.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({k: report[k] for k in ("searched_unimodular_matrices", "feasible_int8_two_bit_candidates", "best_field_bits_per_pair", "first_pair_rank_witness")}, indent=2))
