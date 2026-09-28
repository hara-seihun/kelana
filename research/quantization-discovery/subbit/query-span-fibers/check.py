#!/usr/bin/env python3
"""Check the integer-query rank receipts with only the Python standard library."""
import argparse
import json
from pathlib import Path


def rank(rows, prime):
    basis = {}
    for row in rows:
        v = [int(x) % prime for x in row]
        for pivot in sorted(basis):
            coefficient = v[pivot]
            if coefficient:
                v = [(a-coefficient*b) % prime for a, b in zip(v, basis[pivot])]
        pivot = next((i for i, value in enumerate(v) if value), None)
        if pivot is not None:
            inverse = pow(v[pivot], -1, prime)
            basis[pivot] = [(a*inverse) % prime for a in v]
    return len(basis)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('receipts', type=Path, nargs='+')
    args = parser.parse_args()
    count = 0
    for path in args.receipts:
        data = json.loads(path.read_text())
        assert data['prime'] == 65521
        assert len(data['groups']) == 8
        for group in data['groups']:
            assert len(group['heads']) == 2
            for head in group['heads']:
                rows = head['query_codes_positions_1_to_255']
                assert len(rows) == 255 and all(len(row) == 32 and all(-119 <= c <= 119 for c in row) for row in rows)
                witness = [rows[position-1] for position in head['independent_query_positions']]
                assert witness == head['witness_codes'] and rank(witness, 65521) == head['rank'] == 32
                assert head['first_full_rank_query_position'] == 32
                windows = head['future_32_query_windows']
                assert [window['start'] for window in windows] == list(range(1, 210, 16)) + [224]
                for window in windows:
                    start = window['start']
                    assert rank(rows[start-1:start+31], 65521) == window['rank'] == 32
                    count += 1
        assert data['minimum_future_window_rank'] == 32
        print(path.name, 'full-rank future windows', count)
    print('checked', count, 'full-rank 32x32 matrices')


if __name__ == '__main__':
    main()
