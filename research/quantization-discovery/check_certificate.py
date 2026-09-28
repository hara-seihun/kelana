#!/usr/bin/env python3
"""Replay the entire finite cover, without running the search or trusting its cuts.

The checker shares integer instance/bound evaluators with search.py. It is not
an independent formal verification of Python or the bound evaluator. Lean proves
the mathematical inference rules; exhaustive tests exercise their implementation.
"""
import argparse
import json
from pathlib import Path
from search import Problem, Bounds, add, distance, endpoint_dominates


def check(problem, result):
    nodes = result['certificate']['nodes']
    if not nodes or nodes[0]['path']:
        raise ValueError('missing root')
    if len({tuple(n['path']) for n in nodes}) != len(nodes):
        raise ValueError('duplicate search prefix')
    bounds = Bounds(problem, residues=result['settings']['residues'], dual=result['settings']['dual'])
    states = []
    for node in nodes:
        path = node['path']
        if len(path) > len(problem.blocks):
            raise ValueError('prefix extends beyond instance')
        response, paid = (0,)*len(problem.target), problem.static
        for block, k in zip(problem.blocks, path):
            if not isinstance(k, int) or not 0 <= k < len(block):
                raise ValueError('invalid option')
            response = add(response, block[k].response)
            paid += problem.cost(block[k])
        states.append((response, paid))
    parent_counts = [0]*len(nodes)
    for node in nodes:
        if node['kind'] == 'expanded':
            path = node['path']
            if len(path) >= len(problem.blocks):
                raise ValueError('expanded terminal')
            children = node['children']
            if len(children) != len(problem.blocks[len(path)]):
                raise ValueError('incomplete branch cover')
            for k, child in enumerate(children):
                if not isinstance(child, int) or not 0 <= child < len(nodes):
                    raise ValueError('invalid child')
                if nodes[child]['path'] != path+[k]:
                    raise ValueError('branch is not the required extension')
                parent_counts[child] += 1
    if parent_counts != [0]+[1]*(len(nodes)-1):
        raise ValueError('certificate contains detached or multiply parented prefixes')
    floors, active = {}, set()
    def floor(i):
        if i in floors:
            return floors[i]
        if i in active:
            raise ValueError('cyclic dominance proof')
        active.add(i)
        node = nodes[i]
        response, paid = states[i]
        depth = len(node['path'])
        if node['kind'] == 'expanded':
            value = min(floor(j) for j in node['children'])
        elif node['kind'] == 'dominance':
            j = node['representative']
            if not isinstance(j, int) or not 0 <= j < len(nodes):
                raise ValueError('missing representative')
            if len(nodes[j]['path']) != depth:
                raise ValueError('representative has a different suffix action set')
            other, cost = states[j]
            proof = node.get('proof', 'metric')
            if proof == 'metric':
                if cost+problem.weight*distance(other, response) > paid:
                    raise ValueError('unfunded approximate merge')
            elif proof == 'scalar-endpoints':
                if not endpoint_dominates(problem, bounds, depth, other, cost, response, paid):
                    raise ValueError('invalid scalar endpoint dominance')
            else:
                raise ValueError('unknown dominance proof')
            value = floor(j)
        elif node['kind'] in ('bound', 'frontier'):
            value = bounds.lower(depth, response, paid)
            if value != node['lower']:
                raise ValueError('incorrect local bound')
        elif node['kind'] == 'terminal':
            if depth != len(problem.blocks):
                raise ValueError('incomplete terminal witness')
            value = problem.evaluate(node['path'])['objective']
            if value != node['lower']:
                raise ValueError('incorrect terminal objective')
        else:
            raise ValueError('unknown proof step')
        active.remove(i)
        floors[i] = value
        return value
    root_floor = floor(0)
    upper = problem.evaluate(result['witness']['path'])['objective']
    if not result['lower'] <= root_floor <= upper == result['upper']:
        raise ValueError('claimed interval not justified by cover')
    if result['gap'] != upper-result['lower']:
        raise ValueError('wrong gap')
    return dict(valid=True, nodes=len(nodes), replayed_lower=root_floor,
                reported_lower=result['lower'], upper=upper,
                optimal=root_floor == upper)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('instance', type=Path)
    ap.add_argument('certificate', type=Path)
    a = ap.parse_args()
    p = Problem(json.loads(a.instance.read_text()))
    print(json.dumps(check(p, json.loads(a.certificate.read_text())), indent=2))


if __name__ == '__main__':
    main()
