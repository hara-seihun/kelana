#!/usr/bin/env python3
"""Bounded-work search over additive, consumer-observed representation choices.

Integer arithmetic only. No external packages. The domain and cost model are
explicit in each instance; this is not an ISA compiler or a full-model quantizer.
"""
import argparse
from dataclasses import dataclass
import heapq
import itertools
import json
import math
from pathlib import Path
import time


@dataclass(frozen=True)
class Option:
    label: str
    response: tuple
    bits: int
    ops: int = 0


class Problem:
    def __init__(self, record):
        self.record = record
        self.target = tuple(record['target'])
        self.weight = record.get('error_price', 1)
        self.op_price = record.get('operation_price', 0)
        self.static = record.get('static_bits', 0)
        self.blocks = [[Option(o['label'], tuple(o['response']), o['bits'], o.get('ops', 0))
                        for o in block] for block in record['blocks']]
        if not self.blocks or not self.target or any(not b for b in self.blocks):
            raise ValueError('nonempty blocks and observation domain required')
        if min(self.weight, self.op_price, self.static) < 0:
            raise ValueError('prices and costs must be nonnegative')
        if any(len(o.response) != len(self.target) or min(o.bits, o.ops) < 0
               for b in self.blocks for o in b):
            raise ValueError('inconsistent observations or negative cost')

    def cost(self, option):
        return option.bits + self.op_price * option.ops

    def evaluate(self, path):
        options = [b[k] for b, k in zip(self.blocks, path)]
        if len(options) != len(self.blocks):
            raise ValueError('incomplete witness')
        response = tuple(sum(o.response[j] for o in options) for j in range(len(self.target)))
        error = distance(response, self.target)
        bits = self.static + sum(o.bits for o in options)
        ops = sum(o.ops for o in options)
        return dict(objective=bits + self.op_price * ops + self.weight * error,
                    bits=bits, operations=ops, error=error, response=response,
                    path=list(path), labels=[o.label for o in options])


def distance(a, b):
    return max((abs(x-y) for x, y in zip(a, b)), default=0)


def add(a, b):
    return tuple(x+y for x, y in zip(a, b))


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def progression_distance(target, low, high, base, step):
    """Distance to [low,high] intersect (base + step*Z); step=0 means singleton.

The caller supplies a nonempty relaxation. Endpoints originate in actual
choices, so this intersection cannot be empty in the suffix relaxation.
"""
    if step == 0:
        return abs(target-base)
    first = base + (-((base-low)//step)) * step
    last = base + ((high-base)//step) * step
    if first > last:
        raise ValueError('empty arithmetic progression relaxation')
    k = (target-first)//step
    x = min(last, max(first, first+k*step))
    y = min(last, max(first, x+step))
    return min(abs(target-x), abs(target-y))


class Bounds:
    def __init__(self, problem, residues=True, pairs=True, dual=True):
        self.p = problem
        m, n = len(problem.target), len(problem.blocks)
        self.probes = [tuple(int(i == j) for j in range(m)) for i in range(m)]
        if pairs:
            self.probes += [tuple(int(k == i)-int(k == j) for k in range(m))
                            for i in range(m) for j in range(i)]
        self.norms = [sum(map(abs, a)) for a in self.probes]
        self.target = [dot(a, problem.target) for a in self.probes]
        self.suffix = [[(0, 0, 0, 0) for _ in self.probes] for _ in range(n+1)]
        self.costs = [0]*(n+1)
        self.residues = residues
        self.dual = []
        if dual:
            for a, norm in zip(self.probes, self.norms):
                for sign in (-1, 1):
                    signed = tuple(sign*x for x in a)
                    for temperature in (1, 4, 16, 64, 256):
                        denominator = norm*temperature
                        suffix = [0]*(n+1)
                        for i in range(n-1, -1, -1):
                            suffix[i] = suffix[i+1] + min(
                                denominator*problem.cost(o)+problem.weight*dot(signed, o.response)
                                for o in problem.blocks[i])
                        self.dual.append((signed, denominator, dot(signed, problem.target), suffix))
        for i in range(n-1, -1, -1):
            self.costs[i] = self.costs[i+1] + min(map(problem.cost, problem.blocks[i]))
            for j, a in enumerate(self.probes):
                vals = [dot(a, o.response) for o in problem.blocks[i]]
                lo, hi, base, step = self.suffix[i+1][j]
                g = math.gcd(*(v-vals[0] for v in vals))
                self.suffix[i][j] = (lo+min(vals), hi+max(vals), base+vals[0], math.gcd(step, g))

    def lower(self, depth, response, paid):
        error = 0
        for a, target, norm, (lo, hi, base, step) in zip(
                self.probes, self.target, self.norms, self.suffix[depth]):
            remaining = target-dot(a, response)
            if self.residues:
                delta = progression_distance(remaining, lo, hi, base, step)
            else:
                delta = max(lo-remaining, remaining-hi, 0)
            error = max(error, (delta+norm-1)//norm)
        lower = paid + self.costs[depth] + self.p.weight * error
        for a, denominator, target, suffix in self.dual:
            numerator = denominator*paid + self.p.weight*(dot(a, response)-target) + suffix[depth]
            lower = max(lower, -((-numerator)//denominator))
        return lower


def endpoint_dominates(problem, bounds, depth, left, left_cost, right, right_cost):
    if len(left) != 1:
        return False
    low, high, _, _ = bounds.suffix[depth][0]
    target = problem.target[0]
    return all(left_cost + problem.weight*abs(left[0]+s-target) <=
               right_cost + problem.weight*abs(right[0]+s-target) for s in (low, high))


def seed(problem):
    """Deterministic feasible upper bound; its work is reported separately."""
    n = len(problem.blocks)
    starts = [[min(range(len(b)), key=lambda k: problem.cost(b[k])) for b in problem.blocks],
              [len(b)-1 for b in problem.blocks]]
    best = None
    evaluations = 0
    for path in starts:
        value = problem.evaluate(path)
        evaluations += 1
        for _ in range(2):
            changed = False
            for i, block in enumerate(problem.blocks):
                for k in range(len(block)):
                    trial = path.copy()
                    trial[i] = k
                    candidate = problem.evaluate(trial)
                    evaluations += 1
                    if candidate['objective'] < value['objective']:
                        path, value, changed = trial, candidate, True
            if not changed:
                break
        if best is None or value['objective'] < best['objective']:
            best = value
    return best, evaluations


def search(problem, max_expansions=1000, seconds=10.0, residues=True,
           dominance=True, representative_cap=64, initial=None, certificate=False, dual=True,
           endpoints=True):
    start = time.perf_counter()
    bounds = Bounds(problem, residues=residues, dual=dual)
    incumbent, seed_evals = seed(problem) if initial is None else (problem.evaluate(initial), 0)
    zero = (0,)*len(problem.target)
    root_lower = bounds.lower(0, zero, problem.static)
    records = [dict(path=[], kind='frontier', lower=root_lower)]
    heap = [(root_lower, 0, 0, zero, problem.static, ())]
    representatives = [[] for _ in range(len(problem.blocks)+1)]
    exact = [{} for _ in range(len(problem.blocks)+1)]
    exact[0][zero] = (problem.static, 0)
    expanded = generated = dropped_exact = dropped_metric = dropped_endpoint = comparisons = 0
    peak_frontier = 1
    stop = 'work-budget'
    while heap:
        if heap[0][0] >= incumbent['objective']:
            stop = 'optimal'
            break
        if expanded >= max_expansions:
            break
        if time.perf_counter()-start >= seconds:
            stop = 'time-budget'
            break
        lower, node_id, depth, response, paid, path = heapq.heappop(heap)
        previous = exact[depth].get(response)
        if previous is not None and paid > previous[0]:
            records[node_id].update(kind='dominance', representative=previous[1])
            dropped_exact += 1
            continue
        expanded += 1
        records[node_id].update(kind='expanded', children=[])
        for k, option in enumerate(problem.blocks[depth]):
            generated += 1
            d = depth+1
            r, c = add(response, option.response), paid+problem.cost(option)
            new_path = path+(k,)
            child_id = len(records)
            child = dict(path=list(new_path), kind='frontier')
            records.append(child)
            records[node_id]['children'].append(child_id)
            if d == len(problem.blocks):
                witness = problem.evaluate(new_path)
                child.update(kind='terminal', lower=witness['objective'])
                if witness['objective'] < incumbent['objective']:
                    incumbent = witness
                continue
            lb = bounds.lower(d, r, c)
            child['lower'] = lb
            if lb >= incumbent['objective']:
                child['kind'] = 'bound'
                continue
            previous = exact[d].get(r)
            if previous is not None and previous[0] <= c:
                child.update(kind='dominance', representative=previous[1])
                dropped_exact += 1
                continue
            if dominance:
                dominated = False
                for other, cost, representative in representatives[d]:
                    comparisons += 1
                    if cost + problem.weight*distance(other, r) <= c:
                        child.update(kind='dominance', representative=representative, proof='metric')
                        dropped_metric += 1
                        dominated = True
                        break
                    if endpoints and endpoint_dominates(problem, bounds, d, other, cost, r, c):
                        child.update(kind='dominance', representative=representative, proof='scalar-endpoints')
                        dropped_endpoint += 1
                        dominated = True
                        break
                if dominated:
                    continue
            exact[d][r] = (c, child_id)
            if len(representatives[d]) < representative_cap:
                representatives[d].append((r, c, child_id))
            heapq.heappush(heap, (lb, child_id, d, r, c, new_path))
        peak_frontier = max(peak_frontier, len(heap))
    if not heap:
        stop = 'optimal'
    lower = min(incumbent['objective'], heap[0][0]) if heap else incumbent['objective']
    if lower == incumbent['objective']:
        stop = 'optimal'
    result = dict(lower=lower, upper=incumbent['objective'], gap=incumbent['objective']-lower,
                stop=stop, witness=incumbent, expanded=expanded, generated=generated,
                exact_prunes=dropped_exact, metric_prunes=dropped_metric, endpoint_prunes=dropped_endpoint,
                dominance_comparisons=comparisons, seed_evaluations=seed_evals,
                peak_frontier=peak_frontier, retained_exact_states=sum(map(len, exact)),
                elapsed_seconds=time.perf_counter()-start,
                settings=dict(max_expansions=max_expansions, seconds=seconds,
                              residues=residues, dominance=dominance, dual=dual, endpoints=endpoints,
                              representative_cap=representative_cap))
    if certificate:
        result['certificate'] = dict(format='kelana-quantization-cover/1', nodes=records)
    return result


def exact_dp(problem, metric=False, endpoints=False):
    """Exact layered solver. Only used on declared small-width families."""
    states = {(0,)*len(problem.target): problem.static}
    transitions = merged = 0
    peak = 1
    bounds = Bounds(problem, dual=False) if endpoints else None
    for depth, block in enumerate(problem.blocks, 1):
        next_states = {}
        for response, paid in states.items():
            for o in block:
                transitions += 1
                r, c = add(response, o.response), paid+problem.cost(o)
                if r not in next_states or c < next_states[r]:
                    next_states[r] = c
        if metric or endpoints:
            kept = {}
            def dominates(a, ca, b, cb):
                return ((metric and ca + problem.weight*distance(a, b) <= cb) or
                        (endpoints and endpoint_dominates(problem, bounds, depth, a, ca, b, cb)))
            for r, c in sorted(next_states.items(), key=lambda x: (x[1], x[0])):
                if any(dominates(kr, kc, r, c) for kr, kc in kept.items()):
                    merged += 1
                else:
                    removed = [kr for kr, kc in kept.items() if dominates(r, c, kr, kc)]
                    for kr in removed:
                        del kept[kr]
                    merged += len(removed)
                    kept[r] = c
            next_states = kept
        states = next_states
        peak = max(peak, len(states))
    optimum = min(c+problem.weight*distance(r, problem.target) for r, c in states.items())
    return dict(optimum=optimum, peak_states=peak, transitions=transitions,
                dominance_prunes=merged, final_states=len(states))


def exhaustive(problem):
    return min(problem.evaluate(path)['objective'] for path in
               itertools.product(*(range(len(b)) for b in problem.blocks)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('instance', type=Path)
    ap.add_argument('--expansions', type=int, default=1000)
    ap.add_argument('--seconds', type=float, default=10)
    ap.add_argument('--no-residues', action='store_true')
    ap.add_argument('--no-dominance', action='store_true')
    a = ap.parse_args()
    if not 0 < a.seconds < 60 or a.expansions < 0:
        ap.error('seconds must be in (0,60), expansions nonnegative')
    p = Problem(json.loads(a.instance.read_text()))
    print(json.dumps(search(p, a.expansions, a.seconds, not a.no_residues,
                            not a.no_dominance), indent=2))


if __name__ == '__main__':
    main()
