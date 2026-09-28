#!/usr/bin/env python3
"""Exact counterexamples separating entropy, marginal cost and continued state."""
from fractions import Fraction as Q
from itertools import combinations, product
from pathlib import Path
import hashlib
import json


def fraction(x):
    return {'exact': str(x), 'float': float(x)}


def shared_page_example():
    # Four root outcomes form a valid probability distribution. B candidates share
    # one accessed page. All page sizes and the total budget are abstract units.
    probabilities = [Q(2,5), Q(1,5), Q(1,5), Q(1,5)]
    pages = ['a','b','b','b']
    sizes = {'a': Q(1), 'b': Q(3,2)}
    limit = Q(3,2)
    def cost(nodes):
        return sum((sizes[p] for p in {pages[n] for n in nodes}), Q(0))
    def benefit(nodes):
        return sum((probabilities[n] for n in nodes), Q(0))
    options = [tuple(c) for k in range(5) for c in combinations(range(4),k)]
    feasible = [c for c in options if cost(c) <= limit]
    optimum = max(feasible,key=benefit)
    selected = []
    while True:
        choices = [i for i in range(4) if i not in selected and cost(selected+[i]) <= limit]
        if not choices:
            break
        chosen = max(choices,key=lambda i: (float('inf') if cost(selected+[i]) == cost(selected)
                                           else probabilities[i]/(cost(selected+[i])-cost(selected))))
        selected.append(chosen)
    assert selected == [0] and optimum == (1,2,3)
    return {'probabilities': [str(p) for p in probabilities], 'page_for_node': pages,
            'page_costs': {k:str(v) for k,v in sizes.items()}, 'budget':str(limit),
            'subsets_enumerated':len(options), 'greedy_nodes':selected,
            'greedy_coverage':fraction(benefit(selected)), 'optimal_nodes':optimum,
            'optimal_coverage':fraction(benefit(optimum)),
            'meaning':'Even marginal probability/byte greed fails with shared activation costs. '
                      'This is a fixed-budget coverage example, not a native layout.'}


def state_example():
    # Exact deterministic target emits ABCABC... . At phase s an action of length n
    # emits the next n correct symbols and moves to (s+n)%3. Costs are stipulated.
    costs = [[1,7,8], [17,21,23], [1,2,3]]
    def cycle_rate(policy):
        state, seen, steps = 0, {}, []
        while state not in seen:
            seen[state] = len(steps)
            n = policy[state]
            steps.append((state,n,costs[state][n-1]))
            state = (state+n)%3
        cycle = steps[seen[state]:]
        return Q(sum(x[1] for x in cycle),sum(x[2] for x in cycle)), cycle
    local = tuple(max(range(1,4),key=lambda n: Q(n,costs[s][n-1])) for s in range(3))
    policies = list(product(range(1,4),repeat=3))
    maximum = max(cycle_rate(p)[0] for p in policies)
    chosen = (2,1,3)
    rho, potential = Q(1), [Q(-5),Q(-16),Q(0)]
    bellman = []
    for s in range(3):
        options = [Q(n)-rho*costs[s][n-1]+potential[(s+n)%3] for n in range(1,4)]
        assert max(options) == potential[s]
        assert options[chosen[s]-1] == potential[s]
        bellman.append([str(v) for v in options])
    assert cycle_rate(local)[0] == Q(3,23)
    assert cycle_rate(chosen)[0] == maximum == 1
    return {'cost_by_start_phase_and_action_length':costs,'local_policy':local,
            'local_long_run_rate':fraction(cycle_rate(local)[0]), 'optimal_policy':chosen,
            'optimal_long_run_rate':fraction(maximum), 'policies_enumerated':len(policies),
            'potential':[str(v) for v in potential],'bellman_action_values':bellman,
            'meaning':'Every action emits the same target stream exactly. Different batch '
                      'boundaries have different stipulated costs. Best immediate tokens/time '
                      'can trap dispatch in expensive phases; continuation value matters.'}


def entropy_example():
    # Eight fair bits or a deterministic answer under two declared access interfaces.
    # This records contracts rather than asserting an unproved circuit lower bound.
    return {'high_entropy_case':{'output_bits':8,'entropy_bits':8,
                                'interface':'Known independent Bernoulli(1/2) law; one supplied random byte is the output.',
                                'target_queries_required':0},
            'zero_entropy_case':{'output_bits':1,'entropy_bits':0,
                                 'interface':'Hidden fixed oracle bit. Exact output must work for either oracle assignment.',
                                 'target_queries_required':1,
                                 'proof':'Before querying, the two possible oracle assignments have identical available '
                                         'state but require distinct deterministic outputs. A query distinguishes them.'},
            'meaning':'Information initially available and access cost matter. This oracle statement '
                      'does not imply a lower bound for white-box neural models with accessible weights.'}


def main():
    result = {'source_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'shared_page':shared_page_example(),'stateful_dispatch':state_example(),
              'entropy_interfaces':entropy_example()}
    Path(__file__).with_name('witnesses.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__ == '__main__':
    main()
