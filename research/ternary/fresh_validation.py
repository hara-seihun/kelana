#!/usr/bin/env python3
"""Score frozen, paid complete-model images on unused validation windows 8–15."""
import argparse
import gc
import json
from pathlib import Path

import numpy as np
import torch

from calibrated_splice import Q4, SOURCE, VALIDATION, install_q4, nll
from pilot import MODEL, load_model, sha
from tune import _install

ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary/quality')
ARMS = ('mixed-recovery-control-test-v1', 'calibrated-splice-l17-v1')


def evaluate(name, rows, manifest):
    receipt_path = ROOT / (name + '.json')
    receipt = json.loads(receipt_path.read_text())
    scales_path = Path(receipt['scales_path'])
    if sha(scales_path) != receipt['scales_sha256']:
        raise ValueError(f'Changed scale companion for {name}')
    if receipt['source_manifest_sha256'] != sha(SOURCE / 'manifest.json'):
        raise ValueError(f'Changed packed source for {name}')
    model = load_model()
    providers = _install(model, SOURCE, manifest, set())
    if name == ARMS[1]:
        image_bytes, images = install_q4(model, providers, manifest, receipt['layer'])
        if image_bytes != receipt['image_bytes'] or images != receipt['q4_images']:
            raise ValueError('Calibrated splice no longer matches frozen image')
        if receipt['q4_manifest_sha256'] != sha(Q4):
            raise ValueError('Changed calibrated Q4 image')
    with np.load(scales_path) as scales, torch.no_grad():
        if set(scales.files) != {key.replace('.', '_') for key in providers}:
            raise ValueError('Scale keys differ from frozen image')
        for key, provider in providers.items():
            scale = torch.as_tensor(scales[key.replace('.', '_')], device='cuda')
            if scale.shape != provider.log_scales.shape or not torch.isfinite(scale).all() or (scale <= 0).any():
                raise ValueError(f'Invalid scale {key}')
            provider.log_scales.copy_(scale.float().log())
            if not torch.equal(provider._scales().half(), scale):
                raise ValueError(f'Cannot restore FP16 scales exactly for {key}')
    score, per_window = nll(model, rows)
    result = dict(receipt_sha256=sha(receipt_path), scales_sha256=sha(scales_path),
                  image_bytes=receipt['image_bytes'], bpw=receipt['bpw'],
                  mean_nll=score, per_window=per_window)
    del model, providers
    gc.collect()
    torch.cuda.empty_cache()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise FileExistsError(args.output)
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    manifest_path = SOURCE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    with np.load(VALIDATION) as fixture:
        rows = fixture['validation'][8:16].copy()
    if rows.shape != (8, 256):
        raise ValueError('Missing fresh validation rows')
    arms = {name: evaluate(name, rows, manifest) for name in ARMS}
    delta = np.array(arms[ARMS[1]]['per_window']) - np.array(arms[ARMS[0]]['per_window'])
    result = dict(window_indices=list(range(8, 16)), target_predictions=8*255,
                  fixture_sha256=sha(VALIDATION), source_manifest_sha256=sha(manifest_path),
                  model_source_sha256=sha(MODEL / 'source.json'), script_sha256=sha(Path(__file__)),
                  arms=arms, q4_minus_ternary=float(delta.mean()),
                  paired_standard_error=float(delta.std(ddof=1)/np.sqrt(len(delta))),
                  wins=int((delta < 0).sum()),
                  contract='Frozen paid images; complete-model gold NLL on unused validation rows; BF16 expanded quality only')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: val for key, val in result.items() if key != 'arms'}), flush=True)


if __name__ == '__main__':
    main()
