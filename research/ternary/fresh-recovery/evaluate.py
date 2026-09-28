#!/usr/bin/env python3
"""Compare a frozen paid ternary image on the disjoint scale-continuation panel."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import torch
import torch.nn.functional as F

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pilot import expanded, load_model

ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary')
FIXTURE = ROOT / 'fresh-recovery/tokens.npz'
OUT = ROOT / 'fresh-recovery'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


@torch.inference_mode()
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--name', required=True)
    parser.add_argument('--offset', type=int, required=True)
    parser.add_argument('--windows', type=int, default=8)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    image = ROOT / args.name
    manifest = json.loads((image / 'manifest.json').read_text())
    assert manifest['complete'] and manifest['matrix_count'] == 197
    model = load_model()
    for record in manifest['matrices']:
        file = image / (record['key'].replace('.', '_') + '.npz')
        assert sha(file) == record['sha256']
        model.get_parameter(record['key']).copy_(expanded(file))
    assert model.lm_head.weight.data_ptr() == model.model.embed_tokens.weight.data_ptr()
    with np.load(FIXTURE) as z:
        rows = z['test'][args.offset:args.offset + args.windows].copy()
    assert len(rows) == args.windows
    losses = []
    for row in rows:
        ids = torch.tensor(row, dtype=torch.long, device='cuda')[None]
        logits = model(ids, use_cache=False).logits[:, :-1].float()
        losses.append(float(F.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                                           ids[:, 1:].reshape(-1), reduction='sum')) / 255)
    OUT.mkdir(exist_ok=True)
    receipt = dict(name=args.name, offset=args.offset, windows=args.windows,
                   per_window_nll=losses, mean_nll=float(np.mean(losses)),
                   image_manifest_sha256=sha(image / 'manifest.json'),
                   fixture_sha256=sha(FIXTURE), source_sha256=sha(Path(__file__)),
                   model_source_sha256=sha(ROOT.parent / 'models/qwen3-0.6b/source.json'),
                   bpw=manifest['bpw'])
    target = OUT / f'{args.name}-{args.offset}-{args.windows}.json'
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt), flush=True)


if __name__ == '__main__':
    main()
