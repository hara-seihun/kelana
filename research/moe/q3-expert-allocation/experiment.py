#!/usr/bin/env python3
"""Paid per-expert Q3_K gate/up allocation on actual layer-0 routed producers."""
import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[1] / 'input-subspace'))
from evaluate import capture, evaluator, image_banks, sha

PARENT = Path('/path/to/workspace/data/qwen-moe/gateup-q3-recode')
OUT = Path('/path/to/workspace/data/qwen-moe/q3-expert-allocation')
N = 256
D = 2048
Q3_BYTES = 901120
Q4_BYTES = 1179648
STREAM = 2626187904


def part(index):
    parent = json.loads((PARENT / f'part-{index:02d}.json').read_text())
    assert sha(PARENT / f'image-{index:02d}.bin') == parent['q3_image_sha256']
    inventory, model, banks = image_banks()
    library, weight = evaluator(banks)
    lib = ctypes.CDLL(str(library))
    dequant = lib.dequantize_row_q3_K
    dequant.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]
    dequant.restype = None
    splits = {s: capture(s) for s in ('train', 'held')}
    result = {s: np.zeros((32, len(data['x']), D), np.float32) for s, (_, data) in splits.items()}
    image = np.memmap(PARENT / f'image-{index:02d}.bin', dtype=np.uint8, mode='r')
    assert image.size == 32 * Q3_BYTES
    for j in range(32):
        expert = index * 32 + j
        positions = {s: np.where(data['ids'] == expert) for s, (_, data) in splits.items()}
        if not any(len(pos[0]) for pos in positions.values()):
            continue
        gate, up, down = (weight(name, expert) for name in ('gate', 'up', 'down'))
        reduced = []
        for bank in range(2):
            packed = image[(2*j+bank)*(Q3_BYTES//2):(2*j+bank+1)*(Q3_BYTES//2)]
            q = np.empty((512, 2048), np.float32)
            dequant(packed.ctypes.data, q.ctypes.data, q.size)
            reduced.append(q)
        for split, (_, data) in splits.items():
            row, slot = positions[split]
            if not len(row):
                continue
            x = np.asarray(data['x'][row], np.float32)
            score = data['scores'][row, slot].astype(np.float64)[:, None]
            outputs = []
            for g, u in ((gate, up), tuple(reduced)):
                a = x @ g.T
                b = x @ u.T
                h = ((a / (1. + np.exp(-a))) * b).astype(np.float32)
                outputs.append(h @ down.T)
            result[split][j, row] = (score * (outputs[1].astype(np.float64) - outputs[0].astype(np.float64))).astype(np.float32)
    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / f'part-{index:02d}.npz'
    np.savez_compressed(dst, **result)
    # FP32 slot deltas round the FP64 weighted products once. Check against the
    # parent's FP64 sum without pretending this is native bit identity.
    checks = {}
    with np.load(PARENT / f'part-{index:02d}.npz') as original:
        for split in splits:
            delta = original[f'{split}_q3'] - original[f'{split}_q4']
            actual = result[split].astype(np.float64).sum(axis=0)
            checks[split] = float(np.linalg.norm(actual-delta)/max(np.linalg.norm(delta),1e-20))
            assert checks[split] < 2e-6, checks
    meta = {'parent_part_sha256': sha(PARENT / f'part-{index:02d}.npz'),
            'parent_image_sha256': parent['q3_image_sha256'],
            'capture_sha256': parent['capture_sha256'], 'library_sha256': sha(library),
            'source_sha256': sha(HERE), 'output_sha256': sha(dst),
            'sum_relative_roundoff': checks}
    (OUT / f'part-{index:02d}.json').write_text(json.dumps(meta, indent=2)+'\n')
    print(index, checks, meta['output_sha256'], flush=True)


def greedy(gram, count, eligible=None):
    # True complete routed-sum squared error, including cross-expert cancellation.
    chosen = []
    selected = np.zeros(N, bool)
    if eligible is None:
        eligible = np.ones(N, bool)
    assert count <= np.count_nonzero(eligible)
    running = np.zeros(N, np.float64)
    total = 0.
    for _ in range(count):
        gains = np.where(selected | ~eligible, np.inf, np.diag(gram) + 2*running)
        pick = int(np.argmin(gains))
        total += gains[pick]
        selected[pick] = True
        chosen.append(pick)
        running += gram[pick]
    return chosen, total


def main():
    parents = [json.loads((PARENT / f'part-{i:02d}.json').read_text()) for i in range(8)]
    parts = [json.loads((OUT / f'part-{i:02d}.json').read_text()) for i in range(8)]
    for i, (source, part_meta) in enumerate(zip(parents,parts)):
        assert part_meta['parent_part_sha256'] == sha(PARENT / f'part-{i:02d}.npz')
        assert part_meta['parent_image_sha256'] == source['q3_image_sha256']
        assert part_meta['source_sha256'] == sha(HERE)
        assert part_meta['output_sha256'] == sha(OUT / f'part-{i:02d}.npz')
    deltas = {}
    denom = {}
    for split in ('train','held'):
        chunks = []
        reference = None
        for i in range(8):
            with np.load(OUT / f'part-{i:02d}.npz') as arrays:
                chunks.append(arrays[split].astype(np.float64))
            with np.load(PARENT / f'part-{i:02d}.npz') as arrays:
                reference = arrays[f'{split}_q4'].astype(np.float64) if reference is None else reference + arrays[f'{split}_q4']
        deltas[split] = np.concatenate(chunks, axis=0)
        denom[split] = float(np.square(reference).sum())
    gram = {s: np.einsum('itd,jtd->ij', d,d, optimize=True) for s,d in deltas.items()}
    observed = {s: np.diag(g)>0 for s,g in gram.items()}
    overlap = int(np.count_nonzero(observed['train'] & observed['held']))
    unseen_held = int(np.count_nonzero(~observed['train'] & observed['held']))
    counts = (0,1,2,4,8,16,32,64,128)
    rows = []
    for count in counts:
        chosen, train_sq = greedy(gram['train'], count)
        held_sq = float(gram['held'][np.ix_(chosen,chosen)].sum())
        hindsight, hindsight_sq = greedy(gram['held'],count)
        selected_seen, seen_train_sq = greedy(gram['train'],count,observed['train'])
        seen_held_sq = float(gram['held'][np.ix_(selected_seen,selected_seen)].sum())
        held_seen, held_seen_sq = greedy(gram['held'],count,observed['held'])
        rows.append({'q3_experts': count, 'train_selected': chosen,
                     'train_rms': float(np.sqrt(max(0,train_sq)/denom['train'])),
                     'held_rms': float(np.sqrt(max(0,held_sq)/denom['held'])),
                     'held_greedy_hindsight_rms': float(np.sqrt(max(0,hindsight_sq)/denom['held'])),
                     'held_greedy_hindsight_selected': hindsight,
                     'train_seen_only_selected':selected_seen,
                     'train_seen_only_train_rms':float(np.sqrt(max(0,seen_train_sq)/denom['train'])),
                     'train_seen_only_held_rms':float(np.sqrt(max(0,seen_held_sq)/denom['held'])),
                     'held_seen_only_greedy_rms':float(np.sqrt(max(0,held_seen_sq)/denom['held'])),
                     'held_seen_only_greedy_selected':held_seen,
                     'layer_gateup_bytes': N*Q4_BYTES-count*(Q4_BYTES-Q3_BYTES),
                     'conditional_forty_layer_one_read_fraction':40*8*count*(Q4_BYTES-Q3_BYTES)/(N*STREAM)})
    p = json.loads((PARENT/'receipt.json').read_text())
    full_rms = {}
    for split in ('train','held'):
        full = float(np.sqrt(gram[split].sum()/denom[split]))
        assert abs(full-p['scores'][split]['relative_rms']) < 2e-6, (split,full)
        full_rms[split] = full
    metadata = {'contract':'Frozen native Q3_K/Q4_K paired gate/up images; actual layer-0 producer and router scores; decoded CPU FP32 BLAS/SwiGLU/Q5_K down; FP64 routed sum, FP32 stored per-expert deltas; greedy fixed-cardinality train selection and held greedy comparator (not optimal oracle). No native timing or language loss.',
                'source_sha256':sha(HERE), 'parent_receipt_sha256':sha(PARENT/'receipt.json'),
                'parent_model_sha256':p['parts'][0]['model_sha256'], 'parts':parts,
                'reference_squared_norm':denom,
                'observed_expert_counts': {s:int(np.count_nonzero(v)) for s,v in observed.items()},
                'train_held_observed_overlap':overlap,
                'held_experts_unseen_on_train':unseen_held,
                'all_q3_rms':full_rms, 'result':rows}
    (OUT/'receipt.json').write_text(json.dumps(metadata, indent=2)+'\n')
    for r in rows:
        print(r['q3_experts'], f"{r['train_rms']:.6f}", f"{r['held_rms']:.6f}",
              f"{r['train_seen_only_held_rms']:.6f}",
              f"{r['held_seen_only_greedy_rms']:.6f}",
              f"{r['conditional_forty_layer_one_read_fraction']:.6%}")
    print('expert_coverage', metadata['observed_expert_counts'], overlap, unseen_held)
    print('receipt_sha256', sha(OUT/'receipt.json'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--part',type=int, choices=range(8))
    args = parser.parse_args()
    if args.part is None:
        main()
    else:
        part(args.part)
