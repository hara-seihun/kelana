#!/usr/bin/env python3
"""Canonicalize and compare existing Kelana ternary maps. Exact, no hardware claim.

Writes results.json next to this file. Runs in a few seconds.
"""

import json
import random
from fractions import Fraction
from itertools import product
from pathlib import Path

from ternary_algebra import (
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


def profile(poly):
    return poly.profile()


def relu(value):
    return value if value > 0 else 0


def sign(value):
    return (value > 0) - (value < 0)


# 1. the existing 2x2 ternary MAC, D = A B + C --------------------------


def mac_2x2():
    """D = AB + C built symbolically, then rebuilt from a packed truth table."""
    a = {(i, j): Poly.variable(f"a{i}{j}") for i in range(2) for j in range(2)}
    b = {(i, j): Poly.variable(f"b{i}{j}") for i in range(2) for j in range(2)}
    c = {(i, j): Poly.variable(f"c{i}{j}") for i in range(2) for j in range(2)}
    d = {(i, j): a[(i, 0)] * b[(0, j)] + a[(i, 1)] * b[(1, j)] + c[(i, j)]
         for i in range(2) for j in range(2)}

    entries = {f"d{i}{j}": profile(d[(i, j)]) for i in range(2) for j in range(2)}

    # One output column packed as a single byte in radix 7, the shape toy2's
    # packed construction consumes. Its sign metadata is not modelled here.
    column = ["a00", "a01", "a10", "a11", "b00", "b10", "c00", "c10"]
    packed_symbolic = (d[(0, 0)] + 3) + (d[(1, 0)] + 3) * 7

    def packed_elementwise(point):
        va = [[point[f"a{i}{j}"] for j in range(2)] for i in range(2)]
        vb = [point["b00"], point["b10"]]
        vc = [point["c00"], point["c10"]]
        out = [sum(va[i][k] * vb[k] for k in range(2)) + vc[i] for i in range(2)]
        return (out[0] + 3) + 7 * (out[1] + 3)

    packed_interpolated = interpolate(packed_elementwise, column)
    witness = difference_witness(packed_symbolic, packed_interpolated, column)

    outputs = [d[(0, 0)], d[(1, 0)]]
    return {
        "map": "D = A*B + C on twelve trits, entries of D in [-3,3]",
        "entry_profiles": entries,
        "column_variables": column,
        "packed_byte_profile": profile(packed_symbolic),
        "packed_routes_agree": witness is None,
        "packed_difference_witness": witness,
        "column_states": len(reachable_states(outputs, column)),
        "packed_states": len(reachable_states([packed_symbolic], column)),
        "note": "The packed byte is one canonical polynomial in the eight column "
                "inputs. Building it through D or straight from the truth table "
                "gives the same element, so the elementwise boundary is not part "
                "of the function.",
    }


# 2. gated FFN maps, hidden width contracted away ------------------------


def random_unit(rng):
    return tuple(rng.choice(TRITS) for _ in range(4))


def gated_network(weights, consumers, variables):
    """sum_j c_j * relu(g_j . x) * (u_j . x) as a callable on trit points."""
    n = len(variables)

    def evaluate(point):
        x = [point[v] for v in variables]
        total = 0
        for c, w in zip(consumers, weights):
            gate = sum(g * xi for g, xi in zip(w[:n], x))
            up = sum(u * xi for u, xi in zip(w[n:], x))
            total += c * relu(gate) * up
        return Fraction(total)

    return evaluate


def random_network(rng, width, n):
    weights = [tuple(rng.choice(TRITS) for _ in range(2 * n)) for _ in range(width)]
    consumers = [rng.choice(TRITS) for _ in range(width)]
    return weights, consumers


def hidden_channels(weights, variables):
    """Each hidden channel as its own canonical map, for a before/after count."""
    n = len(variables)
    channels = []
    for w in weights:
        def channel(point, w=w):
            x = [point[v] for v in variables]
            gate = sum(g * xi for g, xi in zip(w[:n], x))
            up = sum(u * xi for u, xi in zip(w[n:], x))
            return Fraction(relu(gate) * up)
        channels.append(interpolate(channel, variables))
    return channels


def contraction_report(rng, n, widths):
    variables = [f"x{i}" for i in range(n)]
    rows = []
    for width in widths:
        weights, consumers = random_network(rng, width, n)
        output = interpolate(gated_network(weights, consumers, variables), variables)
        channels = hidden_channels(weights, variables)
        hidden_states = {tuple(p.evaluate(point) for p in channels)
                         for point in points(variables)}
        rows.append({
            "hidden_width": width,
            "hidden_channel_monomials": sum(p.monomial_count() for p in channels),
            "hidden_channel_max_interaction": max((p.interaction_degree() for p in channels),
                                                  default=0),
            "distinct_hidden_states": len(hidden_states),
            "contracted": profile(output),
            "distinct_output_states": len(reachable_states([output], variables)),
            "matches_network_pointwise": all(
                output.evaluate(p) == gated_network(weights, consumers, variables)(p)
                for p in points(variables)),
        })
    return {
        "inputs": n,
        "domain_states": 3 ** n,
        "basis_dimension": 3 ** n,
        "rows": rows,
        "note": "Hidden width does not appear in the contracted profile. Monomial "
                "counts are algebraic size, not instruction counts.",
    }


# 3. gate / up / polynomial / down, composed by substitution -------------


def composed_stack(rng, n=3, hidden=3):
    """Quantized hidden trits, a polynomial layer, then a linear consumer.

    The quantizer makes the intermediate trit-valued, so substitution into the
    polynomial layer is exact and the whole stack collapses without ever
    materializing the hidden state. The same map is interpolated end to end as
    an independent route.
    """
    variables = [f"x{i}" for i in range(n)]
    hidden_names = [f"h{j}" for j in range(hidden)]
    gate = [[rng.choice(TRITS) for _ in range(n)] for _ in range(hidden)]
    up = [[rng.choice(TRITS) for _ in range(n)] for _ in range(hidden)]
    down = [rng.choice(TRITS) for _ in range(hidden)]

    def quantized(j):
        def channel(point):
            x = [point[v] for v in variables]
            g = sum(w * xi for w, xi in zip(gate[j], x))
            u = sum(w * xi for w, xi in zip(up[j], x))
            return Fraction(sign(relu(g) * u))
        return interpolate(channel, variables)

    hidden_maps = {name: quantized(j) for j, name in enumerate(hidden_names)}
    assert all(p.is_trit_valued() for p in hidden_maps.values())

    # The polynomial layer reads only the hidden trits.
    h = [Poly.variable(name) for name in hidden_names]
    layer = [h[j] * h[(j + 1) % hidden] + h[j].power(2) - h[(j + 2) % hidden]
             for j in range(hidden)]
    consumer = Poly.sum(Poly.constant(d) * p for d, p in zip(down, layer))

    by_substitution = consumer.substitute(hidden_maps)

    def end_to_end(point):
        values = {name: hidden_maps[name].evaluate(point) for name in hidden_names}
        return consumer.evaluate(values)

    by_interpolation = interpolate(end_to_end, variables)
    witness = difference_witness(by_substitution, by_interpolation, variables)

    return {
        "stages": "gate/up -> trit quantizer -> quadratic layer in h -> linear down",
        "inputs": n,
        "hidden_trits": hidden,
        "hidden_channel_profiles": [profile(hidden_maps[name]) for name in hidden_names],
        "layer_profile_in_h": profile(consumer),
        "contracted_in_x": profile(by_substitution),
        "substitution_matches_interpolation": witness is None,
        "difference_witness": witness,
        "hidden_states_used": len({tuple(hidden_maps[name].evaluate(p) for name in hidden_names)
                                   for p in points(variables)}),
        "output_states": len(reachable_states([by_substitution], variables)),
        "note": "Substitution is exact here because the quantizer makes the "
                "intermediate trit-valued; the tool refuses it otherwise.",
    }


# 4. observer equivalence ------------------------------------------------


def rank(rows):
    """Exact rank over Q."""
    matrix = [list(row) for row in rows]
    if not matrix:
        return 0
    pivot_row = 0
    for column in range(len(matrix[0])):
        pivot = next((r for r in range(pivot_row, len(matrix)) if matrix[r][column]), None)
        if pivot is None:
            continue
        matrix[pivot], matrix[pivot_row] = matrix[pivot_row], matrix[pivot]
        scale = matrix[pivot_row][column]
        matrix[pivot_row] = [v / scale for v in matrix[pivot_row]]
        for r in range(len(matrix)):
            if r != pivot_row and matrix[r][column]:
                factor = matrix[r][column]
                matrix[r] = [a - factor * b for a, b in zip(matrix[r], matrix[pivot_row])]
        pivot_row += 1
    return pivot_row


def coefficient_vector(poly, variables):
    order = []
    for exponents in product((0, 1, 2), repeat=len(variables)):
        order.append(tuple(sorted((v, e) for v, e in zip(variables, exponents) if e)))
    return [poly.terms.get(monomial, Fraction(0)) for monomial in order]


def observer_equivalence(rng, n, widths, trials):
    """Different hidden vectors, identical contracted map.

    Collisions are only reported when the shared map is nonzero and the two
    hidden states genuinely differ at some input.
    """
    variables = [f"x{i}" for i in range(n)]
    seen = {}
    vectors = []
    found = None
    found_mixed_width = None
    for _ in range(trials):
        width = rng.choice(widths)
        weights, consumers = random_network(rng, width, n)
        output = interpolate(gated_network(weights, consumers, variables), variables)
        vectors.append(coefficient_vector(output, variables))
        key = output.canonical_key()
        previous = seen.get(key)
        seen.setdefault(key, (weights, consumers, output))
        if previous is None or output.is_zero():
            continue
        other_weights, other_consumers, other_output = previous
        channels = hidden_channels(weights, variables)
        other_channels = hidden_channels(other_weights, variables)
        hidden_witness = None
        for point in points(variables):
            left = [p.evaluate(point) for p in channels]
            right = [p.evaluate(point) for p in other_channels]
            if left != right:
                hidden_witness = {"point": point, "hidden_a": [str(v) for v in left],
                                  "hidden_b": [str(v) for v in right]}
                break
        if hidden_witness is None:
            continue
        example = {
            "width_a": width, "weights_a": weights, "consumers_a": consumers,
            "width_b": len(other_weights), "weights_b": other_weights,
            "consumers_b": other_consumers,
            "hidden_differs_at": hidden_witness,
            "contracted": str(output),
            "contracted_profile": profile(output),
            "canonical_forms_equal": output == other_output,
            "reachable_states_equal": states_equal([output], [other_output], variables),
            "distinct_hidden_states_a": len({
                tuple(p.evaluate(pt) for p in channels) for pt in points(variables)}),
            "distinct_hidden_states_b": len({
                tuple(p.evaluate(pt) for p in other_channels) for pt in points(variables)}),
        }
        if found is None:
            found = example
        if found_mixed_width is None and width != len(other_weights):
            found_mixed_width = example
    return {
        "inputs": n,
        "hidden_widths": list(widths),
        "networks_sampled": trials,
        "distinct_contracted_maps": len(seen),
        "basis_dimension": 3 ** n,
        "family_rank_over_Q": rank(vectors),
        "example": found,
        "example_across_widths": found_mixed_width,
        "note": "A collision means different hidden activations with one canonical "
                "output map. The contracted form is an observer quotient; it does "
                "not say the hidden vectors carry no information.",
    }


# 4b. reflection capacity: which functions this family can reach -------


def parity_split(poly):
    """Even and odd parts under x -> -x, in the canonical basis.

    A monomial flips sign with the parity of its exponent-1 slots, because
    (-x)**2 = x**2 and (-x)**1 = -x.
    """
    even, odd = {}, {}
    for monomial, coefficient in poly.terms.items():
        odd_slots = sum(1 for _, exponent in monomial if exponent == 1)
        (odd if odd_slots % 2 else even)[monomial] = coefficient
    return Poly(even), Poly(odd)


def reflection_capacity(rng, n, widths, trials):
    """Capacity screen for f(x) = sum c_i s(g_i.x)(u_i.x) with s(t)-s(-t)=t.

    f(x) + f(-x) = sum c_i (g_i.x)(u_i.x) is a homogeneous quadratic, so every
    even coefficient of total degree above two must vanish, while the identity
    says nothing about the odd coefficients. That bounds the reachable space by

        n(n+1)/2 + (3**n - 1)/2.

    This measures the exact rank actually attained by sampled ReLU networks and
    checks the vanishing claim on each sample; it does not prove spanning.
    """
    variables = [f"x{i}" for i in range(n)]
    quadratic = n * (n + 1) // 2
    odd_dimension = (3 ** n - 1) // 2
    bound = quadratic + odd_dimension
    vectors, per_width = [], {}
    violations = []
    for _ in range(trials):
        width = rng.choice(widths)
        weights, consumers = random_network(rng, width, n)
        output = interpolate(gated_network(weights, consumers, variables), variables)
        even, odd = parity_split(output)
        for monomial in even.terms:
            if sum(exponent for _, exponent in monomial) > 2:
                violations.append({"weights": weights, "consumers": consumers,
                                   "monomial": list(monomial)})
        vector = coefficient_vector(output, variables)
        vectors.append(vector)
        per_width.setdefault(width, []).append(vector)
    measured = rank(vectors)
    return {
        "inputs": n,
        "basis_dimension": 3 ** n,
        "quadratic_dimension": quadratic,
        "odd_dimension": odd_dimension,
        "allowed_dimension_bound": bound,
        "observed_rank": measured,
        "attains_bound": measured == bound,
        "observed_rank_by_width": {str(w): rank(v) for w, v in sorted(per_width.items())},
        "samples_by_width": {str(w): len(v) for w, v in sorted(per_width.items())},
        "networks_sampled": trials,
        "even_high_degree_violations": violations,
        "note": "The bound follows from the reflection identity alone. The observed "
                "rank is what exact ReLU samples reached; equality here is evidence "
                "of spanning, not a proof of it.",
    }


def difference_demo(rng, n=3):
    """Two networks that do differ: report the state that separates them."""
    variables = [f"x{i}" for i in range(n)]
    while True:
        wa, ca = random_network(rng, 4, n)
        wb, cb = random_network(rng, 4, n)
        left = interpolate(gated_network(wa, ca, variables), variables)
        right = interpolate(gated_network(wb, cb, variables), variables)
        witness = difference_witness(left, right, variables)
        if witness is not None:
            return {
                "weights_a": wa, "consumers_a": ca,
                "weights_b": wb, "consumers_b": cb,
                "witness": witness,
                "value_a": str(left.evaluate(witness)),
                "value_b": str(right.evaluate(witness)),
                "difference_profile": profile(left - right),
            }


# 5. the coefficient ring ------------------------------------------------


def ring_obstruction():
    half = from_values({(-1,): 0, (0,): 0, (1,): 1}, ["x"])
    over_z4 = sum(modular_representable(list(v), 4) for v in product(range(4), repeat=3))
    over_z256 = sum(modular_representable([a, b, c], 256)
                    for a, b, c in product(range(0, 256, 8), repeat=3))
    return {
        "indicator_of_plus_one": str(half),
        "denominator": 2,
        "evaluation_matrix_determinant": 2,
        "tensor_determinant": "2 ** (n * 3 ** (n - 1)) for n variables",
        "maps_to_Z4_representable": f"{over_z4} of 64",
        "sampled_maps_to_Z256_representable": f"{over_z256} of 32768 sampled",
        "note": "Interpolation inverts a Vandermonde with determinant 2, so it "
                "needs 2 to be a unit. Over Z/2**k it is not: exactly the maps "
                "with f(1)+f(-1)-2f(0) even lie in this basis. BitVec arithmetic "
                "is Z/2**k, so a BitVec map need not have a representative here. "
                "ContractedFFN.compile sidesteps this by representing 4F.",
    }


def substitution_boundary():
    """Algebraic substitution into a normal form is not map composition.

    Main's example: y**3 - y is the zero map on trits, so its normal form is 0.
    Substituting y = x + 1 into that normal form gives 0 everywhere, while the
    unreduced expression at x = 1 gives 2**3 - 2 = 6. The tool refuses the
    composition because x + 1 fails cubic closure.
    """
    y = Poly.variable("y")
    x = Poly.variable("x")
    outer = y.power(3) - y
    inner = x + Poly.constant(1)
    refused = None
    try:
        outer.compose({"y": inner})
    except ValueError as error:
        refused = str(error)
    unreduced = [(v, (v + 1) ** 3 - (v + 1)) for v in TRITS]
    return {
        "outer_expression": "y**3 - y",
        "outer_normal_form": str(outer),
        "inner": "x + 1",
        "inner_is_trit_valued": inner.is_trit_valued(),
        "substitution_into_normal_form": str(outer.substitute_representative({"y": inner})),
        "unreduced_expression_values": {str(v): value for v, value in unreduced},
        "composition_refused_with": refused,
        "note": "Normal forms describe maps only on ternary arguments. compose() "
                "checks cubic closure; substitute_representative() rewrites the "
                "representative and claims nothing about composition.",
    }


def main():
    rng = random.Random(20260112)
    results = {
        "format": "kelana-ternary-algebra/1",
        "arithmetic": "exact rationals, fractions.Fraction",
        "ring": "Q[x_1..x_n]/(x_i**3 - x_i), per-variable exponents 0, 1, 2",
        "mac_2x2": mac_2x2(),
        "gated_contraction": contraction_report(rng, 3, [1, 4, 16, 64, 256]),
        "composed_stack": composed_stack(rng),
        "reflection_capacity": [
            reflection_capacity(rng, 2, [1, 4, 16], 200),
            reflection_capacity(rng, 3, [4, 16, 64], 200),
            reflection_capacity(rng, 4, [8, 32, 128], 150),
        ],
        "substitution_boundary": substitution_boundary(),
        "observer_equivalence": {
            "two_inputs": observer_equivalence(rng, 2, [2, 4, 8], 400),
            "three_inputs": observer_equivalence(rng, 3, [4, 16], 400),
        },
        "difference_witness": difference_demo(rng),
        "coefficient_ring": ring_obstruction(),
        "scope": "Exact algebra on {-1,0,1}^n. No instruction count, cycle count "
                 "or hardware speedup is claimed or measured here.",
    }
    path = Path(__file__).with_name("results.json")
    path.write_text(json.dumps(results, indent=2, default=str) + "\n")

    mac = results["mac_2x2"]
    print(f"2x2 MAC: packed byte {mac['packed_byte_profile']['monomials']} monomials, "
          f"support {mac['packed_byte_profile']['support_size']}, "
          f"routes agree: {mac['packed_routes_agree']}")
    for row in results["gated_contraction"]["rows"]:
        print(f"width {row['hidden_width']:>3}: hidden states {row['distinct_hidden_states']:>2}, "
              f"contracted {row['contracted']['monomials']} monomials, "
              f"interaction {row['contracted']['interaction_degree']}, "
              f"output states {row['distinct_output_states']}")
    stack = results["composed_stack"]
    print(f"composed stack: substitution == interpolation: "
          f"{stack['substitution_matches_interpolation']}, "
          f"contracted {stack['contracted_in_x']['monomials']} monomials")
    for row in results["reflection_capacity"]:
        print(f"capacity n={row['inputs']}: observed rank {row['observed_rank']} of bound "
              f"{row['allowed_dimension_bound']} in {row['basis_dimension']} dimensions, "
              f"even high-degree violations {len(row['even_high_degree_violations'])}")
    boundary = results["substitution_boundary"]
    print(f"substitution boundary: y**3-y normalizes to {boundary['outer_normal_form']}, "
          f"unreduced value at x=1 is {boundary['unreduced_expression_values']['1']}, "
          f"composition refused: {boundary['composition_refused_with'] is not None}")
    for name, observer in results["observer_equivalence"].items():
        print(f"observer {name}: {observer['distinct_contracted_maps']} distinct maps from "
              f"{observer['networks_sampled']} networks, family rank "
              f"{observer['family_rank_over_Q']}/{observer['basis_dimension']}, "
              f"nonzero collision: {observer['example'] is not None}, "
              f"across widths: {observer['example_across_widths'] is not None}")
    print(f"ring: {results['coefficient_ring']['maps_to_Z4_representable']} maps T -> Z/4 "
          f"representable in this basis")
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
