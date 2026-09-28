"""Exact three-trit gated ReLU networks and the maps they realize.

The family fixed for this whole-map search:

    F(x) = sum_i c_i * relu(g_i . x) * (u_i . x)

with x in {-1,0,1}^3, g_i and u_i in {-1,0,1}^3 (ternary weights), c_i in
{-1,+1}, and integer arithmetic throughout. No bias, no output scale: the
network's observed result is the integer F(x) itself. Width h is a parameter
and is always reported with a result.

Everything here is exact. There is no floating point in the model, so every
claim about a map holds on all 27 inputs by construction, not by sampling.

Run `python3 model.py` for the structural report.
"""

from __future__ import annotations

import itertools
import json
import random
from fractions import Fraction
from typing import Iterable, List, Sequence, Tuple

TRITS = (-1, 0, 1)

# Lexicographic state order, x = (x0, x1, x2).
STATES: Tuple[Tuple[int, int, int], ...] = tuple(
    itertools.product(TRITS, repeat=3)
)
assert len(STATES) == 27


def balanced_index(x: Sequence[int]) -> int:
    """Balanced-ternary value of the input, shifted into 0..26.

    This is the address used by the two-instruction construction: the input's
    own arithmetic value in base 3, not a bit-packing of its encoding.
    """
    return 13 + x[0] + 3 * x[1] + 9 * x[2]


assert sorted(balanced_index(x) for x in STATES) == list(range(27))


def packed2(x: Sequence[int]) -> int:
    """Two-bit signed code per trit at bits 0,2,4: -1 -> 3, 0 -> 0, +1 -> 1.

    This is the input layout used by the existing two-trit observer result, so
    costs measured from it are comparable with that work.
    """
    code = {-1: 3, 0: 0, 1: 1}
    return code[x[0]] | (code[x[1]] << 2) | (code[x[2]] << 4)


PACKED2_WORDS: Tuple[int, ...] = tuple(packed2(x) for x in STATES)


def packed_bytes(x: Sequence[int]) -> int:
    """One signed byte per trit in lanes 0,1,2; lane 3 is zero."""
    return (x[0] & 0xFF) | ((x[1] & 0xFF) << 8) | ((x[2] & 0xFF) << 16)


class Network:
    """A fixed-weight gated ReLU network on three trits."""

    def __init__(
        self,
        gates: Sequence[Sequence[int]],
        ups: Sequence[Sequence[int]],
        signs: Sequence[int],
    ) -> None:
        assert len(gates) == len(ups) == len(signs)
        self.gates = [tuple(g) for g in gates]
        self.ups = [tuple(u) for u in ups]
        self.signs = [int(c) for c in signs]

    @property
    def width(self) -> int:
        return len(self.signs)

    def __call__(self, x: Sequence[int]) -> int:
        total = 0
        for g, u, c in zip(self.gates, self.ups, self.signs):
            pre = g[0] * x[0] + g[1] * x[1] + g[2] * x[2]
            if pre > 0:
                total += c * pre * (u[0] * x[0] + u[1] * x[1] + u[2] * x[2])
        return total

    def table(self) -> List[int]:
        """The complete map in lexicographic state order."""
        return [self(x) for x in STATES]

    def address_table(self) -> List[int]:
        """The complete map indexed by balanced_index, i.e. lane order."""
        out = [0] * 27
        for x in STATES:
            out[balanced_index(x)] = self(x)
        return out

    def to_json(self) -> dict:
        return {
            "width": self.width,
            "gates": self.gates,
            "ups": self.ups,
            "signs": self.signs,
            "table_lex": self.table(),
            "table_address": self.address_table(),
        }

    @staticmethod
    def random(width: int, rng: random.Random) -> "Network":
        vecs = [v for v in itertools.product(TRITS, repeat=3)]
        nonzero = [v for v in vecs if any(v)]
        gates = [rng.choice(nonzero) for _ in range(width)]
        ups = [rng.choice(vecs) for _ in range(width)]
        signs = [rng.choice((-1, 1)) for _ in range(width)]
        return Network(gates, ups, signs)


# ---------------------------------------------------------------------------
# Structure of the realizable maps
# ---------------------------------------------------------------------------

def monomial_basis() -> List[Tuple[int, int, int]]:
    """Exponent vectors of the reduced ring Q[x0,x1,x2]/(x^3 - x)."""
    return list(itertools.product((0, 1, 2), repeat=3))


def evaluate_monomial(e: Sequence[int], x: Sequence[int]) -> int:
    v = 1
    for ei, xi in zip(e, x):
        v *= xi ** ei
    return v


def rank(rows: Iterable[Sequence[Fraction]]) -> int:
    """Exact rational rank."""
    mat = [list(map(Fraction, r)) for r in rows]
    if not mat:
        return 0
    ncols = len(mat[0])
    r = 0
    for col in range(ncols):
        pivot = None
        for i in range(r, len(mat)):
            if mat[i][col] != 0:
                pivot = i
                break
        if pivot is None:
            continue
        mat[r], mat[pivot] = mat[pivot], mat[r]
        pv = mat[r][col]
        mat[r] = [v / pv for v in mat[r]]
        for i in range(len(mat)):
            if i != r and mat[i][col] != 0:
                f = mat[i][col]
                mat[i] = [a - f * b for a, b in zip(mat[i], mat[r])]
        r += 1
        if r == len(mat):
            break
    return r


def coefficients(table: Sequence[int]) -> dict:
    """Canonical coefficients in the reduced ring, by exact interpolation."""
    basis = monomial_basis()
    # Interpolate: solve V c = table with V[state, monomial].
    rows = []
    for si, x in enumerate(STATES):
        rows.append([Fraction(evaluate_monomial(e, x)) for e in basis] +
                    [Fraction(table[si])])
    n = len(basis)
    # Gaussian elimination on the augmented system.
    r = 0
    where = [-1] * n
    for col in range(n):
        pivot = None
        for i in range(r, len(rows)):
            if rows[i][col] != 0:
                pivot = i
                break
        if pivot is None:
            continue
        rows[r], rows[pivot] = rows[pivot], rows[r]
        pv = rows[r][col]
        rows[r] = [v / pv for v in rows[r]]
        for i in range(len(rows)):
            if i != r and rows[i][col] != 0:
                f = rows[i][col]
                rows[i] = [a - f * b for a, b in zip(rows[i], rows[r])]
        where[col] = r
        r += 1
    out = {}
    for col, e in enumerate(basis):
        if where[col] >= 0:
            c = rows[where[col]][n]
            if c != 0:
                out[e] = c
    return out


def structural_report(samples: int = 400, seed: int = 20260915) -> dict:
    """Facts about the realizable family, checked exactly on all 27 states."""
    rng = random.Random(seed)
    widths = (1, 2, 4, 8, 64, 256)
    tables = []
    per_width = {}
    for w in widths:
        rows = []
        images = []
        for _ in range(samples):
            net = Network.random(w, rng)
            t = net.table()
            rows.append([Fraction(v) for v in t])
            tables.append(t)
            images.append(len(set(t)))
        per_width[w] = {
            "span_rank_over_27_points": rank(rows),
            "distinct_output_values_min": min(images),
            "distinct_output_values_max": max(images),
            "distinct_output_values_mean": sum(images) / len(images),
        }

    # Reflection: F(x) + F(-x) must be a homogeneous quadratic form.
    neg = {x: STATES.index((-x[0], -x[1], -x[2])) for x in STATES}
    quad_basis = [e for e in monomial_basis() if sum(e) == 2]
    violations = 0
    for t in tables:
        even = [t[i] + t[neg[x]] for i, x in enumerate(STATES)]
        co = coefficients(even)
        if any(e not in quad_basis for e in co):
            violations += 1
    return {
        "family": "F(x)=sum_i c_i relu(g_i.x)(u_i.x), g,u ternary, c in {-1,1}",
        "states": 27,
        "samples_per_width": samples,
        "per_width": per_width,
        "reflection_even_part_is_homogeneous_quadratic": violations == 0,
        "reflection_violations": violations,
        "dimension_bound_odd_plus_quadratic": 6 + 13,
    }


if __name__ == "__main__":
    report = structural_report()
    print(json.dumps(report, indent=2, default=str))
