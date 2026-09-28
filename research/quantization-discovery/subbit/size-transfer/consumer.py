#!/usr/bin/env python3
"""Measure Q projection error at its immediately consumed headwise Q normalization."""
import argparse
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from continuation import binary_weight, spectral_weight

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-1.7b'
FACTORS = ROOT / 'size-transfer/factors'


def norm_heads(values, scale, eps, heads):
    head_dim = scale.numel()
    x = values.reshape(-1, heads, head_dim)
    return (x * torch.rsqrt(x.square().mean(-1, keepdim=True) + eps) * scale).reshape(values.shape)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--fixture', type=Path, required=True)
    args = p.parse_args()
    torch.set_num_threads(8)
    name = args.fixture.stem
    layer = int(name.split('-')[0][5:])
    config = json.loads((MODEL / 'config.json').read_text())
    weight_name = f'model.layers.{layer}.self_attn.q_norm.weight'
    index = json.loads((MODEL / 'model.safetensors.index.json').read_text())
    with safe_open(MODEL / index['weight_map'][weight_name], framework='pt', device='cpu') as shard:
        scale = shard.get_tensor(weight_name).float()
    with np.load(args.fixture) as data:
        weight, inputs = [torch.from_numpy(data[key].copy()).float() for key in ('weight', 'validation')]
    binary = json.loads((FACTORS / f'{name}-binary.json').read_text())
    spectral = json.loads((FACTORS / f'{name}-spectral.json').read_text())
    selected = next(row for row in spectral['entries'] if row['image'] == spectral['selected_image'])
    reference = inputs @ weight.T
    normalized_reference = norm_heads(reference, scale, config['rms_norm_eps'], config['num_attention_heads'])
    arms = {}
    for label, replacement in (('binary', binary_weight(binary)), ('spectral', spectral_weight(selected))):
        raw = inputs @ replacement.T
        normalized = norm_heads(raw, scale, config['rms_norm_eps'], config['num_attention_heads'])
        arms[label] = {'raw_response_error': ((raw - reference).square().sum()/reference.square().sum()).item(),
                       'normalized_response_error': ((normalized-normalized_reference).square().sum()/normalized_reference.square().sum()).item()}
    result = {'fixture': str(args.fixture), 'q_norm': weight_name, 'head_dim': scale.numel(),
              'heads': config['num_attention_heads'], 'eps': config['rms_norm_eps'],
              'arms': arms}
    output = FACTORS / f'{name}-qnorm.json'
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
