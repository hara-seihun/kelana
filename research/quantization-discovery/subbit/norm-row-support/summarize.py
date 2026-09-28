#!/usr/bin/env python3
"""Select norm-row strata on train CE and aggregate frozen held causal KL."""
import hashlib
import json
from pathlib import Path

DATA = Path('/path/to/workspace/data/kelana-subbit/norm-row-support')


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def average(xs):
    return [sum(row[i] for row in xs)/len(xs) for i in range(4)]


for layer in (0, 14):
    files = [DATA/f'layer{layer:02d}-group{g}.json' for g in range(8)]
    reports = [json.loads(p.read_text()) for p in files]
    assert [(r['layer'], r['group']) for r in reports] == [(layer, g) for g in range(8)]
    original, deleted, refit, chosen = [], [], [], []
    decisions = []
    for r in reports:
        o = r['held_kl_by_window_original']
        d = r['held_kl_by_window_deleted']
        f = r.get('held_kl_by_window_refit') or o
        ce = r.get('train_ce_without_penalty')
        accept = bool(r['deleted_bins']) and ce is not None and ce['refit'] <= ce['original']
        original.append(o)
        deleted.append(d)
        refit.append(f)
        chosen.append(f if accept else o)
        decisions.append({'group': r['group'], 'delete_bins': r['deleted_bins'] if accept else [],
                          'delete_rows': r['deleted_raw_rows'] if accept else 0,
                          'train_ce': ce})
    out = {'layer': layer, 'selected_on': 'smooth FP32 finite causal train CE, refit versus original, same query positions and no ridge penalty',
           'four_held_window_kl': {name: average(rows) for name, rows in
                                    [('original', original), ('delete_all_small', deleted),
                                     ('refit_all_small', refit), ('train_selected', chosen)]},
           'decisions': decisions, 'deleted_rows': sum(d['delete_rows'] for d in decisions),
           'parent_receipt_sha256': {p.name: sha(p) for p in files},
           'source_sha256': sha(Path(__file__))}
    dest = DATA/f'layer{layer:02d}-summary.json'
    dest.write_text(json.dumps(out, indent=2)+'\n')
    print(dest, out['four_held_window_kl'], out['deleted_rows'])
