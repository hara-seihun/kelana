#!/usr/bin/env python3
"""Instruction-first exact search on a densely packed three-trit word.

Solve for output labels making an ISA-shaped map a bias-free gated ReLU map.
This discovers constructions, not replacements for arbitrary fixed weights.
"""
import argparse
import json
import math
import random
from itertools import product
from pathlib import Path
from time import monotonic
import sympy as sp
from observer import fibers

STATES = tuple(product((-1, 0, 1), repeat=3))
INDEX = {x: i for i, x in enumerate(STATES)}
CODES = tuple(sum((v + 1) * 3**j for j, v in enumerate(x)) for x in STATES)
ZERO = INDEX[(0, 0, 0)]
REPS = tuple(i for i, x in enumerate(STATES) if x > tuple(-v for v in x))
QUADRATICS = tuple((i, j) for i in range(3) for j in range(i, 3))
MASK32 = (1 << 32) - 1


def admissible_labels(values):
    """Kernel projected onto labels; a forced equality forbids bijective relabeling."""
    classes = fibers(values)
    m = max(classes) + 1
    rows = []
    for k in REPS:
        x = STATES[k]
        neg = INDEX[tuple(-v for v in x)]
        row = [0] * (m + 6)
        row[classes[k]] += 1
        row[classes[neg]] += 1
        for j, (a, b) in enumerate(QUADRATICS):
            row[m+j] = -x[a] * x[b]
        rows.append(row)
    zero = [0] * (m + 6)
    zero[classes[ZERO]] = 1
    rows.append(zero)
    basis = [tuple(v[:m]) for v in sp.Matrix(rows).nullspace()]
    for i in range(m):
        for j in range(i + 1, m):
            if all(v[i] == v[j] for v in basis):
                return classes, basis, (i, j)
    return classes, basis, None


def integer_labels(vector):
    denom = sp.ilcm(*[v.q for v in vector]) if len(vector) > 1 else vector[0].q
    integers = [int(v * denom) for v in vector]
    g = math.gcd(*integers)
    return tuple(v // (g or 1) for v in integers)


def choose_labels(basis):
    """Prefer small labels; a moment-curve construction is the exact fallback."""
    d, m = len(basis), len(basis[0])
    rng = random.Random(17)
    combinations = [tuple(int(i == j) for i in range(d)) for j in range(d)]
    combinations += [tuple(rng.randrange(-3, 4) for _ in range(d)) for _ in range(64)]
    candidates = []
    for coeff in combinations:
        v = integer_labels(tuple(sum(coeff[j] * basis[j][i] for j in range(d)) for i in range(m)))
        if len(set(v)) == m:
            candidates.append(v)
    if candidates:
        return min(candidates, key=lambda v: (max(map(abs, v)), sum(map(abs, v)), v))
    # Every pair gives a nonzero polynomial of degree <= d-1. At most this many
    # integer parameters are forbidden, so one of bound+1 candidates must work.
    bound = (d - 1) * m * (m - 1) // 2
    for t in range(bound + 1):
        v = integer_labels(tuple(sum(t**j * basis[j][i] for j in range(d)) for i in range(m)))
        if len(set(v)) == m:
            return v
    raise AssertionError("no distinct labels despite no identically equal pair")


def source_basis():
    atoms = [(g, j) for g in STATES if any(g) for j in range(3)]
    columns = [tuple(max(sum(a*b for a, b in zip(g, x)), 0)*x[j] for x in STATES)
               for g, j in atoms]
    full = sp.Matrix.hstack(*(sp.Matrix(c) for c in columns))
    pivots = full.rref()[1]
    return [atoms[i] for i in pivots], full[:, list(pivots)]


def candidates():
    for constant in (1, 2, 3, 5, 7, 9, 11, 13, 17, 27, 81, 243, 21845):
        for bias in (-13, 0, 13):
            for shift in range(10):
                for width in (1, 2, 3, 4):
                    mask = (1 << width) - 1
                    values = tuple((((q * constant + bias) & MASK32) >> shift) & mask for q in CODES)
                    yield {"form": "u32_affine_bfe", "multiplier": constant,
                           "bias": bias, "offset": shift, "width": width}, values
    for form, values in (
        ("centered_square_low8", tuple(((q-13)**2) & 255 for q in CODES)),
        ("centered_abs", tuple(abs(q-13) for q in CODES)),
        ("popcount", tuple(q.bit_count() for q in CODES)),
        ("popcount_parity", tuple(q.bit_count() & 1 for q in CODES)),
        ("centered_square_low4", tuple(((q-13)**2) & 15 for q in CODES)),
    ):
        yield {"form": form}, values


def run(max_partitions=600, seconds=15):
    start = monotonic()
    atoms, matrix = source_basis()
    seen = set()
    records = []
    generated = eligible = rejected = 0
    complete = True
    for spec, values in candidates():
        generated += 1
        key = fibers(values)
        classes_n = len(set(key))
        if not 2 <= classes_n <= 9:
            continue
        eligible += 1
        if key in seen:
            continue
        if len(seen) >= max_partitions or monotonic() - start >= seconds:
            complete = False
            break
        seen.add(key)
        classes, basis, collision = admissible_labels(values)
        if collision is not None:
            rejected += 1
            continue
        labels = choose_labels(basis)
        target = tuple(labels[c] for c in classes)
        coefficients, params = matrix.gauss_jordan_solve(sp.Matrix(target))
        assert params.rows == 0
        assert matrix * coefficients == sp.Matrix(target)
        assert fibers(target) == key
        terms = []
        for (g, j), coefficient in zip(atoms, coefficients):
            if coefficient:
                terms.append({"gate": g, "up_coordinate": j, "coefficient": str(coefficient)})
        raw_to_label = {}
        for raw, label in zip(values, target):
            raw_to_label[raw] = label
        records.append({"instruction_map": spec, "output_classes": classes_n,
                        "label_space_dimension": len(basis), "relabeling": raw_to_label,
                        "max_abs_label": max(map(abs, labels)), "network_terms": terms,
                        "target_values": target,
                        "claim": "exact complete-map structural match on all 27 inputs; relabeling cost not priced"})
    records.sort(key=lambda r: (r["max_abs_label"], len(r["network_terms"]), r["output_classes"]))
    return {
        "domain": "three ternary inputs, q=sum((x_i+1)*3^i), q is supplied already packed",
        "grammar": "((u32(a*q+b)>>offset)&mask), fixed coefficient/shift grid in source; five extra unary maps",
        "numeric_model": "u32 affine wraps before extraction; other forms as named",
        "source_family": "sum c*relu(g dot x)*x_j with ternary g, rational c; no biases",
        "source_basis_rank": matrix.rank(), "whole_cube_size": len(STATES),
        "filter": "2..9 output classes; identical fibers deduplicated for STRUCTURAL query only",
        "limits": {"max_partitions": max_partitions, "seconds": seconds},
        "enumeration_complete": complete, "generated_maps": generated,
        "eligible_maps": eligible, "distinct_partitions": len(seen),
        "rejected_partitions": rejected, "matched_partitions": len(records),
        "elapsed_seconds": monotonic()-start,
        "best_matches": records[:12],
        "scope": "Instruction-first existence atlas, not a fixed Bonsai-weight replacement or speedup. Arbitrary relabelings are not free. Network witnesses are one basis decomposition, not minimal networks.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--partitions", type=int, default=600)
    parser.add_argument("--seconds", type=float, default=15)
    args = parser.parse_args()
    result = run(args.partitions, args.seconds)
    path = Path(__file__).with_name("inverse-results.json")
    path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "best_matches"}, indent=2))
    print("best matches:", [(r["instruction_map"], r["max_abs_label"], len(r["network_terms"])) for r in result["best_matches"][:5]])
