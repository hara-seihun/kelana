#!/usr/bin/env python3
"""Matched gold-loss scale updates for paid ternary and ternary/Q4 complete images."""
import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

from pilot import DATA, ROOT, MODEL, load_model, sha
from tune import _install, _nll

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'quantization-discovery/subbit'))
from spectral_quant import decode

SOURCE = ROOT / 'expanded-scale384'
SCALAR = DATA / 'full-scalar' / 'accounting.json'
FIXTURE = ROOT / 'expanded-tokens.npz'
VALIDATION = ROOT / 'tokens.npz'
GROUP = (14, 21)


class FrozenLinear(nn.Module):
    def __init__(self, weight):
        super().__init__()
        self.register_buffer('weight', weight)

    def forward(self, x):
        return F.linear(x, self.weight)


def install_q4(model, providers, manifest):
    entries = {e['name']: e for e in json.loads(SCALAR.read_text())['entries'] if e['bits'] == 4}
    selected = [r for r in manifest['matrices'] if r['key'].startswith('model.layers.')
                and GROUP[0] <= int(r['key'].split('.')[2]) < GROUP[1]]
    if len(selected) != 7 * (GROUP[1] - GROUP[0]):
        raise ValueError('Incomplete group substitution')
    bytes_total = manifest['payload_bytes']
    hashes = {}
    for record in selected:
        key = record['key']
        entry = entries[key]
        path = Path(entry['image'])
        if sha(path) != entry['sha256']:
            raise ValueError(f'Q4 image changed: {key}')
        with np.load(path) as image:
            weight = decode(image, 'weight').to(device='cuda', dtype=torch.bfloat16)
        parts = key.split('.')
        module = model.model.layers[int(parts[2])]
        for part in parts[3:-2]:
            module = getattr(module, part)
        setattr(module, parts[-2], FrozenLinear(weight))
        del providers[key]
        bytes_total += entry['payload_bytes'] - record['payload_bytes']
        hashes[key] = entry['sha256']
    return bytes_total, hashes


def nll(model, rows):
    model.eval()
    with torch.no_grad():
        sums = [float(_nll(model, torch.as_tensor(row, device='cuda', dtype=torch.long)))
                for row in rows]
    return sum(sums) / len(sums), sums


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--arm', choices=['ternary', 'mixed'], required=True)
    p.add_argument('--steps', type=int, default=8)
    p.add_argument('--train-offset', type=int, default=448)
    p.add_argument('--train-windows', type=int, default=8)
    p.add_argument('--learning-rate', type=float, default=.0003)
    p.add_argument('--name', required=True)
    p.add_argument('--test-windows', type=int, default=0)
    a = p.parse_args()
    if a.steps <= 0 or a.train_windows <= 0 or a.learning_rate <= 0:
        raise ValueError('Positive steps, windows, learning rate required')
    path = ROOT / 'quality' / (a.name + '.json')
    scale_path = path.with_suffix('.scales.npz')
    if path.exists() or scale_path.exists():
        raise FileExistsError(path)
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    started = time.time()
    manifest_path = SOURCE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    if not manifest['complete'] or len(manifest['matrices']) != 197:
        raise ValueError('Incomplete ternary source')
    model = load_model()
    providers = _install(model, SOURCE, manifest, set())
    image_bytes, q4_hashes = (install_q4(model, providers, manifest) if a.arm == 'mixed'
                              else (manifest['payload_bytes'], {}))
    with np.load(FIXTURE) as fixture:
        train = fixture['train'][a.train_offset:a.train_offset + a.train_windows].copy()
    with np.load(VALIDATION) as fixture:
        validation = fixture['validation'][:8].copy()
        test = fixture['test'][:a.test_windows].copy()
    if len(train) != a.train_windows or len(validation) != 8 or len(test) != a.test_windows:
        raise ValueError('Incomplete train or validation fixture')
    before, before_rows = nll(model, validation)
    model.train()
    model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={'use_reentrant': False})
    optimizer = torch.optim.Adam([provider.log_scales for provider in providers.values()], lr=a.learning_rate)
    train_losses = []
    for step in range(a.steps):
        optimizer.zero_grad(set_to_none=True)
        tokens = torch.as_tensor(train[step % len(train)], device='cuda', dtype=torch.long)
        loss = _nll(model, tokens)
        if not torch.isfinite(loss):
            raise ValueError(f'Nonfinite train loss at step {step}')
        loss.backward()
        optimizer.step()
        train_losses.append(float(loss.detach()))
    after, after_rows = nll(model, validation)
    test_nll, test_rows = nll(model, test) if a.test_windows else (None, [])
    with torch.no_grad():
        scales = {key.replace('.', '_'): provider.log_scales.exp().half().cpu().numpy()
                  for key, provider in providers.items()}
    np.savez(scale_path, **scales)
    result = dict(arm=a.arm, source_manifest_sha256=sha(manifest_path), q4_accounting_sha256=sha(SCALAR),
                  q4_images=q4_hashes, model_source_sha256=sha(MODEL / 'source.json'),
                  train_fixture_sha256=sha(FIXTURE), validation_fixture_sha256=sha(VALIDATION),
                  script_sha256=sha(Path(__file__)), tune_sha256=sha(Path(__file__).with_name('tune.py')),
                  image_bytes=image_bytes, bpw=8 * image_bytes / manifest['unique_parameters'],
                  unique_parameters=manifest['unique_parameters'], train_offset=a.train_offset,
                  train_windows=a.train_windows, steps=a.steps, learning_rate=a.learning_rate,
                  train_pre_update_nll=train_losses, validation_before=before, validation_after=after,
                  validation_before_rows=before_rows, validation_after_rows=after_rows,
                  test_windows=a.test_windows, test_nll=test_nll, test_rows=test_rows,
                  scales_path=str(scale_path), scales_sha256=sha(scale_path),
                  scale_payload_bytes=sum(value.nbytes for value in scales.values()),
                  execution='Complete Qwen3-0.6B BF16 expansion during full-model gold-loss optimization; no native packed timing',
                  seconds=time.time()-started)
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('q4_images', 'train_pre_update_nll',
                                  'validation_before_rows', 'validation_after_rows', 'test_rows')}), flush=True)


if __name__ == '__main__':
    main()
