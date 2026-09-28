#!/usr/bin/env python3
"""Combine disjoint expert shards and price the complete routed down observation."""
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
CAP = BASE / 'route-capture'
OUT = BASE / 'down-route-quant'
PARTS = [(0, 32), (32, 128), (128, 224), (224, 256)]
ARMS = ('q5', 'q4-reference', 'q4-train-weighted')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    results = {'source_sha256': sha(__file__), 'shards': {}, 'splits': {},
               'map': 'Native Q4_K recode of decoded Q5_K down bank; CPU FP32 BLAS products, FP64 routed sum. No full-model quality or native runtime result.'}
    sums = {s: {} for s in ('train', 'held')}
    for first, last in PARTS:
        path = OUT / f'part-{first}-{last}.npz'
        receipt = json.loads(path.with_suffix('.json').read_text())
        assert receipt['arrays_sha256'] == sha(path)
        results['shards'][f'{first}-{last}'] = receipt
        with np.load(path) as part:
            for split in sums:
                for arm in ARMS:
                    key = f'{split}_{arm}'
                    sums[split][arm] = sums[split].get(arm, 0) + part[key]
    for split in sums:
        weights = np.fromfile(CAP / f'{split}.0.ffn_moe_weights_norm-0.bin', '<f4').reshape(-1, 8)
        native = np.fromfile(CAP / f'{split}.0.ffn_moe_down-0.bin', '<f4').reshape(-1, 8, 2048)
        native_sum = np.einsum('te,ted->td', weights.astype(np.float64), native.astype(np.float64))
        ref = sums[split]['q5']
        den = np.square(ref).sum()
        errs = {arm: np.square(sums[split][arm] - ref).sum(axis=1) for arm in ARMS[1:]}
        results['splits'][split] = {
            'tokens': len(ref), 'denominator_sse': float(den),
            'q5_offline_vs_native_relative_rms': float(np.sqrt(np.square(native_sum - ref).sum() / den)),
            'relative_rms': {arm: float(np.sqrt(error.sum() / den)) for arm, error in errs.items()},
            'sse': {arm: float(error.sum()) for arm, error in errs.items()},
            'weighted_better_token_counts': {
                arm: int((errs[arm] < errs['q4-reference']).sum()) for arm in ('q4-train-weighted',)},
            'rms_per_token': {arm: (np.sqrt(error / np.maximum(np.square(ref).sum(axis=1), 1e-30))).tolist()
                              for arm, error in errs.items()},
            'input_sha256': {name: sha(CAP / f'{split}.0.{name}-0.bin') for name in
                             ('ffn_moe_topk', 'ffn_moe_weights_norm', 'ffn_moe_swiglu', 'ffn_moe_down')},
        }
    traffic = json.loads((BASE / 'traffic.json').read_text())
    routed = next(x for x in traffic['tensors'] if x['name'] == 'blk.0.ffn_down_exps.weight')
    assert routed['bytes'] == 256 * 2048 * 512 // 256 * 176
    results['rate'] = {'q5_k_bytes_per_down_expert': 2048 * 512 // 256 * 176,
                       'q4_k_bytes_per_down_expert': 2048 * 512 // 256 * 144,
                       'eight_selected_down_bytes_saved_per_token_per_layer': 8 * 2048 * 512 // 256 * 32,
                       'forty_layer_bytes_saved_per_token': 40 * 8 * 2048 * 512 // 256 * 32,
                       'forty_layer_bank_bytes_saved': 40 * 256 * 2048 * 512 // 256 * 32,
                       'whole_model_one_read_bytes': 2626187904,
                       'full_bank_weight_bytes_reference': 22123538944,
                       'online': 'Same 8 down matvecs and weighted sum; existing Q4_K native consumer available. No inferred instruction or latency gain; recoding requires a new full GGUF and held model loss.'}
    results['rate']['conditional_full_stream_fraction'] = results['rate']['forty_layer_bytes_saved_per_token'] / results['rate']['whole_model_one_read_bytes']
    path = OUT / 'receipt.json'
    path.write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps({'splits': [{s: {k: v for k, v in r.items() if k != 'rms_per_token'}} for s, r in results['splits'].items()], 'rate': results['rate']}, indent=2))


if __name__ == '__main__':
    main()
