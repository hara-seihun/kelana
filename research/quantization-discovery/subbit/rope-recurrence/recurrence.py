#!/usr/bin/env python3
"""Pinned Q/K witness for the stationary linear RoPE score-recurrence theorem."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from safetensors import safe_open
import torch


def sha(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def score_coefficients(q, b):
    half = len(q) // 2
    a = q[:half] * b[:half] + q[half:] * b[half:]
    c = q[half:] * b[:half] - q[:half] * b[half:]
    return a, c


def recurrence(a, c, frequencies, count):
    cosine, sine = np.ones_like(frequencies), np.zeros_like(frequencies)
    step_cos, step_sin = np.cos(frequencies), np.sin(frequencies)
    scores = np.empty(count)
    for t in range(count):
        scores[t] = a @ cosine + c @ sine
        cosine, sine = step_cos * cosine - step_sin * sine, step_sin * cosine + step_cos * sine
    return scores


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__)
    model = args.model / 'model.safetensors'
    config = args.model / 'config.json'
    cfg = json.loads(config.read_text())
    half = cfg['head_dim'] // 2
    frequencies = cfg['rope_theta'] ** (-np.arange(half, dtype=np.float64) / half)
    times = np.arange(256, dtype=np.float64)
    result = {'source_sha256': sha(source), 'model_sha256': sha(model), 'config_sha256': sha(config),
              'scope': 'original BF16 Q/K first input columns, cast to FP64; all 2 heads of 8 GQA groups',
              'head_dim': cfg['head_dim'], 'positions': 256, 'layers': {}}
    with safe_open(model, framework='pt', device='cpu') as tensors:
        for layer in (0, 14):
            prefix = f'model.layers.{layer}.self_attn.'
            q = tensors.get_tensor(prefix + 'q_proj.weight')[:, 0].to(torch.float64).numpy()
            k = tensors.get_tensor(prefix + 'k_proj.weight')[:, 0].to(torch.float64).numpy()
            entries = []
            for group in range(cfg['num_key_value_heads']):
                b = k[group * 2 * half:(group + 1) * 2 * half]
                for local_head in range(cfg['num_attention_heads'] // cfg['num_key_value_heads']):
                    head = group * (cfg['num_attention_heads'] // cfg['num_key_value_heads']) + local_head
                    query = q[head * 2 * half:(head + 1) * 2 * half]
                    a, c = score_coefficients(query, b)
                    direct = np.cos(times[:, None] * frequencies) @ a + np.sin(times[:, None] * frequencies) @ c
                    replay = recurrence(a, c, frequencies, len(times))
                    amplitudes = np.hypot(a, c)
                    entries.append({'group': group, 'head': head, 'nonzero_modes': int(2 * np.count_nonzero(amplitudes)),
                                    'min_mode_amplitude': float(amplitudes.min()),
                                    'max_recurrence_absolute_error': float(np.max(np.abs(direct - replay))),
                                    'max_score_magnitude': float(np.max(np.abs(direct)))})
            result['layers'][str(layer)] = entries
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    for layer, entries in result['layers'].items():
        print(layer, 'minimum modes', min(e['nonzero_modes'] for e in entries),
              'minimum amplitude', min(e['min_mode_amplitude'] for e in entries),
              'max replay error', max(e['max_recurrence_absolute_error'] for e in entries))


if __name__ == '__main__':
    main()
