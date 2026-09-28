#!/usr/bin/env python3
"""Aggregate complete forty-layer train/held output-span certificates."""
import hashlib
import json
from pathlib import Path
import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe/all-layer-output-span')
rows, source, capture, model, files, shards = [], None, None, None, {}, {}
for start in range(0, 40, 5):
    p = BASE / f'layers-{start}-{start+4}.json'
    data = json.loads(p.read_text())
    for key, value in [('source', data['source_sha256']),
                       ('capture', data['capture_receipt_sha256']),
                       ('model', data['model_sha256'])]:
        old = locals()[key]
        assert old is None or old == value, key
        if key == 'source': source = value
        if key == 'capture': capture = value
        if key == 'model': model = value
    assert not (files.keys() & data['files_sha256'].keys())
    files.update(data['files_sha256'])
    rows.extend(data['layers'])
    shards[p.name] = hashlib.sha256(p.read_bytes()).hexdigest()
assert [r['layer'] for r in rows] == list(range(40))
assert len(files) == 160
out = {'source_sha256': source, 'summary_source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
       'capture_receipt_sha256': capture, 'model_sha256': model,
       'shards_sha256': shards, 'input_files_sha256': files, 'layers': 40,
       'observations_per_split': 2560, 'slots_per_split': 20480,
       'train_slot_rank_min': min(r['train_slot_rank'] for r in rows),
       'train_slot_rank_max': max(r['train_slot_rank'] for r in rows), 'panels': {}}
for n in (64, 128, 256, 512):
    panel = {}
    for split in ('train', 'held'):
        errors = np.array([r['panels'][str(n)][f'{split}_error_sq'] for r in rows])
        norms = np.array([r[f'{split}_sum_norm_sq'] for r in rows])
        ratios = np.sqrt(errors / norms)
        panel[split] = {'pooled_relative_rms': float(np.sqrt(errors.sum() / norms.sum())),
                        'layer_median': float(np.median(ratios)), 'layer_min': float(ratios.min()),
                        'layer_max': float(ratios.max()), 'layers_over_half': int((ratios > .5).sum())}
    out['panels'][str(n)] = panel
BASE.joinpath('receipt.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps(out['panels'], indent=2))
