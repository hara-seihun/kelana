#!/usr/bin/env python3
"""Count the instructions in each measured kernel's inner loop.

  hipcc --offload-arch=gfx1151 -O3 -std=c++17 -Wno-unused-value --cuda-device-only -S bench.cpp -o kernels.s
  ./count-ops.py kernels.s
"""
import collections, re, sys

src = open(sys.argv[1] if len(sys.argv) > 1 else "kernels.s").read()
for chunk in re.split(r'\n(?=[_A-Za-z0-9]+:\s*;+ @)', src):
    m = re.match(r'([_A-Za-z0-9]+):', chunk)
    if not m or ('core' not in m.group(1) and 'raw' not in m.group(1)):
        continue
    lines = [l.strip() for l in chunk.split('\n')]
    labels = {mm.group(1): i for i, l in enumerate(lines) if (mm := re.match(r'(\.LBB[\w\.]+):', l))}
    span = None
    for i, l in enumerate(lines):
        mm = re.search(r's_cbranch\w*\s+(\.LBB[\w\.]+)', l)
        if mm and labels.get(mm.group(1), i) < i:
            cand = (labels[mm.group(1)], i)
            if span is None or cand[1] - cand[0] > span[1] - span[0]:
                span = cand
    if not span:
        continue
    ops = collections.Counter(mm.group(1) for l in lines[span[0]:span[1] + 1]
                              if (mm := re.match(r'([sv]_[a-z0-9_]+)', l)))
    print(f"== {m.group(1)}  loop instructions {sum(ops.values())}")
    for op, n in ops.most_common(14):
        print(f"     {n:4d}  {op}")
