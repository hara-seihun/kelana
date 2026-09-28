"""Exact source extremum graph: which centers can avoid worsening every range?"""
import hashlib
import json
import sys
from collections import deque
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent


def tree(edges, root, members, transpose=False):
    seen = {root}
    queue = deque([root])
    result = []
    while queue:
        u = queue.popleft()
        for v in members:
            source = edges[u][v] if transpose else edges[v][u]
            if source < 0 or v in seen:
                continue
            result.append({'from': v if transpose else u,
                           'to': u if transpose else v,
                           'source_row': source})
            seen.add(v)
            queue.append(v)
    assert seen == set(members)
    return result


def source_values():
    certificate = json.loads((HERE / 'certificate.json').read_text())
    source = HERE.parent / 'kivi-value-intern'
    rows = []
    for w in range(8):
        raw = (source / f'train-{w}-events.bin').read_bytes()
        owner = json.loads((source / f'train-{w}-manifest.json').read_text())
        assert hashlib.sha256(raw).hexdigest() == certificate['source_sha256'][w] == owner['events_sha256']
        a = np.frombuffer(raw, dtype='u1').reshape(256,4098)
        assert np.array_equal(a[:,:2].copy().view('<u2').reshape(256), np.arange(1,257))
        words = a[:,2050:].copy().view('<u2').reshape(256,32,32)
        assert np.all((words & 0x7f80) != 0x7f80)
        rows.append((words.astype('<u4') << 16).view('<f4'))
    return np.concatenate(rows), certificate['source_sha256']


def validate(result, values, source_hashes):
    assert result['source_sha256'] == source_hashes
    assert [g['group'] for g in result['groups']] == list(range(32))
    for group in result['groups']:
        v = values[:,group['group'],:]
        covered = []
        for component in group['components']:
            members = component['members']
            root = component['root']
            assert len(set(members)) == len(members) and root in members
            covered.extend(members)
            for kind in ('outward_tree', 'inward_tree'):
                edges = component[kind]
                assert len(edges) == len(members)-1
                for edge in edges:
                    s, lo, hi = edge['source_row'], edge['from'], edge['to']
                    assert 0 <= s < 2048 and lo in members and hi in members
                    assert v[s,lo] == min(v[s]) and v[s,hi] == max(v[s])
                reached = {root}
                for _ in members:
                    for edge in edges:
                        a, b = edge['from'], edge['to']
                        if kind == 'inward_tree':
                            a, b = b, a
                        if a in reached:
                            reached.add(b)
                assert reached == set(members)
        assert sorted(covered) == list(range(32))
        assert group['constant_center_forced'] == (len(group['components']) == 1)
    assert result['constant_center_forced_groups'] == sum(g['constant_center_forced'] for g in result['groups'])


def main():
    values, source_hashes = source_values()
    if sys.argv[1:] == ['check']:
        result = json.loads((HERE / 'range-edges.json').read_text())
        validate(result, values, source_hashes)
        print(f"Validated source edge/tree witnesses; {result['constant_center_forced_groups']} full-group certificates")
        return
    assert not sys.argv[1:]
    groups = []
    for g in range(32):
        v = values[:,g,:]
        lo = v.min(axis=1)
        hi = v.max(axis=1)
        # Entry [d,e] witnesses an edge e->d: e is a minimum, d a maximum.
        edges = np.full((32,32), -1, dtype=np.int32)
        for d in range(32):
            for e in range(32):
                hits = np.flatnonzero((v[:,d] == hi) & (v[:,e] == lo))
                if len(hits):
                    edges[d,e] = int(hits[0])
        reach = (edges.T >= 0) | np.eye(32, dtype=bool)
        for k in range(32):
            reach |= reach[:,k,None] & reach[None,k,:]
        remaining = set(range(32))
        components = []
        edge_list = edges.tolist()
        while remaining:
            root = min(remaining)
            members = [d for d in sorted(remaining) if reach[root,d] and reach[d,root]]
            remaining.difference_update(members)
            outward = tree(edge_list, root, members)
            inward = tree(edge_list, root, members, transpose=True)
            # Independently validate every retained extremum row and tree link.
            for edge in outward + inward:
                s, e, d = edge['source_row'], edge['from'], edge['to']
                assert v[s,e] == lo[s] and v[s,d] == hi[s]
            components.append({'root': root, 'members': members,
                               'outward_tree': outward, 'inward_tree': inward})
        groups.append({'group': g, 'components': components,
                       'edge_count': int(np.sum(edges >= 0)),
                       'constant_center_forced': len(components) == 1})
    result = {'source_sha256': source_hashes,
              'scope': 'All2048 original train arrivals; exact max/min equality in BF16 values, no fit or observer',
              'constant_center_forced_groups': sum(g['constant_center_forced'] for g in groups),
              'groups': groups}
    validate(result, values, source_hashes)
    (HERE / 'range-edges.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'constant_groups': result['constant_center_forced_groups'],
                      'component_sizes': [[len(c['members']) for c in g['components']] for g in groups]}))


if __name__ == '__main__':
    main()
