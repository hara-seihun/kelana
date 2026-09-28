#!/usr/bin/env python3
"""Score simultaneous paid four-bit substitutions in a recovered ternary model."""
import argparse
import json
from pathlib import Path

import numpy as np
import torch
from pilot import DATA, ROOT, MODEL, expanded, load_model, sha
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'quantization-discovery/subbit'))
from spectral_quant import decode

SCALAR = DATA / 'full-scalar'
GROUPS = [(0, 7), (7, 14), (14, 21), (21, 28)]


def loss(model, rows):
    losses = []
    with torch.inference_mode():
        for row in rows:
            x = torch.tensor(row, device='cuda', dtype=torch.long)[None]
            logits = model(x, use_cache=False).logits[:, :-1].float()
            value = torch.nn.functional.cross_entropy(
                logits.reshape(-1, logits.shape[-1]), x[:, 1:].reshape(-1), reduction='sum')
            losses.append(float(value))
    return dict(nll=sum(losses) / sum(len(row) - 1 for row in rows), nll_sums=losses)


@torch.inference_mode()
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--split', choices=['validation', 'test'], default='validation')
    ap.add_argument('--windows', type=int, default=8)
    ap.add_argument('--offset', type=int, default=0)
    ap.add_argument('--groups', required=True, help='Comma-separated distinct indices 0..3')
    a = ap.parse_args()
    groups = tuple(int(i) for i in a.groups.split(','))
    if not groups or len(groups) != len(set(groups)) or any(i not in range(4) for i in groups):
        raise ValueError('Expected distinct group indices 0..3')
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    source = ROOT / 'expanded-scale384'
    manifest_path = source / 'manifest.json'
    scalar_path = SCALAR / 'accounting.json'
    manifest = json.loads(manifest_path.read_text())
    scalar = json.loads(scalar_path.read_text())
    if not manifest['complete'] or len(manifest['matrices']) != 197:
        raise ValueError('Incomplete ternary image')
    matrices = {e['key']: e for e in manifest['matrices']}
    scalar_entries = {e['name']: e for e in scalar['entries'] if e['bits'] == 4}
    if set(matrices) != set(scalar_entries):
        raise ValueError('Unmatched scalar matrices')
    with np.load(ROOT / 'tokens.npz') as z:
        rows = z[a.split][a.offset:a.offset + a.windows].copy()
    if len(rows) != a.windows:
        raise ValueError('Not enough token windows')
    model = load_model()
    for key, entry in matrices.items():
        path = source / (key.replace('.', '_') + '.npz')
        if sha(path) != entry['sha256']:
            raise ValueError(f'Ternary image changed: {key}')
        model.get_parameter(key).copy_(expanded(path))
    if model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr():
        raise ValueError('Tied head detached')
    picked = [key for key in matrices if key.startswith('model.layers.') and any(
        GROUPS[i][0] <= int(key.split('.')[2]) < GROUPS[i][1] for i in groups)]
    total = manifest['payload_bytes']
    for key in picked:
        entry = scalar_entries[key]
        path = Path(entry['image'])
        if sha(path) != entry['sha256']:
            raise ValueError(f'Scalar image changed: {key}')
        with np.load(path) as image:
            model.get_parameter(key).copy_(decode(image, 'weight'))
        total += entry['payload_bytes'] - matrices[key]['payload_bytes']
    result = dict(groups=groups, split=a.split, offset=a.offset, windows=a.windows,
                  source_sha256=sha(Path(__file__)), tokens_sha256=sha(ROOT / 'tokens.npz'),
                  model_source_sha256=sha(MODEL / 'source.json'),
                  ternary_manifest_sha256=sha(manifest_path), scalar_accounting_sha256=sha(scalar_path),
                  baseline_payload_bytes=manifest['payload_bytes'], payload_bytes=total,
                  unique_parameters=manifest['unique_parameters'], bpw=8 * total / manifest['unique_parameters'],
                  replaced_matrices=len(picked),
                  execution='BF16 expanded complete-model forward; no packed inference timing',
                  **loss(model, rows))
    destination = ROOT / 'quality' / f'mixed-interaction-{a.split}-{a.offset}-{a.windows}-{"-".join(map(str, groups))}.json'
    if destination.exists():
        raise FileExistsError(destination)
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'nll_sums'}), flush=True)


if __name__ == '__main__':
    main()
