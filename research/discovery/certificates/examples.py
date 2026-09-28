#!/usr/bin/env python3
"""Reproducible certificate inputs, including a deliberately invalid rewrite."""
import json
from pathlib import Path
from export_lean import export

HERE = Path(__file__).resolve().parent


def lit(c): return ['lit', c]
def var(i): return ['var', i]
def add(a, b): return ['add', a, b]
def mul(a, b): return ['mul', a, b]
def neg(a): return mul(lit(-1), a)
def sub(a, b): return add(a, neg(b))
def square(a): return mul(a, a)
def total(*terms):
    result = lit(0)
    for term in terms: result = add(result, term)
    return result


def main():
    x, y = var(0), var(1)
    xx, yy = square(x), square(y)
    # On trits this polynomial is ReLU(x+y). The exported theorem compares
    # polynomial expressions; it does not assume a hardware exp/max meaning.
    gate = mul(lit('1/2'), total(x, y, xx, yy, mul(x, y), neg(mul(xx, yy))))
    contracted = mul(lit('1/2'), total(xx, neg(yy), x, neg(y), neg(mul(x, yy)), mul(xx, y)))
    cases = {
        'gated-pair': {'arity': 2, 'lhs': mul(gate, sub(x, y)), 'rhs': contracted},
        'fourth-power': {'arity': 2, 'lhs': square(square(add(x, y))),
                         'rhs': total(xx, yy, mul(lit(8), mul(x, y)), mul(lit(6), mul(xx, yy)))},
        'invalid-substitution': {'arity': 1, 'lhs': sub(mul(square(add(x, lit(1))), add(x, lit(1))), add(x, lit(1))),
                                 'rhs': lit(0)},
    }
    reports = {}
    for name, spec in cases.items():
        src = HERE / 'examples' / (name + '.json')
        src.parent.mkdir(parents=True, exist_ok=True)
        src.write_text(json.dumps(spec, indent=2) + '\n')
        reports[name] = export(src, src.with_suffix('.lean'))
    assert reports['gated-pair']['equal']
    assert reports['fourth-power']['equal']
    assert reports['invalid-substitution'] == {'equal': False, 'input': {'x0': 1}, 'lhs': '6', 'rhs': '0'}
    # Store portable paths. The source fingerprints, not the checkout directory,
    # identify the proof inputs.
    for report in reports.values():
        if 'certificate' in report:
            report['certificate'] = str(Path(report['certificate']).relative_to(HERE))
    (HERE / 'results.json').write_text(json.dumps(reports, indent=2) + '\n')
    print(json.dumps(reports, indent=2))


if __name__ == '__main__': main()
