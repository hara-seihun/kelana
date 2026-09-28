#!/usr/bin/env python3
"""Exact copositivity classification and lexicographic maximum-cardinality group matching."""
import csv
import hashlib
import json
from pathlib import Path

import networkx as nx

HERE = Path(__file__).resolve().parent
SOURCE = (
    (HERE / '../kivi-two-bit-dot-native/original-o.bf16', '803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499'),
    (HERE / '../contextual-value-feedback/original-o.bf16', '677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48'),
)


def classification(a, b, d):
    if a == b == d == 0:
        return 'zero'
    positive = a >= 0 and d >= 0 and (b >= 0 or b*b <= 4*a*d)
    negative = a <= 0 and d <= 0 and (b <= 0 or b*b <= 4*a*d)
    if positive and negative:
        raise AssertionError('nonzero polynomial with both signs')
    return '+' if positive else '-' if negative else 'indefinite'


def main():
    for path, expected in SOURCE:
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected, path
        assert path.stat().st_size == 4194304
    groups = {(layer,h,g): [] for layer in range(2) for h in range(8) for g in range(4)}
    counts = [{s: 0 for s in ('+', '-', 'zero', 'indefinite')} for _ in range(2)]
    with (HERE / 'coefficients.tsv').open(newline='') as source, (HERE / 'certificates.tsv').open('w', newline='') as destination:
        reader = csv.DictReader(source, delimiter='\t')
        assert reader.fieldnames == ['layer','head','group','i','j','A','B','D']
        writer = csv.writer(destination, delimiter='\t', lineterminator='\n')
        writer.writerow(('layer', 'head', 'group', 'i', 'j', 'sign', 'fourAD_minus_B2'))
        for row in reader:
            layer,h,g,i,j,a,b,d = (int(row[k]) for k in reader.fieldnames)
            assert 0 <= layer < 2 and 0 <= h < 8 and 0 <= g < 4 and h*128+g*32 <= i < j < h*128+(g+1)*32
            assert len(groups[layer,h,g]) < 496
            sign = classification(a,b,d)
            counts[layer][sign] += 1
            groups[layer,h,g].append((i,j,sign))
            writer.writerow((layer,h,g,i,j,sign,4*a*d-b*b))
    assert all(sum(c.values()) == 8*4*32*31//2 for c in counts)
    summaries = []
    layout = bytearray()
    with (HERE / 'matching.tsv').open('w', newline='') as f:
        writer = csv.writer(f, delimiter='\t', lineterminator='\n')
        writer.writerow(('layer','head','group','i','j','sign'))
        for layer in range(2):
            pairs = []
            distribution = {}
            graph_coverage = 0
            unmatched = 0
            map_start = len(layout)
            for h in range(8):
                for g in range(4):
                    edges = groups[layer,h,g]
                    assert len(edges) == 496
                    assert [(i,j) for i,j,_ in edges] == [(h*128+g*32+a,h*128+g*32+b) for a in range(32) for b in range(a+1,32)]
                    signed = [(i,j,sign) for i,j,sign in edges if sign in ('+','-')]
                    graph_coverage += len(signed)
                    graph = nx.Graph()
                    graph.add_nodes_from(range(h*128+g*32, h*128+(g+1)*32))
                    # Unique descending powers of two choose the lexicographically first
                    # sorted edge list among all maximum-cardinality matchings.
                    for rank,(i,j,_) in enumerate(signed):
                        graph.add_edge(i,j,weight=1 << (len(signed)-1-rank))
                    matching = nx.max_weight_matching(graph, maxcardinality=True)
                    chosen = sorted((min(i,j),max(i,j)) for i,j in matching)
                    signs = {(i,j):sign for i,j,sign in signed}
                    assert len(set(v for edge in chosen for v in edge)) == 2*len(chosen)
                    count = len(chosen)
                    distribution[str(count)] = distribution.get(str(count),0)+1
                    unmatched += 32-2*count
                    layout.append(count)
                    for i,j in chosen:
                        sign = signs[i,j]
                        writer.writerow((layer,h,g,i,j,sign))
                        pairs.append((h,g,i,j,sign))
                        layout.extend((i-(h*128+g*32),j-(h*128+g*32),1 if sign=='+' else 0))
            summaries.append({
                'layer':layer, 'total_pairs':sum(counts[layer].values()),
                'classification_counts':counts[layer], 'signed_graph_edges':graph_coverage,
                'groups':32, 'matching_pairs':len(pairs), 'covered_coordinates':2*len(pairs),
                'unmatched_coordinates':unmatched, 'pairs_per_group_distribution':distribution,
                'matching_sign_counts':{sign:sum(p[-1]==sign for p in pairs) for sign in ('+','-')},
                'pair_map_offset':map_start, 'pair_map_bytes':len(layout)-map_start,
                'pair_map_sha256':hashlib.sha256(layout[map_start:]).hexdigest(),
            })
    (HERE / 'pair-map.bin').write_bytes(layout)
    result = {
        'source_sha256': [expected for _,expected in SOURCE],
        'source_shape': [1024,2048], 'unit': '2^-70 for A,B,D',
        'layers':summaries, 'pair_map_bytes':len(layout),
        'pair_map_sha256':hashlib.sha256(layout).hexdigest(),
        'coefficients_sha256':hashlib.sha256((HERE/'coefficients.tsv').read_bytes()).hexdigest(),
        'certificates_sha256':hashlib.sha256((HERE/'certificates.tsv').read_bytes()).hexdigest(),
        'matching_sha256':hashlib.sha256((HERE/'matching.tsv').read_bytes()).hexdigest(),
    }
    (HERE / 'summary.json').write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    print(json.dumps(result, indent=2, sort_keys=True))

if __name__ == '__main__':
    main()
