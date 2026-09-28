#!/usr/bin/env python3
"""Checks for the ternary quotient-ring tool. Runs in about a second."""

import random
import sys
from fractions import Fraction
from itertools import product

from ternary_algebra import (
    MAX_POINTS,
    TRITS,
    Poly,
    difference_witness,
    from_values,
    interpolate,
    modular_representable,
    points,
    reachable_states,
    states_equal,
)


def random_poly(rng, variables, terms=6):
    poly = Poly()
    for _ in range(terms):
        monomial = Poly.constant(Fraction(rng.randint(-4, 4), rng.choice((1, 2, 3))))
        for variable in variables:
            monomial = monomial * Poly.variable(variable).power(rng.randint(0, 2))
        poly = poly + monomial
    return poly


def agrees(left, right, variables):
    return all(left.evaluate(p) == right.evaluate(p) for p in points(variables))


def test_reduction_matches_evaluation():
    x = Poly.variable("x")
    assert x.power(3) == x
    assert x.power(4) == x * x
    assert x.power(5) == x
    for value in TRITS:
        assert (x * x * x).evaluate({"x": value}) == value ** 3


def test_ring_laws():
    rng = random.Random(20260112)
    variables = ["a", "b", "c"]
    for _ in range(25):
        p, q, r = (random_poly(rng, variables) for _ in range(3))
        assert p + q == q + p
        assert p * q == q * p
        assert (p + q) + r == p + (q + r)
        assert (p * q) * r == p * (q * r)
        assert p * (q + r) == p * q + p * r
        assert (p - p).is_zero()
        # Canonical arithmetic is the function on T^n, pointwise.
        for point in points(variables):
            assert (p * q).evaluate(point) == p.evaluate(point) * q.evaluate(point)
            assert (p + q).evaluate(point) == p.evaluate(point) + q.evaluate(point)


def test_canonical_form_is_unique():
    rng = random.Random(7)
    variables = ["u", "v"]
    for _ in range(40):
        p = random_poly(rng, variables)
        recovered = interpolate(p.evaluate, variables)
        assert recovered == p
        assert recovered.canonical_key() == p.canonical_key()
        assert hash(recovered) == hash(p)


def test_interpolation_round_trip_with_rationals():
    variables = ["x", "y", "z"]
    rng = random.Random(99)
    table = {tuple(vs): Fraction(rng.randint(-9, 9), rng.randint(1, 5))
             for vs in product(TRITS, repeat=3)}
    poly = from_values(table, variables)
    for values, expected in table.items():
        assert poly.evaluate(dict(zip(variables, values))) == expected


def test_half_integer_coefficients_are_needed():
    # f(-1)=0, f(0)=0, f(1)=1 forces denominators of 2 over Q.
    poly = from_values({(-1,): 0, (0,): 0, (1,): 1}, ["x"])
    assert poly == Poly.variable("x") * Fraction(1, 2) + Poly.variable("x").power(2) * Fraction(1, 2)
    assert not modular_representable([0, 0, 1], 4)
    assert not modular_representable([0, 0, 1], 256)
    assert modular_representable([0, 0, 2], 4)
    representable = sum(modular_representable(list(v), 4) for v in product(range(4), repeat=3))
    assert representable == 32  # half of the 64 maps T -> Z/4


def test_substitution_composes_functions():
    rng = random.Random(4242)
    inner_vars = ["s", "t"]
    outer_vars = ["p", "q"]
    for _ in range(15):
        # Trit-valued inner maps, interpolated from random trit tables.
        inner = {}
        for name in outer_vars:
            table = {vs: Fraction(rng.choice(TRITS)) for vs in product(TRITS, repeat=2)}
            poly = from_values(table, inner_vars)
            assert poly.is_trit_valued()
            inner[name] = poly
        outer = random_poly(rng, outer_vars)
        composed = outer.substitute(inner)
        for point in points(inner_vars):
            middle = {name: inner[name].evaluate(point) for name in outer_vars}
            assert composed.evaluate(point) == outer.evaluate(middle)


def test_substitution_guard_rejects_non_trit_maps():
    x = Poly.variable("x")
    outer = Poly.variable("h").power(2)
    assert not (x + Poly.constant(1)).is_trit_valued()
    try:
        outer.substitute({"h": x + Poly.constant(1)})
    except ValueError as error:
        assert "cubic closure" in str(error)
    else:
        raise AssertionError("expected the guard to reject a non-trit-valued map")
    assert x.is_trit_valued()
    assert (x * x).is_trit_valued()
    assert outer.substitute({"h": x * x}) == x * x


def test_substitution_boundary_counterexample():
    # A normal form describes the map only on ternary arguments.
    y, x = Poly.variable("y"), Poly.variable("x")
    outer = y.power(3) - y
    assert outer.is_zero()
    inner = x + Poly.constant(1)
    assert not inner.is_trit_valued()
    # Algebraic rewriting of the representative: still zero.
    assert outer.substitute_representative({"y": inner}).is_zero()
    # The unreduced expression is not zero there.
    assert (1 + 1) ** 3 - (1 + 1) == 6
    try:
        outer.compose({"y": inner})
    except ValueError as error:
        assert "cubic closure" in str(error)
    else:
        raise AssertionError("expected compose to refuse a non-trit-valued argument")


def test_reflection_capacity_bound_on_two_inputs():
    # f(x) + f(-x) quadratic forces even coefficients above total degree two to
    # vanish; with the odd part free this bounds the family by 7 of 9 dimensions.
    rng = random.Random(5150)
    variables = ["x0", "x1"]
    seen = set()
    for _ in range(40):
        width = rng.choice((1, 3, 9))
        weights = [tuple(rng.choice(TRITS) for _ in range(4)) for _ in range(width)]
        consumers = [rng.choice(TRITS) for _ in range(width)]

        def network(point):
            a, b = point["x0"], point["x1"]
            total = 0
            for c, (g0, g1, u0, u1) in zip(consumers, weights):
                gate = g0 * a + g1 * b
                total += c * (gate if gate > 0 else 0) * (u0 * a + u1 * b)
            return Fraction(total)

        poly = interpolate(network, variables)
        for monomial, coefficient in poly.terms.items():
            odd_slots = sum(1 for _, e in monomial if e == 1)
            if odd_slots % 2 == 0:
                assert sum(e for _, e in monomial) <= 2, monomial
        seen.add(poly.canonical_key())
        assert poly.evaluate({"x0": 0, "x1": 0}) == 0
    assert len(seen) > 1


def test_scalar_replacements_are_checked_for_closure():
    # A bare 2 is a constant map out of {-1,0,1}: composition must refuse it.
    outer = Poly.variable("x").power(2)
    for scalar in (2, Fraction(1, 2), -3):
        try:
            outer.compose({"x": scalar})
        except ValueError as error:
            assert "cubic closure" in str(error)
        else:
            raise AssertionError(f"compose accepted the non-trit scalar {scalar}")
    for scalar in TRITS:
        assert outer.compose({"x": scalar}) == Poly.constant(scalar ** 2)


def test_integer_tables_stay_exact():
    # The /2 inside interpolation must never see a raw int.
    poly = interpolate([0, 0, 1], ["x"])
    assert all(isinstance(c, Fraction) for c in poly.terms.values())
    assert poly.evaluate({"x": 1}) == 1 and poly.evaluate({"x": -1}) == 0
    big = 2 ** 60 + 1
    table = [0, big, 3 * big]
    recovered = interpolate(table, ["x"])
    for value, expected in zip(TRITS, table):
        assert recovered.evaluate({"x": value}) == expected
    assert recovered.evaluate({"x": 1}) == 3 * big  # would drift as a float


def test_table_shape_and_limits():
    try:
        interpolate([0, 1], ["x"])
    except ValueError as error:
        assert "expected 3" in str(error)
    else:
        raise AssertionError("expected a table-length complaint")
    try:
        interpolate([0] * 3 ** 12, [f"v{i}" for i in range(12)])
    except ValueError as error:
        assert "above the limit" in str(error)
    else:
        raise AssertionError("expected the list path to enforce the point limit")
    for call in (lambda: list(points(["x", "x"])),
                 lambda: interpolate(lambda p: Fraction(0), ["x", "x"]),
                 lambda: from_values({}, ["a", "b", "a"])):
        try:
            call()
        except ValueError as error:
            assert "duplicate variable" in str(error)
        else:
            raise AssertionError("expected duplicate variable names to be rejected")


def test_constructor_normalizes_and_rejects():
    x, y = Poly.variable("x"), Poly.variable("y")
    assert Poly({(("x", 1), ("x", 1)): 1}) == x * x
    assert Poly({(("x", 4),): 1}) == x * x
    assert Poly({(("x", 3),): 1}) == x
    assert Poly({(("y", 1), ("x", 1)): 1}) == x * y
    assert Poly({(("x", 0),): 5}) == Poly.constant(5)
    # Two spellings of one basis element add instead of shadowing each other.
    combined = Poly({(("x", 2),): 1, (("x", 4),): 1})
    assert combined == x * x * 2
    assert len(combined.terms) == 1
    for bad in ({(("x", -1),): 1}, {(("x", 1.5),): 1}, {("x",): 1}):
        try:
            Poly(bad)
        except ValueError:
            pass
        else:
            raise AssertionError(f"constructor accepted {bad}")


def test_terms_are_immutable():
    poly = Poly.variable("x") + Poly.constant(2)
    before = hash(poly)
    try:
        poly.terms[(("x", 1),)] = Fraction(99)
    except TypeError:
        pass
    else:
        raise AssertionError("public coefficient map is writable")
    try:
        del poly.terms[(("x", 1),)]
    except TypeError:
        pass
    else:
        raise AssertionError("public coefficient map is deletable")
    assert hash(poly) == before
    assert dict(poly.terms) == {(("x", 1),): Fraction(1), (): Fraction(2)}


def test_difference_witness():
    rng = random.Random(31337)
    variables = [f"x{i}" for i in range(5)]
    for _ in range(20):
        p = random_poly(rng, variables, terms=4)
        q = random_poly(rng, variables, terms=4)
        witness = difference_witness(p, q, variables)
        if p == q:
            assert witness is None
        else:
            assert set(witness) == set(variables)
            assert p.evaluate(witness) != q.evaluate(witness)
    assert difference_witness(p, p) is None


def test_structure_reports():
    x, y, z = (Poly.variable(n) for n in "xyz")
    poly = x * y + z.power(2) * x
    assert poly.support() == {"x", "y", "z"}
    assert poly.interaction_degree() == 2
    assert poly.total_degree() == 3
    assert poly.monomial_count() == 2
    assert Poly.constant(3).profile() == {
        "monomials": 1, "support_size": 0, "interaction_degree": 0, "total_degree": 0}


def test_reachable_states_and_equality():
    x, y = Poly.variable("x"), Poly.variable("y")
    left = [x * y, x + y]
    right = [x * y, y + x]
    assert states_equal(left, right, ["x", "y"])
    assert len(reachable_states(left, ["x", "y"])) == 6
    assert not states_equal(left, [x * y, x - y], ["x", "y"])


def test_point_limit():
    try:
        list(points([f"v{i}" for i in range(12)], max_points=MAX_POINTS))
    except ValueError as error:
        assert "above the limit" in str(error)
    else:
        raise AssertionError("expected the exponential-table guard to fire")


def main():
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()
        print(f"ok {test.__name__}")
    print(f"{len(tests)} checks passed")


if __name__ == "__main__":
    sys.exit(main())
