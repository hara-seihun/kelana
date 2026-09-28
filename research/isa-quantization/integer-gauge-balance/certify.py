"""Exact integer-gauge optimization and a separately checkable circulation witness."""
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import time
import networkx as nx
import numpy as np

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent / 'qwen-coupled-gamma'


def scaled_matrix(C, e):
    terms = []
    for a, row in enumerate(C):
        for b, x in enumerate(row):
            num, den = float(x).as_integer_ratio()
            assert num >= 0 and den & (den - 1) == 0
            terms.append((a, b, num, 2 * (e[a] - e[b]) - (den.bit_length() - 1)))
    bits = max(0, max(-power for _, _, _, power in terms))
    B = [[0] * len(e) for _ in e]
    for a, b, num, power in terms:
        B[a][b] = num << (power + bits)
    return B, bits


def improving_cut(B):
    n = len(B)
    graph = nx.DiGraph()
    graph.add_nodes_from(range(n + 2))
    source, sink = n, n + 1
    negative_constant = 0
    for a in range(n):
        d = 3 * (sum(B[a]) - sum(B[b][a] for b in range(n)))
        if d > 0:
            graph.add_edge(a, sink, capacity=d)
        elif d < 0:
            graph.add_edge(source, a, capacity=-d)
            negative_constant += d
        for b in range(n):
            if a != b:
                graph.add_edge(a, b, capacity=9 * B[a][b])
    value, (left, _) = nx.minimum_cut(graph, source, sink)
    S = sorted(a for a in left if a < n)
    delta4 = 12 * sum(B[a][b] for a in S for b in range(n) if b not in S)
    delta4 -= 3 * sum(B[a][b] for a in range(n) if a not in S for b in S)
    assert isinstance(value, int) and value + negative_constant == delta4 <= 0
    return S, delta4


def balanced_circulation(B):
    n = len(B)
    graph = nx.DiGraph()
    graph.add_nodes_from(range(n + 2))
    source, sink = n, n + 1
    needed = 0
    for a in range(n):
        supply = sum(B[b][a] for b in range(n)) - sum(B[a])
        if supply > 0:
            graph.add_edge(source, a, capacity=supply)
            needed += supply
        elif supply < 0:
            graph.add_edge(a, sink, capacity=-supply)
        for b in range(n):
            if a != b:
                graph.add_edge(a, b, capacity=3 * B[a][b])
    value, flow = nx.maximum_flow(graph, source, sink)
    assert value == needed
    G = [[B[a][b] + (flow[a][b] if a != b else 0) for b in range(n)] for a in range(n)]
    assert all(B[a][b] <= G[a][b] <= 4 * B[a][b] for a in range(n) for b in range(n))
    assert all(sum(G[a]) == sum(G[b][a] for b in range(n)) for a in range(n))
    return G


def rational_record(x):
    return {'numerator': str(x.numerator), 'denominator': str(x.denominator), 'decimal': float(x)}


def main():
    start = time.monotonic()
    path = SOURCE / 'train-pair-moment.npy'
    C = np.load(path)
    assert C.shape == (64, 64) and C.dtype == np.float64 and (C > 0).all()
    original_e = json.loads((SOURCE / 'prepare.json').read_text())['integer_e']
    e = list(original_e)
    B, bits = scaled_matrix(C, e)
    original = Fraction(sum(map(sum, B)), 1 << bits)
    steps = []
    while True:
        S, delta4 = improving_cut(B)
        if delta4 == 0:
            break
        previous = Fraction(sum(map(sum, B)), 1 << bits)
        change = Fraction(delta4, 4 << bits)
        e = [x + int(a in S) for a, x in enumerate(e)]
        origin = e[0]
        e = [x - origin for x in e]
        B, bits = scaled_matrix(C, e)
        current = Fraction(sum(map(sum, B)), 1 << bits)
        assert current == previous + change and current < previous
        steps.append({'subset_incremented': S, 'delta': rational_record(change), 'F': rational_record(current)})
        assert time.monotonic() - start < 50, 'Do not extend an attended computation past its bounded budget'
    G = balanced_circulation(B)
    witness = {
        'source_npy_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'source_float64_payload_sha256': hashlib.sha256(C.astype('<f8').tobytes()).hexdigest(),
        'contract': 'Stored FP64 train C entries interpreted as exact dyadic rationals; not unrounded source moments',
        'original_exponents': original_e,
        'optimal_exponents': e,
        'common_denominator_power_two': bits,
        'balanced_G_integer': [[str(x) for x in row] for row in G],
        'flow_bounds': 'B <= G <= 4 B, balanced row/column totals; f=(3/4)G is a discrete support',
        'steps': steps,
        'original_F': rational_record(original),
        'optimal_F': rational_record(Fraction(sum(map(sum, B)), 1 << bits)),
        'candidate_policy': 'No gamma replacement or cache image exported; the prior frozen quantizer arm is unchanged',
    }
    (HERE / 'certificate.json').write_text(json.dumps(witness, indent=2) + '\n')
    print(json.dumps({'seconds': time.monotonic() - start, 'cut_steps': len(steps), 'original_F': witness['original_F'], 'optimal_F': witness['optimal_F'], 'changed_exponents': sum(a != b for a, b in zip(original_e, e))}, indent=2))


if __name__ == '__main__':
    main()
