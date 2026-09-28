#!/usr/bin/env python3
"""Exact constructive illustration of the all-C binary-mean state bound."""
from fractions import Fraction as F
from itertools import product
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent


def run(transitions, zeros, ones):
    state = 0
    for _ in range(zeros):
        state = transitions[2*state]
    for _ in range(ones):
        state = transitions[2*state+1]
    return state


def witness(transitions, C, s):
    assert C > 0 and s >= 2 and len(transitions) == 2*C
    state = 0
    seen = {}
    for count in range(1, C+2):
        state = transitions[2*state]
        if state in seen:
            n, d = seen[state], count-seen[state]
            break
        seen[state] = count
    else:
        raise AssertionError('finite-state collision absent')
    assert 1 <= n <= C and 1 <= d <= C
    target = s*s*C
    periods = (target-n+d-1)//d
    m = n+periods*d
    assert target <= m < (s*s+1)*C
    ones = s*C
    assert run(transitions, n, 0) == run(transitions, m, 0)
    assert run(transitions, n, ones) == run(transitions, m, ones)
    first, second = F(ones, n+ones), F(ones, m+ones)
    assert first >= F(s, s+1) and second <= F(1, s+1)
    floor = (first-second)/2
    assert floor >= F(s-1, 2*(s+1))
    assert max(n+ones, m+ones) <= (s*s+s+1)*C
    return {'short_zero_prefix': n, 'zero_period': d, 'long_zero_prefix': m,
            'common_ones': ones, 'first_teacher': str(first), 'second_teacher': str(second),
            'forced_worst_error': str(floor), 'max_length': m+ones}


def main():
    C, s = 3, 2
    count = 0
    weakest = None
    maximum_length = 0
    for transitions in product(range(C), repeat=2*C):
        item = witness(transitions, C, s)
        count += 1
        maximum_length = max(maximum_length, item['max_length'])
        if weakest is None or F(item['forced_worst_error']) < F(weakest['forced_worst_error']):
            weakest = dict(item, transition_table=list(transitions))
    result = {'theorem': 'C states, all integers s>=2: some word length<=(s²+s+1)C has error>=(s-1)/(2(s+1))',
              'finite_illustration_C': C, 'finite_illustration_s': s,
              'all_transition_tables_checked': count,
              'no_readout_enumerated': True,
              'theorem_error_floor': str(F(s-1, 2*(s+1))),
              'theorem_horizon': (s*s+s+1)*C,
              'largest_constructed_horizon': maximum_length,
              'weakest_constructed_pair': weakest,
              'precision': 'exact rational',
              'scope': 'deterministic full paid state, all binary words; not randomized or free external counter'}
    (HERE/'capacity.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
