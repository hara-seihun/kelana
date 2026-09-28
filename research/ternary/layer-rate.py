#!/usr/bin/env python3
"""Price replacing disjoint ternary layers with the existing scalar-four-bit image."""
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
    ap.add_argument('--groups', default='0,1,2,3', help='comma-separated group indices; baseline always included')
    a = ap.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    source = ROOT / 'expanded-scale384'
    manifest_path = source / 'manifest.json'
    scalar_path = SCALAR / 'accounting.json'
    manifest = json.loads(manifest_path.read_text())
    scalar = json.loads(scalar_path.read_text())
    if not manifest['complete'] or len(manifest['matrices']) != 197:
        raise ValueError('Ternary image is incomplete')
    scalar_entries = {e['name']: e for e in scalar['entries'] if e['bits'] == 4}
    matrices = {r['key']: r for r in manifest['matrices']}
    if set(scalar_entries) != set(matrices):
        raise ValueError('Scalar and ternary image matrices differ')
    groups = [int(s) for s in a.groups.split(',')]
    if len(set(groups)) != len(groups) or any(i not in range(4) for i in groups):
        raise ValueError('Expected distinct group indices 0..3')
    with np.load(ROOT / 'tokens.npz') as z:
        rows = z[a.split][:a.windows].copy()
    model = load_model()
    for key, r in matrices.items():
        path = source / (key.replace('.', '_') + '.npz')
        if sha(path) != r['sha256']:
            raise ValueError(f'Ternary image changed: {key}')
        model.get_parameter(key).copy_(expanded(path))
    if model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr():
        raise ValueError('Tied head detached')
    output = dict(split=a.split, windows=a.windows, groups=groups, source=sha(Path(__file__)),
                  tokens_sha256=sha(ROOT / 'tokens.npz'), ternary_manifest_sha256=sha(manifest_path),
                  scalar_accounting_sha256=sha(scalar_path), model_source_sha256=sha(MODEL / 'source.json'),
                  unique_parameters=manifest['unique_parameters'],
                  baseline_payload_bytes=manifest['payload_bytes'],
                  execution='BF16 expanded forward for paid packed mixed images; no packed inference timing',
                  results={})
    output['results']['ternary'] = dict(payload_bytes=manifest['payload_bytes'], **loss(model, rows))
    for group in groups:
        start, end = GROUPS[group]
        keys = [key for key in matrices if key.startswith('model.layers.') and start <= int(key.split('.')[2]) < end]
        scalar_bytes = 0
        replaced_bytes = 0
        for key in keys:
            entry = scalar_entries[key]
            path = Path(entry['image'])
            if sha(path) != entry['sha256']:
                raise ValueError(f'Scalar image changed: {key}')
            with np.load(path) as image:
                weight = decode(image, 'weight')
            model.get_parameter(key).copy_(weight)
            scalar_bytes += entry['payload_bytes']
            replaced_bytes += matrices[key]['payload_bytes']
        total = manifest['payload_bytes'] + scalar_bytes - replaced_bytes
        output['results'][f'layers-{start}-{end-1}'] = dict(
            payload_bytes=total, bpw=8 * total / manifest['unique_parameters'],
            replaced_matrices=len(keys), scalar_bytes=scalar_bytes, ternary_bytes=replaced_bytes,
            **loss(model, rows))
        for key in keys:
            path = source / (key.replace('.', '_') + '.npz')
            model.get_parameter(key).copy_(expanded(path))
    destination = ROOT / 'quality' / f'layer-rate-{a.split}-{a.windows}-{"-".join(map(str, groups))}.json'
    destination.write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({'receipt': str(destination), 'results': {k: {j: v for j, v in r.items() if j != 'nll_sums'} for k, r in output['results'].items()}}), flush=True)

if __name__ == '__main__':
    main()
