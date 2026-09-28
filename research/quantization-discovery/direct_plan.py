#!/usr/bin/env python3
"""Exact chunk partitioning under a weight-bit budget and a declared work proxy."""
from collections import Counter
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def bits(k):
    return (3**k-1).bit_length()


def plan(columns, output_rows, budget, max_chunk=10, reuse=1):
    assert columns > 0 and output_rows > 0 and reuse > 0 and max_chunk > 0
    # Every edge consumes coordinates and fixed payload bits. The state graph is acyclic.
    states = {(0, 0): (0, ())}
    edges = 0
    for used in range(columns):
        for used_bits in range(budget+1):
            entry = states.get((used, used_bits))
            if entry is None:
                continue
            cost, chunks = entry
            for k in range(1, min(max_chunk, columns-used)+1):
                new_bits = used_bits+bits(k)
                if new_bits > budget:
                    continue
                edges += 1
                key = (used+k, new_bits)
                candidate = (cost+3**k-1+output_rows*reuse, chunks+(k,))
                if key not in states or candidate < states[key]:
                    states[key] = candidate
    finals = [(cost, used_bits, chunks) for (used, used_bits), (cost, chunks) in states.items()
              if used == columns]
    if not finals:
        return dict(feasible=False, columns=columns, budget=budget,
                    max_chunk=max_chunk, reachable_states=len(states), transitions=edges)
    cost, used_bits, chunks = min(finals)
    return dict(feasible=True, columns=columns, output_rows=output_rows, query_reuse=reuse,
                budget=budget, max_chunk=max_chunk, weight_bits_per_row=used_bits,
                chunk_lengths=list(chunks), chunk_histogram=dict(sorted(Counter(chunks).items())),
                lookups_per_row=len(chunks), lookup_accumulations=output_rows*reuse*len(chunks),
                table_arithmetic=sum(3**k-1 for k in chunks),
                table_entries=sum(3**k for k in chunks),
                table_bytes_int16=2*sum(3**k for k in chunks),
                peak_one_chunk_table_bytes_int16=2*max(3**k for k in chunks),
                proxy_cost=cost, reachable_states=len(states), transitions=edges)


def partitions(n, maximum):
    if n == 0:
        yield ()
    for k in range(1, min(n, maximum)+1):
        for rest in partitions(n-k, maximum):
            yield (k,)+rest


def checks():
    choices = list(partitions(10, 5))
    for budget in (15, 16, 17, 20):
        actual = plan(10, 37, budget, max_chunk=5)
        allowed = [(sum(3**k-1+37 for k in p), sum(bits(k) for k in p), p)
                   for p in choices if sum(bits(k) for k in p) <= budget]
        assert actual['feasible'] == bool(allowed)
        if allowed:
            cost, used_bits, chunks = min(allowed)
            assert (actual['proxy_cost'], actual['weight_bits_per_row'], tuple(actual['chunk_lengths'])) == (cost, used_bits, chunks)
    return dict(exhaustive_partitions=len(choices), budgets_checked=4)


def main():
    result = dict(checks=checks(),
                  objective='sum_k [(3^k-1) table add/sub operations + output_rows*query_reuse lookup-accumulations]',
                  scope='Exact within contiguous independent base3 chunks of lengths 1..10. Proxy units are not CPU/GPU cycles. Copies, address extraction, SIMD, cache and allocation are not priced.',
                  rows=[plan(128, 5120, b) for b in (204, 205, 206, 208, 210, 214, 224)],
                  reuse=[plan(128, 5120, 208, reuse=r) for r in (1, 8, 64)])
    (HERE/'direct-plan-results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
