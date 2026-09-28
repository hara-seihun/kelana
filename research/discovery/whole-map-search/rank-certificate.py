#!/usr/bin/env python3
"""Exact certificate for the three-trit gated ReLU family's 19-dimensional span."""

from itertools import product

P = 1_000_003
TRITS = (-1, 0, 1)
STATES = tuple(product(TRITS, repeat=3))
REPS = tuple(x for x in STATES if next((v for v in x if v), 0) == 1)
AXES = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
PAIRS = ((1, 1, 0), (1, 0, 1), (0, 1, 1))
SAMPLES = REPS + tuple(tuple(-a for a in x) for x in AXES + PAIRS)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def atom(g, u, x):
    return max(0, dot(g, x)) * dot(u, x)


def reconstruct(samples):
    """Recover all 27 entries from 19 samples using the reflection quadratic."""
    at = dict(zip(SAMPLES, samples, strict=True))
    sums = {x: at[x] + at[tuple(-v for v in x)] for x in AXES + PAIRS}
    cross = {
        (0, 1): sums[PAIRS[0]] - sums[AXES[0]] - sums[AXES[1]],
        (0, 2): sums[PAIRS[1]] - sums[AXES[0]] - sums[AXES[2]],
        (1, 2): sums[PAIRS[2]] - sums[AXES[1]] - sums[AXES[2]],
    }
    def quadratic(x):
        return sum(sums[AXES[i]] * x[i] * x[i] for i in range(3)) + sum(
            cross[i, j] * x[i] * x[j] for i, j in cross
        )
    for x in REPS:
        at[tuple(-v for v in x)] = quadratic(x) - at[x]
    at[(0, 0, 0)] = 0
    return tuple(at[x] for x in STATES)


def rank(columns):
    """Modular rank of column vectors, with stable first-independent selection."""
    pivots = {}
    chosen = []
    for label, column in columns:
        vec = [v % P for v in column]
        for pos, basis in sorted(pivots.items()):
            if vec[pos]:
                mul = vec[pos]
                vec = [(a - mul * b) % P for a, b in zip(vec, basis)]
        pos = next((i for i, v in enumerate(vec) if v), None)
        if pos is None:
            continue
        inv = pow(vec[pos], -1, P)
        pivots[pos] = [(v * inv) % P for v in vec]
        chosen.append(label)
    return chosen, tuple(sorted(pivots))


def determinant(rows):
    mat = [[v % P for v in row] for row in rows]
    det = 1
    for i in range(len(mat)):
        pivot = next((r for r in range(i, len(mat)) if mat[r][i]), None)
        if pivot is None:
            return 0
        if pivot != i:
            mat[i], mat[pivot] = mat[pivot], mat[i]
            det = -det
        val = mat[i][i]
        det = det * val % P
        inv = pow(val, -1, P)
        for r in range(i + 1, len(mat)):
            factor = mat[r][i] * inv % P
            for c in range(i, len(mat)):
                mat[r][c] = (mat[r][c] - factor * mat[i][c]) % P
    return det % P


def main():
    vectors = tuple(x for x in STATES if any(x))
    atoms = ((g, u) for g in vectors for u in vectors)
    selected, pivots = rank(((g, u), tuple(atom(g, u, x) for x in SAMPLES)) for g, u in atoms)
    assert len(selected) == 19 and len(pivots) == 19
    rows = [[atom(g, u, x) for g, u in selected] for x in SAMPLES]
    det = determinant(rows)
    assert det != 0
    for g in vectors:
        for u in vectors:
            actual = tuple(atom(g, u, x) for x in STATES)
            assert reconstruct(tuple(atom(g, u, x) for x in SAMPLES)) == actual
    print(f"states={len(STATES)} representatives={len(REPS)} samples={len(SAMPLES)} atoms={len(vectors)**2}")
    print(f"rank mod {P}={len(selected)} determinant mod {P}={det}")
    print("independent gate/up atoms:")
    for g, u in selected:
        print(f"  g={g} u={u}")
    print("all 676 atoms reconstructed at all 27 states")


if __name__ == "__main__":
    main()
