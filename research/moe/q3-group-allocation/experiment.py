#!/usr/bin/env python3
"""Choose paid Q3_K/Q4_K gate+up banks by fixed 32-expert shard on real routes."""
import hashlib
import itertools
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/qwen-moe/gateup-q3-recode')
OUT = Path('/path/to/workspace/data/qwen-moe/q3-group-allocation')
N = 8
Q3_BANK = 230686720
Q4_BANK = 301989888
STREAM = 2626187904


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    source = json.loads((DATA / 'receipt.json').read_text())
    banks = {split: {arm: [] for arm in ('q3', 'q4')} for split in ('train', 'held')}
    parts = []
    for i in range(N):
        p = DATA / f'part-{i:02d}.npz'
        meta = json.loads((DATA / f'part-{i:02d}.json').read_text())
        assert digest(p) == meta['partial_output_sha256']
        assert digest(DATA / f'image-{i:02d}.bin') == meta['q3_image_sha256']
        assert meta['experts'] == [32*i, 32*(i+1)]
        parts.append({'index': i, 'output_sha256': digest(p), 'image_sha256': meta['q3_image_sha256'],
                      'image_bytes': meta['q3_image_bytes'], 'observed_experts': meta['observed_experts']})
        with np.load(p) as arrays:
            for split in banks:
                for arm in banks[split]:
                    banks[split][arm].append(arrays[f'{split}_{arm}'])
    grams = {}
    denominators = {}
    per_shard = {}
    for split in banks:
        q4 = sum(banks[split]['q4'])
        delta = np.stack([a-b for a,b in zip(banks[split]['q3'], banks[split]['q4'])])
        grams[split] = np.einsum('itd,jtd->ij',delta,delta, optimize=True)
        denominators[split] = float(np.square(q4).sum())
        per_shard[split] = (np.diag(grams[split])/denominators[split]).tolist()
        expected = source['scores'][split]['relative_rms']
        actual = float(np.sqrt(grams[split].sum()/denominators[split]))
        assert abs(actual-expected) < 1e-10, (split, actual, expected)
    results = []
    for count in range(N+1):
        choices = []
        for choice in itertools.combinations(range(N),count):
            v = np.zeros(N)
            v[list(choice)] = 1
            choices.append((choice, {s: float(v @ grams[s] @ v) for s in grams}))
        trained = min(choices, key=lambda item:(item[1]['train'],item[0]))
        hindsight = min(choices, key=lambda item:(item[1]['held'],item[0]))
        results.append({'q3_shards':count, 'q3_experts':32*count,
                        'selected_shards':list(trained[0]),
                        'train_relative_rms':float(np.sqrt(trained[1]['train']/denominators['train'])),
                        'held_relative_rms':float(np.sqrt(trained[1]['held']/denominators['held'])),
                        'held_oracle_shards':list(hindsight[0]),
                        'held_oracle_relative_rms':float(np.sqrt(hindsight[1]['held']/denominators['held'])),
                        'layer_gateup_bytes':Q4_BANK-(Q4_BANK-Q3_BANK)*count//N,
                        'forty_layer_conditional_one_read_saving_bytes':40*8*(Q4_BANK-Q3_BANK)*count//(N*256),
                        'forty_layer_conditional_one_read_fraction':40*8*(Q4_BANK-Q3_BANK)*count/(N*256*STREAM)})
    offdiag = grams['train']-np.diag(np.diag(grams['train']))
    eig = np.linalg.eigvalsh(np.diag(1/np.sqrt(np.diag(grams['train']))) @ offdiag @ np.diag(1/np.sqrt(np.diag(grams['train']))))
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'contract':'Eight fixed 32-expert paired gate/up Q3_K vs Q4_K banks, decoded installed GGUF, actual layer-0 inputs/IDs/scores, FP32 BLAS/SwiGLU/down, FP64 weighted sum; train-only subset selection by complete squared output error; no full-model loss or native timing',
              'source_sha256':digest(Path(__file__)), 'parent_receipt_sha256':digest(DATA/'receipt.json'),
              'parent_model_sha256':source['parts'][0]['model_sha256'], 'parts':parts,
              'reference_squared_norm':denominators, 'shard_error_diagonal_fraction':per_shard,
              'train_normalized_offdiagonal_eigenvalues':eig.tolist(), 'result':results}
    (OUT/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    for item in results:
        print(item['q3_shards'],item['selected_shards'],f"{item['train_relative_rms']:.6f}",
              f"{item['held_relative_rms']:.6f}",f"{item['held_oracle_relative_rms']:.6f}",
              f"{item['forty_layer_conditional_one_read_fraction']:.6%}")
    print('receipt_sha256',digest(OUT/'receipt.json'))


if __name__ == '__main__':
    main()
