#!/usr/bin/env python3
"""Exact rational-interval categorical state floors and vocabulary-tree relaxations."""
import json
from fractions import Fraction as F
from functools import cache
from pathlib import Path
from time import perf_counter

SCALE = 1 << 88


def outward(lo, hi):
    return F(lo.numerator * SCALE // lo.denominator, SCALE), F(-((-hi.numerator * SCALE) // hi.denominator), SCALE)


def add(*values):
    return outward(sum((v[0] for v in values), F(0)), sum((v[1] for v in values), F(0)))


def scaled(a, interval):
    values = [a*v for v in interval]
    return outward(min(values), max(values))


@cache
def log_interval(x):
    assert x > 0
    if x == 1:
        return F(0), F(0)
    if x < 1:
        return scaled(-1, log_interval(1/x))
    k = 0
    while x > 2:
        x /= 2
        k += 1
    z = (x-1)/(x+1)
    terms = 24
    total = 2*sum((z**(2*j+1)/(2*j+1) for j in range(terms)), F(0))
    tail = 2*z**(2*terms+1)/((2*terms+1)*(1-z*z))
    base = outward(total-tail, total+tail)
    return add(base, scaled(k, log_interval(F(2)))) if k else base


def minimum(intervals):
    return min(v[0] for v in intervals), min(v[1] for v in intervals)


def trees(tokens):
    if len(tokens) == 1:
        return [tokens[0]]
    first, rest = tokens[0], tokens[1:]
    out = []
    for mask in range((1 << len(rest))-1):
        left = (first,) + tuple(x for i, x in enumerate(rest) if mask >> i & 1)
        right = tuple(x for i, x in enumerate(rest) if not (mask >> i & 1))
        out.extend((a, b) for a in trees(left) for b in trees(right))
    return out


def leaves(tree):
    if isinstance(tree, int):
        return (tree,)
    return leaves(tree[0])+leaves(tree[1])


def nodes(tree):
    if isinstance(tree, int):
        return ()
    a, b = tree
    return ((tuple(sorted(leaves(a))), tuple(sorted(leaves(b)))),) + nodes(a) + nodes(b)


def receipt(interval):
    return {"interval": [str(x) for x in interval], "decimal": [float(x) for x in interval]}


class Study:
    def __init__(self, rows, weights):
        self.p = tuple(tuple(F(x, sum(row)) for x in row) for row in rows)
        self.nu = tuple(F(w, sum(weights)) for w in weights)
        self.n = len(rows)
        self.all = (1 << self.n)-1
        self.assignments = tuple(mask for mask in range(1, self.all+1) if mask & 1)

    def subset(self, mask):
        return [s for s in range(self.n) if mask >> s & 1]

    @cache
    def cluster_node(self, node, mask):
        if not mask:
            return F(0), F(0)
        left, right = node
        ss = self.subset(mask)
        pl = {s: sum(self.p[s][i] for i in left) for s in ss}
        pr = {s: sum(self.p[s][i] for i in right) for s in ss}
        ml = sum(self.nu[s]*pl[s] for s in ss)
        mr = sum(self.nu[s]*pr[s] for s in ss)
        q = ml/(ml+mr)
        value = add(*(add(scaled(self.nu[s]*pl[s], log_interval(pl[s]/((pl[s]+pr[s])*q))),
                          scaled(self.nu[s]*pr[s], log_interval(pr[s]/((pl[s]+pr[s])*(1-q))))) for s in ss))
        return max(F(0), value[0]), max(F(0), value[1])

    @cache
    def cluster_full(self, mask):
        if not mask:
            return F(0), F(0)
        ss = self.subset(mask)
        mass = sum(self.nu[s] for s in ss)
        q = [sum(self.nu[s]*self.p[s][i] for s in ss)/mass for i in range(len(self.p[0]))]
        value = add(*(scaled(self.nu[s]*p, log_interval(p/q[i])) for s in ss for i, p in enumerate(self.p[s])))
        return max(F(0), value[0]), max(F(0), value[1])

    def assigned(self, node, mask):
        return add(self.cluster_node(node, mask), self.cluster_node(node, self.all ^ mask))

    def group_floor(self, group):
        return minimum([add(*(self.assigned(node, mask) for node in group)) for mask in self.assignments])

    def dp_node(self, node):
        left, right = node
        order = sorted(range(self.n), key=lambda s: sum(self.p[s][i] for i in left)/sum(self.p[s][i] for i in left+right))
        choices = []
        for cut in range(1, self.n+1):
            mask = sum(1 << s for s in order[:cut])
            choices.append(self.assigned(node, mask))
        return minimum(choices)

    def run(self):
        exact = minimum([add(self.cluster_full(mask), self.cluster_full(self.all ^ mask)) for mask in self.assignments])
        out = []
        for tree in trees(tuple(range(len(self.p[0])))):
            ns = nodes(tree)
            singleton = add(*(self.dp_node(node) for node in ns))
            for node in ns:
                dp, brute = self.dp_node(node), self.group_floor((node,))
                assert dp[0] <= brute[1] and brute[0] <= dp[1]
            grouped = [add(self.group_floor((ns[i], ns[j])), self.group_floor((ns[k],)))
                       for i,j,k in ((0,1,2),(0,2,1),(1,2,0))]
            joined = self.group_floor(ns)
            assert joined[0] <= exact[1] and exact[0] <= joined[1]
            assert singleton[0] <= min(v[1] for v in grouped)
            assert max(v[0] for v in grouped) <= exact[1]
            for mask in self.assignments:
                chain = add(*(self.assigned(node, mask) for node in ns))
                direct = add(self.cluster_full(mask), self.cluster_full(self.all ^ mask))
                assert chain[0] <= direct[1] and direct[0] <= chain[1]
            out.append({"tree": tree, "independent_nodes": receipt(singleton),
                        "best_two_node_group": receipt((max(x[0] for x in grouped), max(x[1] for x in grouped))),
                        "common_assignment": receipt(joined)})
        return {"teacher_laws": [[str(x) for x in p] for p in self.p], "occupancy": [str(x) for x in self.nu],
                "candidate_state_budget": 2, "distinct_unlabeled_assignments": len(self.assignments),
                "one_state_control": receipt(self.cluster_full(self.all)), "full_categorical_two_state_floor": receipt(exact),
                "trees": out}


def main():
    start = perf_counter()
    crossing = Study([[a*b,a*(4-b),(4-a)*b,(4-a)*(4-b)] for a in (1,3) for b in (1,3)], [1]*4).run()
    generic = Study([[9,1,4,2],[2,7,1,6],[3,2,9,2],[1,3,2,10],[5,5,3,3],[4,2,4,6]], [1,2,1,3,2,1]).run()
    separated = Study([[1000000 if i == j else 1 for j in range(4)] for i in range(4)], [1]*4).run()
    assert max(row["independent_nodes"]["decimal"][1] for row in separated["trees"]) < .0001
    assert separated["full_categorical_two_state_floor"]["decimal"][0] > .69
    natural = next(row for row in crossing["trees"] if row["tree"] == ((0,1),(2,3)))
    assert natural["independent_nodes"]["decimal"][1] < 1e-18
    assert natural["best_two_node_group"]["decimal"][0] > .02
    assert crossing["full_categorical_two_state_floor"]["decimal"][0] > .1
    results = {"contract": "Fixed teacher occupancy; stationary arbitrary categorical emissions; two candidate labels. Trees and analyst certificates are not candidate code. All laws strictly positive.",
               "crossing_label_witness": crossing, "generic_six_law_witness": generic,
               "near_disjoint_support_witness": separated,
               "arithmetic": "24-term rational atanh logarithm intervals after exact power-of-two range reduction; outward rounding at 2^-88. No float participates in bound optimization or acceptance except loose final sanity thresholds.",
               "checks": "All 15 four-token trees, node ordered DP versus exhaustive assignments, all-assignment KL chain identities, monotone group consistency, fully joined/direct equality.",
               "elapsed_seconds": perf_counter()-start}
    Path(__file__).with_name("results.json").write_text(json.dumps(results, indent=2)+"\n")
    for name, result in (("crossing", crossing), ("generic", generic), ("near-disjoint", separated)):
        print(name, "exact", result["full_categorical_two_state_floor"]["decimal"],
              "tree floor range", min(x["independent_nodes"]["decimal"][0] for x in result["trees"]),
              max(x["independent_nodes"]["decimal"][1] for x in result["trees"]))
    print("seconds", results["elapsed_seconds"])


if __name__ == "__main__":
    main()
