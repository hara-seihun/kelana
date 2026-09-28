#!/usr/bin/env python3
"""Construct collisions for a two-head radix-packed direct key dot."""
import json

N = 32
Q = 7
K = 7


def spread(total):
    out = [0] * N
    for i in range(N):
        out[i] = max(-Q, min(Q, total))
        total -= out[i]
    assert total == 0
    return out


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def main():
    key = [1] * N
    q1_left = [0] * N
    q1_right = [1] + [0] * (N - 1)
    rows = []
    for base in range(1, 18):
        q0_left = [0] * N
        q0_right = spread(-base)
        packed_left = [x + base * y for x, y in zip(q0_left, q1_left)]
        packed_right = [x + base * y for x, y in zip(q0_right, q1_right)]
        assert all(-128 <= v <= 127 for v in packed_left + packed_right)
        assert dot(packed_left, key) == dot(packed_right, key) == 0
        assert (dot(q0_left, key), dot(q1_left, key)) == (0, 0)
        assert (dot(q0_right, key), dot(q1_right, key)) == (-base, 1)
        rows.append({'radix': base, 'packed_query_min': -Q * (base + 1),
                     'packed_query_max': Q * (base + 1),
                     'witness_q0_right_nonzero': [[i, v] for i, v in enumerate(q0_right) if v]})
    assert Q * (17 + 1) <= 127 < Q * (18 + 1)
    sufficient_radix = 2 * N * Q * K + 1
    assert Q * (sufficient_radix + 1) <= 32767
    print(json.dumps({'domain': {'coordinates': N, 'heads': 2, 'query_min': -Q,
                                  'query_max': Q, 'key_min': -K, 'key_max': K},
                      'signed_byte_largest_radix': 17,
                      'collisions_for_every_signed_byte_radix': rows,
                      'sufficient_full_domain_radix': sufficient_radix,
                      'signed_halfword_packed_query_abs_max': Q * (sufficient_radix + 1),
                      'signed_halfword_packed_dot_abs_max': N * Q * (sufficient_radix + 1) * K,
                      'independent_signed_nibble_dot8_count_per_32_coordinates': 8}, indent=2))


if __name__ == '__main__':
    main()
