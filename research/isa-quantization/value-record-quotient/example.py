"""Exact rational observer quotient; no real-cache or native experiment."""
from fractions import Fraction as Q
from pathlib import Path
import json

p = [Q(1, 3)] * 3
ratio = [Q(1, 4), Q(7, 4), Q(1)]
record = [0, 0, 1]
values = [Q(1), Q(3)]
mean = sum(a * r for a, r in zip(p, ratio))
changed = [a * r / mean for a, r in zip(p, ratio)]
base_mass = [sum(p[i] for i in range(3) if record[i] == g) for g in range(2)]
changed_mass = [sum(changed[i] for i in range(3) if record[i] == g) for g in range(2)]
base = sum(p[i] * values[record[i]] for i in range(3))
shifted = sum(changed[i] * values[record[i]] for i in range(3))
grouped = sum(a * v for a, v in zip(changed_mass, values))
tv = sum(abs(a - b) for a, b in zip(p, changed)) / 2
assert base_mass == changed_mass == [Q(2, 3), Q(1, 3)]
assert base == shifted == grouped == Q(5, 3)
assert tv == Q(1, 4)
# Independent key-ratio intervals coalesce exactly to the group intervals.
low, high = [Q(1, 4), Q(1, 4), Q(1)], [Q(4), Q(4), Q(1)]
group_low = [sum(p[i] * low[i] for i in range(3) if record[i] == g) / base_mass[g] for g in range(2)]
group_high = [sum(p[i] * high[i] for i in range(3) if record[i] == g) / base_mass[g] for g in range(2)]
result = {
    'arithmetic': 'exact Fractions, fixed three-position example',
    'base_probability': list(map(str, p)),
    'changed_probability': list(map(str, changed)),
    'both_group_masses': list(map(str, base_mass)),
    'individual_probability_TV': str(tv),
    'base_changed_and_grouped_output': str(base),
    'output_squared_error': '0',
    'group_ratio_low': list(map(str, group_low)),
    'group_ratio_high': list(map(str, group_high)),
}
Path(__file__).with_name('example.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
