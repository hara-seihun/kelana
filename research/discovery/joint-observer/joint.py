#!/usr/bin/env python3
"""Exact pullback intersections for jointly choosing carriers and consumers."""
from dataclasses import dataclass
from typing import Optional

import sympy as sp


@dataclass
class JointFamily:
    consumer_coefficients: sp.Matrix
    source_coefficients: sp.Matrix
    values: sp.Matrix
    coefficient_nullity: int

    @property
    def dimension(self):
        return self.values.cols


class SourceSpace:
    """Columns are source functions, rows are reachable inputs, over Q."""
    def __init__(self, values):
        self.values = sp.Matrix(values)
        if self.values.rows == 0 or self.values.cols == 0:
            raise ValueError("source space must have states and functions")
        if any(not v.is_Rational for v in self.values):
            raise ValueError("source values must be exact rationals")
        self.pivots = self.values.rref()[1]
        self.basis = self.values[:, list(self.pivots)]
        annihilators = self.basis.T.nullspace()
        self.constraints = (sp.Matrix.vstack(*(v.T for v in annihilators))
                            if annihilators else sp.zeros(0, self.values.rows))

    def intersect(self, consumer_values):
        """Intersect source image with consumer image; discard zero-function freedom.

        consumer_values may come from polynomials, ISA programs or tuple carriers.
        Its columns are evaluated features, not abstract symbolic expressions.
        """
        b = sp.Matrix(consumer_values)
        if b.rows != self.values.rows:
            raise ValueError("source and consumer must enumerate the same states")
        if any(not v.is_Rational for v in b):
            raise ValueError("consumer values must be exact rationals")
        kernel = (self.constraints * b).nullspace()
        n = sp.Matrix.hstack(*kernel) if kernel else sp.zeros(b.cols, 0)
        image = b * n
        keep = image.rref()[1]
        coefficients = n[:, list(keep)]
        values = b * coefficients
        source = sp.zeros(self.values.cols, len(keep))
        for j in range(len(keep)):
            solution, free = self.basis.gauss_jordan_solve(values[:, j])
            assert free.rows == 0
            for i, pivot in enumerate(self.pivots):
                source[pivot, j] = solution[i]
        assert self.values * source == values
        return JointFamily(coefficients, source, values, len(kernel))


def polynomial_features(carrier, powers):
    values = [sp.sympify(h) for h in carrier]
    if any(not h.is_Rational for h in values):
        raise ValueError("carrier labels must be exact rationals")
    if any(not isinstance(p, int) or p < 0 for p in powers):
        raise ValueError("powers must be nonnegative integers")
    return sp.Matrix([[h ** p for p in powers] for h in values])


def label_features(carrier):
    labels = sorted(set(carrier))
    return sp.Matrix([[int(h == label) for label in labels] for h in carrier])


def separates_all_coordinates(states, carrier):
    return all(any(carrier[i] != carrier[j] and
                   all(x[k] == y[k] for k in range(len(x)) if k != axis)
                   for i, x in enumerate(states) for j, y in enumerate(states))
               for axis in range(len(states[0])))


def collision_witness(carrier, target) -> Optional[dict]:
    """A necessary and sufficient obstruction to ANY deterministic decoder."""
    if len(carrier) != len(target):
        raise ValueError("carrier and target must enumerate the same states")
    seen = {}
    for i, (h, y) in enumerate(zip(carrier, target)):
        if h in seen and seen[h][1] != y:
            return {"first": seen[h][0], "second": i, "carrier": h,
                    "first_output": seen[h][1], "second_output": y}
        seen[h] = i, y
    return None


def target_coefficients(features, target):
    """Represent a fixed target in a declared consumer grammar, or return None."""
    a, b = sp.Matrix(features), sp.Matrix(target)
    if a.rows != b.rows or b.cols != 1:
        raise ValueError("one target value is needed for every state")
    if any(not v.is_Rational for v in (*a, *b)):
        raise ValueError("target and feature values must be exact rationals")
    try:
        solution, free = a.gauss_jordan_solve(b)
    except ValueError:
        return None
    return solution.subs({s: 0 for s in free})
