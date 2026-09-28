"""Exact scalar ratio-box support by sorting, not a vertex census."""
from fractions import Fraction as Q
from itertools import groupby
from pathlib import Path
import json


def ratio_max(p, low, high, values):
    assert p and len(p) == len(low) == len(high) == len(values)
    assert all(w > 0 and 0 < l <= h for w, l, h in zip(p, low, high))
    order = sorted(range(len(p)), key=values.__getitem__)
    numerator = sum(w * h * v for w, h, v in zip(p, high, values))
    denominator = sum(w * h for w, h in zip(p, high))
    previous = None
    for boundary, group in groupby(order, key=values.__getitem__):
        root = numerator / denominator
        if (previous is None or previous <= root) and root <= boundary:
            break
        for i in group:
            change = p[i] * (low[i] - high[i])
            numerator += change * values[i]
            denominator += change
        previous = boundary
    else:
        root = numerator / denominator
        assert previous <= root
    witness = [h if v >= root else l for l, h, v in zip(low, high, values)]
    assert all(l <= r <= h for l, r, h in zip(low, witness, high))
    assert sum(w * r * (v - root) for w, r, v in zip(p, witness, values)) == 0
    return root, witness


def observed(p, r, values):
    return sum(w * x * v for w, x, v in zip(p, r, values)) / sum(w * x for w, x in zip(p, r))


def main():
    p = [Q(1, 3)] * 3
    low, high = [Q(1, 4), Q(1, 4), Q(1)], [Q(4), Q(4), Q(1)]
    values = [Q(0), Q(0), Q(1)]
    upper, maximizing = ratio_max(p, low, high, values)
    opposite, minimizing = ratio_max(p, low, high, [-v for v in values])
    lower = -opposite
    baseline = observed(p, [Q(1)] * 3, values)
    exact_error = max(upper - baseline, baseline - lower)
    tv_bound = Q(3, 5)
    assert (lower, upper, baseline, exact_error) == (Q(1, 9), Q(2, 3), Q(1, 3), Q(1, 3))
    assert observed(p, maximizing, values) == upper
    assert observed(p, minimizing, values) == lower
    assert exact_error ** 2 < tv_bound ** 2
    shared = [Q(1, 4), Q(4), Q(1)]
    cancelled = observed(p, shared, values) + observed(p, shared, [-v for v in values])
    assert cancelled == 0
    independent_max = upper + opposite
    assert independent_max == Q(5, 9)
    results = {
        'arithmetic': 'exact rational; sorted scalar support, no vertex enumeration',
        'baseline': str(baseline), 'min': str(lower), 'max': str(upper),
        'minimum_witness': list(map(str, minimizing)),
        'maximum_witness': list(map(str, maximizing)),
        'exact_squared_error': str(exact_error ** 2),
        'tv_diameter_squared_bound': str(tv_bound ** 2),
        'shared_two_head_output': str(cancelled),
        'independent_two_head_box_maximum': str(independent_max),
    }
    Path(__file__).with_name('ratio-support.json').write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
