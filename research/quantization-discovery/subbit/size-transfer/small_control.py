#!/usr/bin/env python3
"""Apply the same four output sweeps to the pinned 0.6B middle down control."""
import json
from pathlib import Path

import numpy as np
import torch

from fit_binary import response, activation_output_fit

FIXTURE = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer14-mlp_down_proj.npz')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures/model_layers_14_mlp_down_proj_weight_0.55.npz')
OUTPUT = Path('/path/to/workspace/data/kelana-subbit/size-transfer/control-0.6b-down.json')


def main():
    torch.set_num_threads(8)
    with np.load(FIXTURE) as d:
        weight, train, validation = [torch.from_numpy(d[key].copy()).float()
                                     for key in ('weight', 'train', 'validation')]
    with np.load(IMAGE) as d:
        n, k, rank = [int(x) for x in d['dimensions']]
        u = torch.from_numpy(np.unpackbits(d['U'], axis=1, bitorder='little')[:, :rank].copy().astype(np.float32)) * 2 - 1
        v = torch.from_numpy(np.unpackbits(d['V'], axis=1, bitorder='little')[:, :k].copy().astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(d['scale_pre'].copy()).float()
        post = torch.from_numpy(d['scale_post'].copy()).float()
    initial = response(weight, validation, u, v, pre, post)
    u, post = activation_output_fit(weight, train, u, v, pre, post)
    record = {'fixture': str(FIXTURE), 'original_image': str(IMAGE), 'dimensions': [n, k],
              'rank': rank, 'admm_heldout_error': initial,
              'four_sweep_heldout_error': response(weight, validation, u, v, pre, post)}
    OUTPUT.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record))


if __name__ == '__main__':
    main()
