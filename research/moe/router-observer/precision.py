#!/usr/bin/env python3
"""Test whether omitted Qwen router logits affect rounded selected weights."""
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
CAP = BASE / 'route-capture'
DEST = BASE / 'router-observer' / 'precision.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rounded_weights(logits, ids):
    """Declared host FP32 grammar, not a simulation of CUDA warp reductions."""
    logits = np.asarray(logits, dtype=np.float32)
    exp = np.exp(logits - np.max(logits), dtype=np.float32)
    total = np.sum(exp, dtype=np.float32)
    probs = np.multiply(exp, np.float32(1) / total, dtype=np.float32)
    chosen = probs[ids]
    return np.multiply(chosen, np.float32(1) / np.sum(chosen, dtype=np.float32), dtype=np.float32)


def main():
    inventory = BASE / 'traffic.json'
    info = json.loads(inventory.read_text())
    router = next(t for t in info['tensors'] if t['name'] == 'blk.0.ffn_gate_inp.weight')
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = (info['header_bytes'] + 31) // 32 * 32 + router['offset']
    weights = np.memmap(model, '<f4', 'r', offset=offset, shape=(256, 2048)).astype(np.float64)
    result = {'model_sha256': json.loads((BASE / 'acquisition.json').read_text())['sha256'],
              'inventory_sha256': sha(inventory), 'source_sha256': sha(Path(__file__)),
              'grammar': 'FP64 F32-router dot cast to F32; NumPy F32 exp, sequential row reduction, reciprocal then multiply for 256 probabilities and selected eight. Omitted logits shifted -1 F32; selected logits fixed. Not HIP warp/FMA arithmetic.',
              'splits': {}}
    for split in ('train', 'held'):
        paths = {name: CAP / f'{split}.0.{node}-0.bin' for name, node in
                 (('input', 'attn_post_norm'), ('ids', 'ffn_moe_topk'),
                  ('down', 'ffn_moe_down'))}
        x = np.memmap(paths['input'], '<f4').reshape(-1, 2048).astype(np.float64)
        ids = np.memmap(paths['ids'], '<i4').reshape(-1, 8)
        down = np.memmap(paths['down'], '<f4').reshape(-1, 8, 2048)
        logits = (x @ weights.T).astype(np.float32)
        changes = []
        weighted_changes = []
        witness = None
        for i, (row, selection) in enumerate(zip(logits, ids)):
            mask = np.ones(256, dtype=bool)
            mask[selection] = False
            shifted = row.copy()
            shifted[mask] -= np.float32(1)
            assert np.array_equal(row[selection], shifted[selection])
            assert set(np.argsort(-row, kind='stable')[:8]) == set(selection)
            assert set(np.argsort(-shifted, kind='stable')[:8]) == set(selection)
            a, b = rounded_weights(row, selection), rounded_weights(shifted, selection)
            count = int(np.count_nonzero(a.view(np.uint32) != b.view(np.uint32)))
            changes.append(count)
            y = np.einsum('e,ed->d', a.astype(np.float64), down[i].astype(np.float64))
            z = np.einsum('e,ed->d', b.astype(np.float64), down[i].astype(np.float64))
            weighted_changes.append(float(np.linalg.norm(y-z) / np.linalg.norm(y)))
            if count and witness is None:
                witness = {'row': i, 'selected_ids': selection.tolist(),
                           'selected_logits_f32_bits': row[selection].view(np.uint32).tolist(),
                           'selected_weights_f32_bits': a.view(np.uint32).tolist(),
                           'shifted_weights_f32_bits': b.view(np.uint32).tolist(),
                           'top8_gap': float(np.min(row[selection]) - np.max(row[mask]))}
        result['splits'][split] = {'rows': len(ids), 'changed_rows': sum(c > 0 for c in changes),
                                   'changed_weight_coordinates': sum(changes),
                                   'max_weighted_sum_relative_l2': max(weighted_changes),
                                   'mean_weighted_sum_relative_l2': float(np.mean(weighted_changes)),
                                   'witness': witness,
                                   'captures': {name: sha(path) for name, path in paths.items()}}
    DEST.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps({k: {n: v for n, v in s.items() if n != 'captures'} for k, s in result['splits'].items()}, indent=2))


if __name__ == '__main__':
    main()
