#!/usr/bin/env python3
"""Train-only, whole-head variable-rate allocation of a fixed Q factor."""
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'attention-metric'))
from refine import FIXTURE, MODEL, attention, decode_right, left_from_codes, measure, prep, unpack_codes

SOURCE = Path('/path/to/workspace/data/kelana-subbit/attention-radial')
OUT = Path('/path/to/workspace/data/kelana-subbit/head-rate')


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def kl_by_head(logp, teacher):
    t = teacher['logp']
    return (t.exp() * (t - logp)).sum(-1).mean((0, 2))


def run():
    torch.set_num_threads(8)
    OUT.mkdir(parents=True, exist_ok=True)
    paths = [SOURCE / f'layer00-q-left{b}.npz' for b in (2, 3)]
    images = []
    for path in paths:
        with np.load(path) as z:
            images.append({k: z[k].copy() for k in z.files})
    assert all(np.array_equal(images[0][k], images[1][k]) for k in ('right_shape', 'right_codes', 'right_scales'))
    right = decode_right(images[0])
    left = [left_from_codes(unpack_codes(im['left_codes'], 2048, 88, b), im, False) for b, im in zip((2, 3), images)]
    with np.load(FIXTURE) as z:
        xtr = torch.from_numpy(z['train'].copy()).float().reshape(8, 256, -1)
        xva = torch.from_numpy(z['validation'].copy()).float().reshape(4, 256, -1)
        wq = torch.from_numpy(z['weight'].copy()).float()
    with safe_open(MODEL, framework='pt', device='cpu') as z:
        wk = z.get_tensor('model.layers.0.self_attn.k_proj.weight').float()
        wv = z.get_tensor('model.layers.0.self_attn.v_proj.weight').float()
        wo = z.get_tensor('model.layers.0.self_attn.o_proj.weight').float()
        qgamma = z.get_tensor('model.layers.0.self_attn.q_norm.weight').float()
        kgamma = z.get_tensor('model.layers.0.self_attn.k_norm.weight').float()
    with torch.no_grad():
        data = {}
        for name, x in (('train', xtr), ('validation', xva)):
            prepared = prep(x, wk, wv, qgamma, kgamma)
            teacher = measure(x, (x @ wq.T).to(torch.bfloat16).float(), wq, prepared, qgamma, wo)
            responses = x @ right.T
            arms = []
            for factor in left:
                raw = (responses @ factor.T).to(torch.bfloat16).float()
                logp, _, _ = attention(raw, x, *prepared, qgamma, wo)
                arms.append(kl_by_head(logp, teacher))
            data[name] = (x, prepared, teacher, responses, arms)
        gains = (data['train'][4][0] - data['train'][4][1]).numpy()
        selected = np.argsort(-gains, kind='stable')[:8]
        alternatives = {'train_kl': sorted(map(int, selected)),
                        'reverse': sorted(map(int, np.argsort(gains, kind='stable')[:8])),
                        'even': list(range(0, 16, 2)),
                        'all_two': [], 'all_three': list(range(16))}
        metrics = {}
        for name, heads in alternatives.items():
            chosen = np.zeros(16, dtype=bool)
            chosen[heads] = True
            mixed = torch.where(torch.from_numpy(chosen.repeat(128))[:, None], left[1], left[0])
            metrics[name] = {}
            for split in ('train', 'validation'):
                x, prepared, teacher, responses, _ = data[split]
                raw = (responses @ mixed.T).to(torch.bfloat16).float()
                measured = measure(x, raw, wq, prepared, qgamma, wo, teacher)
                logp, _, _ = attention(raw, x, *prepared, qgamma, wo)
                measured['attention_kl_by_head'] = kl_by_head(logp, teacher).tolist()
                metrics[name][split] = measured
        # Head-major packed records: two-bit codes for the first class, three-bit
        # codes for the second; their FP16 scales share a single row-aligned array.
        chosen = np.zeros(16, dtype=bool)
        chosen[selected] = True
        rows3 = np.flatnonzero(chosen.repeat(128))
        rows2 = np.flatnonzero(~chosen.repeat(128))
        records = {'head_three_mask': np.packbits(chosen.astype(np.uint8), bitorder='little'),
                   'left_codes_two': images[0]['left_codes'][rows2],
                   'left_codes_three': images[1]['left_codes'][rows3],
                   'left_scales_two': images[0]['left_scales'][rows2],
                   'left_scales_three': images[1]['left_scales'][rows3],
                   'right_codes': images[0]['right_codes'],
                   'right_scales': images[0]['right_scales'],
                   'shape': np.array([2048, 1024, 88, 128], dtype=np.int32)}
        recovered = np.unpackbits(records['head_three_mask'], bitorder='little')[:16].astype(bool)
        assert np.array_equal(recovered, chosen)
        assert np.array_equal(records['left_codes_two'], images[0]['left_codes'][rows2])
        assert np.array_equal(records['left_codes_three'], images[1]['left_codes'][rows3])
        assert np.array_equal(records['left_scales_two'], images[0]['left_scales'][rows2])
        assert np.array_equal(records['left_scales_three'], images[1]['left_scales'][rows3])
        image_path = OUT / 'layer00-q-eight-heads.npz'
        np.savez(image_path, **records)
        report = {'source_sha256': sha(Path(__file__)), 'fixture_sha256': sha(FIXTURE),
                  'model_sha256': sha(MODEL), 'input_image_sha256': [sha(p) for p in paths],
                  'image_sha256': sha(image_path), 'stored_bytes': sum(v.nbytes for v in records.values()),
                  'bits_per_original_weight': 8 * sum(v.nbytes for v in records.values()) / (2048 * 1024),
                  'two_bit_bytes': sum(v.nbytes for v in images[0].values()),
                  'three_bit_bytes': sum(v.nbytes for v in images[1].values()),
                  'train_kl_gain_by_head': gains.tolist(), 'allocation': alternatives, 'metrics': metrics}
        (OUT / 'results.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps({k: report[k] for k in ('stored_bytes', 'bits_per_original_weight', 'train_kl_gain_by_head', 'allocation')}))
        for name in metrics:
            print(name, [(split, metrics[name][split]['causal_attention_kl'], metrics[name][split]['attention_output_relative_squared_error']) for split in ('train', 'validation')])


if __name__ == '__main__':
    run()
