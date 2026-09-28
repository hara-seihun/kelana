#!/usr/bin/env python3
"""Count the weight-path instructions each projection kernel actually issues per 128-block.

Reads compiled gfx1151 assembly, finds the k_proj instantiations, and reports the VALU
instructions in the block loop body together with the matrix instructions they feed. This is
what the expansion costs; it is read from the emitted ISA, not estimated from source.
"""
import re, sys, collections, json

def kernels(src):
    for m in re.finditer(r'^(_ZN12_GLOBAL__N_16k_proj\w+):', src, re.M):
        name = m.group(1)
        end = src.find('.Lfunc_end', m.end())
        yield name, src[m.end():end]

def label(name):
    tt = re.search(r'ILi(\d)E', name).group(1)
    nums = re.findall(r'ELi(\d)ELb([01])E', name)
    wmap = re.search(r'ILi\d+ELi(\d)ELb([01])E', name)
    return int(tt), int(wmap.group(1)), wmap.group(2) == '1'

WMAP = {0: 'dense5 (1.625 bpw)', 1: 'paircode narrow (2.000 bpw)', 2: 'paircode wide (2.000 bpw)'}

def main(path):
    src = open(path).read()
    rows = []
    for name, body in kernels(src):
        tt, wmap, fuse = label(name)
        ops = collections.Counter()
        for line in body.split('\n'):
            m = re.match(r'\s*([a-z][a-z0-9_]*)', line)
            if m and m.group(1).startswith(('v_', 's_', 'global_', 'ds_', 'scratch_')):
                ops[m.group(1)] += 1
        wmma = ops.get('v_wmma_i32_16x16x16_iu4', 0)
        if not wmma:
            continue
        valu = sum(c for k, c in ops.items() if k.startswith('v_'))
        loads = sum(c for k, c in ops.items() if k.startswith('global_load'))
        # Counts are for the whole kernel body. dense5 and paircode-wide unroll all eight K16
        # slices of a block, so their bodies hold one complete block iteration and differ only in
        # the weight path; paircode-narrow keeps its slice loop rolled, so its body holds one
        # slice and its per-matrix-instruction figure is not comparable with theirs.
        unrolled = wmma == 8 * 2 * tt
        rows.append(dict(kernel=name, tt=tt, wmap=WMAP[wmap], fused=fuse, unrolled=unrolled,
                         wmma=wmma, valu=valu, loads=loads,
                         pk=ops.get('v_pk_mul_lo_u16', 0) + ops.get('v_pk_lshrrev_b16', 0),
                         perm=ops.get('v_perm_b32', 0),
                         valu_per_wmma=round(valu / wmma, 2) if unrolled else None))
    rows.sort(key=lambda r: (r['wmap'], r['tt']))
    print(f"{'weight path':30s} {'TT':>3} {'fuse':>5} {'iu4':>4} {'valu':>5} {'perm':>5} "
          f"{'pk':>4} {'ld':>4} {'valu/iu4':>9}")
    for r in rows:
        v = f"{r['valu_per_wmma']:9.2f}" if r['valu_per_wmma'] is not None else "   rolled"
        print(f"{r['wmap']:30s} {r['tt']:3d} {str(r['fused']):>5} {r['wmma']:4d} {r['valu']:5d} "
              f"{r['perm']:5d} {r['pk']:4d} {r['loads']:4d} {v}")
    if len(sys.argv) > 2:
        json.dump(rows, open(sys.argv[2], 'w'), indent=1)
        print('wrote', sys.argv[2])

main(sys.argv[1])
