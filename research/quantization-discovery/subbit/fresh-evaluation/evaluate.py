#!/usr/bin/env python3
"""Paired q0-only whole-model continuation on immutable fresh WikiText windows."""
import argparse
import hashlib
import json
import math
import os
import time
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-0.6b'
DATA = ROOT / 'fresh-evaluation'
IMAGES = {
    'spectral_seed': ROOT / 'spectral-quant/layer00-self_attn_q_proj-b0.539062-l4r4-g128-s0.5-f1.npz',
    'spectral_mse_sweeps': ROOT / 'spectral-refine/layer00-self_attn_q_proj-b0.539062-l4r4-g128-s0.5-f1-sweeps4.npz',
    'spectral_attention': ROOT / 'attention-metric/final/layer00_q_rank88_attention_refined.npz',
    'binary_coordinate_sweeps': ROOT / 'block-factor/control-layer0-q.npz',
}


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def quantized_factor(image, name):
    rows, cols, bits, group = map(int, image[name + '_shape'])
    planes = np.unpackbits(image[name + '_codes'], axis=1, bitorder='little')[:, :cols * bits]
    codes = (planes.reshape(rows, cols, bits).astype(np.int16) << np.arange(bits)).sum(-1)
    scale = np.repeat(image[name + '_scales'].astype(np.float32), group, axis=1)[:, :cols]
    return torch.from_numpy((2 * codes - (2**bits - 1)) * scale).float()


def load_spectral(path):
    with np.load(path) as image:
        return quantized_factor(image, 'left') @ quantized_factor(image, 'right')


def load_binary(path):
    with np.load(path) as image:
        n, k, rank = map(int, image['dimensions'])
        u = torch.from_numpy(np.unpackbits(image['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32)) * 2 - 1
        v = torch.from_numpy(np.unpackbits(image['V'], axis=1, bitorder='little')[:, :k].astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(image['scale_pre'].astype(np.float32))
        post = torch.from_numpy(image['scale_post'].astype(np.float32))
    return (u * post[:, None]) @ (v * pre[None, :])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--split', choices=('validation', 'test'), required=True)
    p.add_argument('--length', type=int, choices=(256, 1024), required=True)
    p.add_argument('--start-index', type=int, required=True)
    p.add_argument('--count', type=int, required=True)
    p.add_argument('--data', type=Path, default=DATA)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    torch.set_num_threads(4)
    torch.manual_seed(42)
    torch.backends.cuda.matmul.allow_tf32 = False
    manifest = json.loads((a.data / 'manifest.json').read_text())
    if manifest['tokens_sha256'] != sha(a.data / 'tokens.npz'):
        raise ValueError('token fixture changed after selection')
    key = f'{a.split}_{a.length}'
    with np.load(a.data / 'tokens.npz') as tokens:
        batch = tokens[key].copy()
    starts = manifest['windows'][key]['starts']
    if a.start_index < 0 or a.count < 1 or a.start_index + a.count > len(batch):
        p.error('panel outside frozen token range')
    hashes = {name: sha(path) for name, path in IMAGES.items()}
    weights = {name: (load_binary(path) if name.startswith('binary') else load_spectral(path))
               for name, path in IMAGES.items()}
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
              dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    parameter = model.get_submodule('model.layers.0.self_attn.q_proj').weight
    original = parameter.detach().clone()
    weights = {name: weight.to(dtype=torch.bfloat16, device='cuda') for name, weight in weights.items()}
    a.out.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    with a.out.open('w') as file, torch.inference_mode():
        for index in range(a.start_index, a.start_index + a.count):
            token_ids = torch.from_numpy(batch[index].astype(np.int64)).to('cuda').unsqueeze(0)
            target = token_ids[0, 1:]
            record = {'split': a.split, 'length': a.length, 'index': index,
                      'token_start': starts[index], 'predictions': a.length - 1,
                      'tokens_sha256': manifest['tokens_sha256'], 'images_sha256': hashes,
                      'model_revision': manifest['model_revision'], 'arms': {}}
            teacher_logp = None
            for name in ('reference', *IMAGES):
                parameter.copy_(original if name == 'reference' else weights[name])
                logits = model(token_ids, use_cache=False).logits[0, :-1].float()
                logp = logits.log_softmax(-1)
                nll = -logp.gather(1, target[:, None]).sum().item()
                if name == 'reference':
                    teacher_logp = logp
                    kl = 0.
                    agreement = a.length - 1
                else:
                    kl = (teacher_logp.exp() * (teacher_logp - logp)).sum().item()
                    agreement = int((teacher_logp.argmax(-1) == logp.argmax(-1)).sum().item())
                record['arms'][name] = {'nll_sum': nll, 'teacher_kl_sum': kl,
                                        'argmax_agreements': agreement}
                del logits, logp
            file.write(json.dumps(record) + '\n')
            file.flush()
            print(json.dumps({'index': index, 'split': a.split, 'length': a.length,
                              'seconds': time.monotonic() - started,
                              'nll': {n: round(v['nll_sum'] / (a.length - 1), 5)
                                      for n, v in record['arms'].items()}}), flush=True)
    with torch.no_grad():
        parameter.copy_(original)


if __name__ == '__main__':
    main()
