#!/usr/bin/env python3
"""Exact integer routed-map experiment; no numerical dependencies."""
import itertools
import json
import random
from fractions import Fraction

DOMAIN = tuple(range(-7, 8))
NEG = tuple(x for x in DOMAIN if x < 0)
POS = tuple(x for x in DOMAIN if x >= 0)
TEACHER = ((1, 8, 3, -2), (2, 1, -1, 3), (-1, 8, 2, 1))
ROUTES = ((1, 2), (0, 1))  # x < 0, x >= 0


def expert(w, x):
    g, b, u, c = w
    return max(0, g*x+b)*(u*x+c)


def routed(weights, x):
    i, j = ROUTES[x >= 0]
    return expert(weights[i], x) + expert(weights[j], x)


def polynomial(values, xs):
    a, b, c = map(Fraction, (0, 0, 0))
    x0, x1, x2 = xs[:3]
    y0, y1, y2 = (values[x] for x in xs[:3])
    a = (Fraction(y2-y1, x2-x1) - Fraction(y1-y0, x1-x0)) / (x2-x0)
    b = Fraction(y1-y0, x1-x0) - a*(x1+x0)
    c = y0-a*x0*x0-b*x0
    abc = (a, b, c)
    return abc if all(a*x*x+b*x+c == values[x] for x in xs) else None


def candidates(scale):
    for trits in itertools.product((-1, 0, 1), repeat=4):
        yield tuple(scale*t for t in trits)


def squared_error(outputs, target):
    return sum((a-b)**2 for a, b in zip(outputs, target))


def best_joint(scales, target):
    # Eliminate e0 and e2 independently conditional on the shared e1.
    banks = [[(w, tuple(expert(w, x) for x in POS), tuple(expert(w, x) for x in NEG))
              for scale in opts for w in candidates(scale)] for opts in scales]
    tp = tuple(target[x] for x in POS)
    tn = tuple(target[x] for x in NEG)
    result = None
    for w1, p1, n1 in banks[1]:
        ep, w0 = min((sum((v+q-t)**2 for v, q, t in zip(p0, p1, tp)), w)
                     for w, p0, _ in banks[0])
        en, w2 = min((sum((v+q-t)**2 for v, q, t in zip(n2, n1, tn)), w)
                     for w, _, n2 in banks[2])
        trial = (ep+en, (w0, w1, w2))
        if result is None or trial < result:
            result = trial
    return result


def independent(scales):
    banks = []
    for i, opts in enumerate(scales):
        observed = tuple(x for x in DOMAIN if i in ROUTES[x >= 0])
        candidate = min((sum((expert(w, x)-expert(TEACHER[i], x))**2 for x in observed), w)
                        for s in opts for w in candidates(s))
        banks.append(candidate[1])
    return tuple(banks)


def main():
    target = {x: routed(TEACHER, x) for x in DOMAIN}
    branches = {"negative": polynomial(target, NEG), "nonnegative": polynomial(target, POS)}
    assert branches == {"negative": (Fraction(-2), Fraction(15), Fraction(8)),
                        "nonnegative": (Fraction(1), Fraction(27), Fraction(-13))}
    assert all(-128 <= c <= 127 for coeffs in branches.values() for c in coeffs)
    assert all(sum(int(c)*x**(2-i) for i, c in enumerate(branches["nonnegative" if x >= 0 else "negative"])) == target[x] for x in DOMAIN)
    shared = min((best_joint(((s,), (s,), (s,)), target)[0], s) for s in range(1, 9))
    shared_fit = best_joint(((shared[1],),)*3, target)
    separate = best_joint(((1, 2, 3, 4, 5, 6, 7, 8),)*3, target)
    independent_fit = independent(((1, 2, 3, 4, 5, 6, 7, 8),)*3)
    rng = random.Random(20260924)
    random_stats = {"samples": 500, "piecewise_quadratic": 0, "int8_coefficients": 0}
    failure = None
    for _ in range(random_stats["samples"]):
        weights = tuple(tuple(rng.randint(-8, 8) for _ in range(4)) for _ in range(3))
        outputs = {x: routed(weights, x) for x in DOMAIN}
        poly = (polynomial(outputs, NEG), polynomial(outputs, POS))
        if all(p is not None for p in poly):
            random_stats["piecewise_quadratic"] += 1
            if all(c.denominator == 1 and -128 <= c <= 127 for p in poly for c in p):
                random_stats["int8_coefficients"] += 1
        elif failure is None:
            failure = {"weights": weights, "responses": [outputs[x] for x in DOMAIN],
                       "quadratic_on_negative": poly[0] is not None,
                       "quadratic_on_nonnegative": poly[1] is not None}
    print(json.dumps({"domain": DOMAIN, "teacher": TEACHER,
        "teacher_responses": [target[x] for x in DOMAIN],
        "conditional_coefficients": {key: [int(c) for c in value] for key, value in branches.items()},
        "shared_scale_joint": {"scale": shared[1], "sse": shared_fit[0], "weights": shared_fit[1]},
        "separate_scale_joint": {"sse": separate[0], "weights": separate[1]},
        "separate_scale_independent": {"sse": squared_error([routed(independent_fit, x) for x in DOMAIN], [target[x] for x in DOMAIN]), "weights": independent_fit},
        "unstructured": random_stats, "first_failure": failure}, indent=2))


if __name__ == "__main__":
    main()
