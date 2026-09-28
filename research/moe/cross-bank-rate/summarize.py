#!/usr/bin/env python3
"""Evaluate frozen disjoint image assignments on a common offline Q4 producer."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/qwen-moe')
OUT = ROOT / 'cross-bank-rate'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    first = json.loads((OUT/'receipt.json').read_text())
    inputs = sorted(OUT.glob('offline-down-*.npz'))
    assert len(inputs) == 4
    assert all(sha(p) == json.loads(p.with_suffix('.json').read_text())['payload_sha256'] for p in inputs)
    panel = []
    for split in ('train','held'):
        q3 = np.concatenate([np.load(p)[split] for p in sorted((ROOT/'q3-expert-allocation').glob('part-*.npz'))])
        offline = np.concatenate([np.load(p)[split] for p in inputs])
        assert q3.shape == offline.shape
        denom = first['reference_squared_norm'][split]
        for row_index, row in enumerate(first['results']):
            a = q3[row['q3_ids']].astype(np.float64).sum(axis=0) if row['q3_ids'] else np.zeros_like(q3[0], dtype=np.float64)
            b = offline[row['q4_down_ids']].astype(np.float64).sum(axis=0) if row['q4_down_ids'] else np.zeros_like(a)
            actual = np.sqrt(np.square(a+b).sum()/denom)
            linear_proxy = row[split]['relative_rms']
            overlap = float(np.vdot(a,b)/np.sqrt(np.square(a).sum()*np.square(b).sum())) if np.any(a) and np.any(b) else None
            if split == 'train':
                panel.append({'q3_gateup_experts': row['q3_gateup_experts'], 'q4_down_experts': row['q4_down_experts'], 'order': row['order'],
                              'layer_gateup_down_bytes': row['layer_gateup_down_bytes'], 'conditional_one_read_fraction_saved': row['conditional_one_read_fraction_saved'],
                              'q3_ids':row['q3_ids'], 'q4_down_ids':row['q4_down_ids']})
            panel[row_index][split] = {'relative_rms':float(actual), 'native_producer_proxy_rms':linear_proxy,
                                       'gate_down_error_cosine': overlap,
                                       'down_only_rms':float(np.sqrt(np.square(b).sum()/denom)),
                                       'q3_only_rms':float(np.sqrt(np.square(a).sum()/denom))}
    receipt = {'contract': 'Frozen proxy-trained disjoint per-expert Q3 gate/up OR Q4 down bank on identical offline Q4 producer; Q4 down codes fitted to native train post-SwiGLU hiddens then evaluated on recomputed offline Q4 gate/up hiddens; FP32 CPU BLAS products and FP64 weighted sum. The disjoint images compose exactly under this CPU evaluation, not native FP32 bitwise or complete-model language quality.',
               'source_sha256':sha(Path(__file__)), 'verify_source_sha256':sha(Path(__file__).with_name('verify.py')),
               'selection_receipt_sha256':sha(OUT/'receipt.json'), 'offline_down_sha256':{p.name:sha(p) for p in inputs}, 'rows':panel}
    path = OUT/'exact-receipt.json'
    path.write_text(json.dumps(receipt,indent=2)+'\n')
    for r in panel:
        print(r['q3_gateup_experts'],r['q4_down_experts'],r['order'],f"{r['train']['relative_rms']:.6f}",f"{r['held']['relative_rms']:.6f}",f"{r['held']['gate_down_error_cosine']:.4f}" if r['held']['gate_down_error_cosine'] is not None else '-', flush=True)
    print('receipt',sha(path))


if __name__ == '__main__':
    main()
