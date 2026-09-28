#!/usr/bin/env python3
"""Exact robust assignment for affine integer producer domains.

All objective arithmetic is integer. A domain's denominator converts its integer
numerators to physical input units. State limits return unfinished, not optimal.
"""
from dataclasses import dataclass
from itertools import product


def dot(a, b):
    assert len(a) == len(b)
    return sum(x*y for x, y in zip(a, b))


@dataclass(frozen=True)
class Domain:
    center: tuple
    generators: tuple
    residual: tuple
    denominator: int = 1
    radii: tuple | None = None

    def __post_init__(self):
        n = len(self.center)
        assert self.denominator > 0 and len(self.residual) == n
        assert all(r >= 0 for r in self.residual)
        assert all(len(g) == n for g in self.generators)
        if self.radii is None:
            object.__setattr__(self, 'radii', (1,)*len(self.generators))
        assert len(self.radii) == len(self.generators) and all(r >= 0 for r in self.radii)

    def support(self, error):
        """Numerator of max |error.x| with independent bounded integer coefficients."""
        return (abs(dot(error, self.center)) +
                sum(r*abs(dot(error, g)) for r, g in zip(self.radii, self.generators)) +
                sum(r*abs(e) for r, e in zip(self.residual, error)))

    def witness(self, error):
        sign = lambda x: 1 if x >= 0 else -1
        orientation = sign(dot(error, self.center))
        latent = [orientation*r*sign(dot(error, g)) for r, g in zip(self.radii, self.generators)]
        point = [c + sum(z*g[i] for z, g in zip(latent, self.generators)) +
                 orientation*sign(e)*r
                 for i, (c, e, r) in enumerate(zip(self.center, error, self.residual))]
        assert abs(dot(error, point)) == self.support(error)
        return dict(numerator=point, denominator=self.denominator, latent=latent)


@dataclass(frozen=True)
class Choice:
    label: str
    cost: int
    factors: tuple


@dataclass(frozen=True)
class Assignment:
    blocks: tuple
    static: int
    price: int
    denominator: int = 1

    def __post_init__(self):
        assert self.blocks and all(self.blocks)
        assert self.static >= 0 and self.price >= 0 and self.denominator > 0
        count = len(self.blocks[0][0].factors)
        assert all(o.cost >= 0 and len(o.factors) == count for b in self.blocks for o in b)

    def evaluate(self, path):
        assert len(path) == len(self.blocks)
        selected = [block[k] for block, k in zip(self.blocks, path)]
        sums = tuple(sum(o.factors[j] for o in selected)
                     for j in range(len(self.blocks[0][0].factors)))
        return self.static + sum(o.cost for o in selected) + self.price*sum(map(abs, sums))


def compile_domain(weights, block_menus, domain, static_bits=0, price=1):
    """Menu entries: (label, integer block weights, stored bits)."""
    assert len(weights) == len(domain.center) and price >= 0
    factors = (domain.center,) + tuple(tuple(r*v for v in g)
                                      for r, g in zip(domain.radii, domain.generators))
    start, blocks = 0, []
    for menu in block_menus:
        width = len(menu[0][1])
        choices = []
        for label, values, bits in menu:
            assert len(values) == width and bits >= 0
            error = tuple(v-w for v, w in zip(values, weights[start:start+width]))
            projected = tuple(dot(error, f[start:start+width]) for f in factors)
            residual = sum(r*abs(e) for r, e in zip(domain.residual[start:start+width], error))
            choices.append(Choice(label, bits*domain.denominator + price*residual, projected))
        start += width
        blocks.append(tuple(choices))
    assert start == len(weights)
    return Assignment(tuple(blocks), static_bits*domain.denominator, price, domain.denominator)


def replay_dual(problem, denominator, probes):
    """Integer-only replay of a rational signed-L1 lower-bound certificate."""
    assert isinstance(denominator, int) and denominator > 0
    assert len(probes) == len(problem.blocks[0][0].factors)
    assert all(isinstance(p, int) and abs(p) <= denominator for p in probes)
    minima = [min(denominator*o.cost + problem.price*dot(probes, o.factors) for o in block)
              for block in problem.blocks]
    numerator = denominator*problem.static + sum(minima)
    return dict(lower_numerator=-((-numerator)//denominator), block_minima=minima)


def lifetimes(problem):
    count = len(problem.blocks[0][0].factors)
    first, last = [len(problem.blocks)]*count, [-1]*count
    for i, block in enumerate(problem.blocks):
        for j in range(count):
            if any(o.factors[j] != 0 for o in block):
                first[j] = min(first[j], i)
                last[j] = i
    return first, last


def frontier_dp(problem, max_states=20000, close_factors=True):
    """Close dead factors, then retain cheapest history per live response tuple."""
    first, last = lifetimes(problem)
    if not close_factors:
        last = [len(problem.blocks)-1 if j >= 0 else -1 for j in last]
    states, previous = {(): (problem.static, ())}, ()
    transitions = peak = max_live = 0
    for depth, block in enumerate(problem.blocks):
        current = tuple(j for j in range(len(first)) if first[j] <= depth <= last[j])
        keep = tuple(j for j in current if last[j] > depth)
        close = tuple(j for j in current if last[j] == depth)
        positions = {j: k for k, j in enumerate(previous)}
        following = {}
        for values, (cost, path) in states.items():
            for k, option in enumerate(block):
                total = {j: (values[positions[j]] if j in positions else 0) + option.factors[j]
                         for j in current}
                key = tuple(total[j] for j in keep)
                paid = cost + option.cost + problem.price*sum(abs(total[j]) for j in close)
                transitions += 1
                if key not in following or paid < following[key][0]:
                    following[key] = paid, path+(k,)
                if len(following) > max_states:
                    return dict(status='width-limit', completed_blocks=depth,
                                partial_next_states=len(following), transitions=transitions,
                                peak_states=max(peak, len(following)), max_live=max(max_live, len(keep)))
        states, previous = following, keep
        peak, max_live = max(peak, len(states)), max(max_live, len(keep))
    optimum, path = states[()]
    assert problem.evaluate(path) == optimum
    return dict(status='optimal', objective_numerator=optimum, denominator=problem.denominator,
                path=list(path), transitions=transitions, peak_states=peak, max_live=max_live)


def exhaustive(problem):
    return min(problem.evaluate(p) for p in product(*(range(len(b)) for b in problem.blocks)))


def coordinate_search(problem, passes=4):
    """Feasible incumbent only; no optimality claim."""
    best = None
    evaluations = 0
    for start in (0, -1):
        path = [start % len(b) for b in problem.blocks]
        value = problem.evaluate(path)
        evaluations += 1
        for _ in range(passes):
            changed = False
            for i, block in enumerate(problem.blocks):
                old = path[i]
                chosen, score = old, value
                for k in range(len(block)):
                    path[i] = k
                    trial = problem.evaluate(path)
                    evaluations += 1
                    if trial < score:
                        chosen, score = k, trial
                path[i], value = chosen, score
                changed |= chosen != old
            if not changed:
                break
        if best is None or value < best['objective_numerator']:
            best = dict(objective_numerator=value, denominator=problem.denominator, path=path[:])
    best.update(status='feasible', evaluations=evaluations)
    return best
