#!/usr/bin/env python3
"""Count the emitted inner-loop instructions of each rate_bench kernel.

The model instruction counts in rate_bench.hip are what the map is supposed to cost. This reads
what the compiler actually produced, so the two can be compared instead of assumed equal.

    hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value --cuda-device-only -S \
        rate_bench.hip -o build/rate_bench.s
    python3 count_instructions.py build/rate_bench.s --out results/instruction-counts.json
"""
import argparse
import json
import re
from collections import Counter
from pathlib import Path


def kernel_bodies(lines):
    starts = [(i, l.split(':')[0]) for i, l in enumerate(lines) if l.startswith('_Z')]
    for k, (i, name) in enumerate(starts):
        end = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        yield name, lines[i:end]


def innermost_loop(body):
    """The longest span from a label to a branch back to that same label."""
    best = None
    for j, line in enumerate(body):
        if not re.match(r'^\.LBB\S+:', line):
            continue
        label = line.split(':')[0]
        for m in range(j + 1, len(body)):
            if 's_cbranch' in body[m] and label in body[m]:
                span = body[j + 1:m + 1]
                if best is None or len(span) > len(best):
                    best = span
                break
    return best


def count(span):
    """VALU and matrix instructions only: scalar setup and branches are not the issue cost here."""
    out = []
    for line in span:
        text = line.strip()
        if not text or text.startswith((';', '.', '//')):
            continue
        op = text.split()[0]
        if op.startswith(('v_', 'ds_', 'global_', 'buffer_')):
            out.append(op.split('_e32')[0].split('_e64')[0])
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('assembly', type=Path)
    p.add_argument('--out', type=Path)
    a = p.parse_args()
    lines = a.assembly.read_text().split('\n')
    report = {}
    for name, body in kernel_bodies(lines):
        span = innermost_loop(body)
        if not span:
            continue
        ops = count(span)
        if not ops:
            continue
        report[name] = {'vector_instructions': len(ops), 'by_opcode': dict(Counter(ops).most_common())}
        print(f'{name:46s} {len(ops):5d}  {dict(Counter(ops).most_common(6))}')
    if a.out:
        a.out.write_text(json.dumps(
            {'source': str(a.assembly),
             'scope': 'Vector and memory instructions in each kernel\'s innermost loop, counted '
                      'from the emitted assembly. Scalar instructions, loop control and dual-issue '
                      'packing are not represented.',
             'kernels': report}, indent=2) + '\n')
        print(f'wrote {a.out}')


if __name__ == '__main__':
    main()
