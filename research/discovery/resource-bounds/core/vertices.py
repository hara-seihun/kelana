"""Bounded exact vertex proposals for small certificate LPs.

Returns checked candidate points and search coverage, not an optimizer verdict.
Optimality is established elsewhere by matching independently checked dual and
primal witnesses. Larger spaces return a partial result under an explicit budget.
"""
from fractions import Fraction as Q
from itertools import combinations
from math import comb
from time import monotonic


def square_solve(rows, rhs):
    n = len(rows)
    a = [[Q(x) for x in row]+[Q(b)] for row, b in zip(rows, rhs)]
    for col in range(n):
        pivot = next((r for r in range(col, n) if a[r][col]), None)
        if pivot is None:
            return None
        a[col], a[pivot] = a[pivot], a[col]
        divisor = a[col][col]
        a[col] = [v/divisor for v in a[col]]
        for row in range(n):
            if row != col and a[row][col]:
                factor = a[row][col]
                a[row] = [v-factor*w for v, w in zip(a[row], a[col])]
    return [row[-1] for row in a]


def minimum_vertex(objective, inequalities, rhs, equalities=(), equality_rhs=(),
                   max_bases=20000, max_seconds=3):
    """x>=0 is implicit; rows use <=. Equalities supplied here are independent."""
    c = list(map(Q, objective))
    n = len(c)
    a = [list(map(Q, row)) for row in inequalities]
    b = list(map(Q, rhs))
    e = [list(map(Q, row)) for row in equalities]
    eb = list(map(Q, equality_rhs))
    if len(a) != len(b) or len(e) != len(eb) or any(len(row) != n for row in a+e):
        raise ValueError("vertex problem shape mismatch")
    if len(e) > n:
        raise ValueError("too many supplied independent equalities")
    a += [[Q(-int(i == j)) for i in range(n)] for j in range(n)]
    b += [Q(0)]*n
    active = n-len(e)
    total = comb(len(a), active)
    start = monotonic()
    examined = 0
    best = point = None
    for indices in combinations(range(len(a)), active):
        if examined >= max_bases or monotonic()-start >= max_seconds:
            break
        examined += 1
        x = square_solve(e+[a[i] for i in indices], eb+[b[i] for i in indices])
        if x is None or any(sum(v*w for v, w in zip(row, x)) > bound for row, bound in zip(a, b)):
            continue
        if any(sum(v*w for v, w in zip(row, x)) != bound for row, bound in zip(e, eb)):
            continue
        value = sum(v*w for v, w in zip(c, x))
        if best is None or value < best:
            best, point = value, x
    return {"point": point, "objective": best, "bases_examined": examined, "total_bases": total,
            "enumeration_complete": examined == total,
            "limits": {"max_bases": max_bases, "max_seconds": max_seconds}}
