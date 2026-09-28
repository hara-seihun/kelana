#!/usr/bin/env python3
"""Fit the same full train-response output scales on existing binary-only images."""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'binary-factors'))
from compare import response_error  # noqa: E402

FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
BASELINE = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    p.add_argument('--baseline', type=Path, default=BASELINE)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--threads', type=int, default=8)
    a = p.parse_args()
    torch.set_num_threads(a.threads)
    a.out.mkdir(parents=True, exist_ok=True)
    with np.load(a.fixture) as fx:
        weight = torch.from_numpy(fx['weight'].copy()).float()
        train = torch.from_numpy(fx['train'].copy()).float()
        validation = torch.from_numpy(fx['validation'].copy()).float()
    layer, op = a.fixture.stem.split('-', 1)
    base = a.baseline / f'model_layers_{int(layer[5:])}_{op}_weight.json'
    report = json.loads(base.read_text())
    entries = []
    for control in report['entries']:
        source = Path(control['artifact'])
        with np.load(source) as image:
            u_bits, v_bits = image['U'].copy(), image['V'].copy()
            dims = image['dimensions'].copy()
            pre_bytes = image['scale_pre'].copy()
        n, k, rank = map(int, dims)
        u = torch.from_numpy(np.unpackbits(u_bits, axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
        v = torch.from_numpy(np.unpackbits(v_bits, axis=1, bitorder='little')[:, :k].astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(pre_bytes.astype(np.float32))
        # This is the same per-row covariance-aware scalar rule used for the
        # hybrid's binary residual. No factor bits or input scale is changed.
        raw = ((train * pre[None, :]) @ v.T) @ u.T
        target = train @ weight.T
        post = ((raw * target).sum(0) / raw.square().sum(0).clamp_min(1e-12)).half().numpy()
        rate = control['target_matrix_bpw']
        path = a.out / f'{a.fixture.stem}_binary_rate{rate:g}_postfit.npz'
        np.savez(path, U=u_bits, V=v_bits, scale_pre=pre_bytes, scale_post=post, dimensions=dims)
        estimate = (u * torch.from_numpy(post.astype(np.float32))[:, None]) @ (v * pre[None, :])
        entries.append({'target_bpw': rate, 'matrix_payload_bpw': control['matrix_payload_bpw'],
                        'rank': rank, 'payload_bytes': control['factor_bytes'] + control['scale_bytes'],
                        'serialized_file_bytes': path.stat().st_size, 'artifact': str(path),
                        'binary_original_validation_error': control['heldout_response']['relative_squared_error'],
                        'binary_postfit_validation': response_error(weight, estimate, validation),
                        'binary_postfit_train': response_error(weight, estimate, train)})
    result = {'method': 'NanoQuant ADMM binary signs + fixed FP16 input scales; full train-response FP16 output-scale least squares',
              'fixture': str(a.fixture), 'source_report': str(base), 'train_samples': train.shape[0],
              'validation_samples': validation.shape[0], 'entries': entries}
    (a.out / f'{a.fixture.stem}_binary_postfit.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'fixture': str(a.fixture), 'entries': entries}), flush=True)


if __name__ == '__main__':
    main()
