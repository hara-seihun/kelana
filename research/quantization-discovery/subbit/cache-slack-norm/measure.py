#!/usr/bin/env python3
"""Fit a sparse positive K denominator after filling the paid score cache lines."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from importlib.util import module_from_spec, spec_from_file_location

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = spec_from_file_location(name, path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


norm = imported(ROOT/'causal-key-norm/measure.py', 'sparse_norm')
paid = norm.paid
finite = norm.finite
sample = norm.sample


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--group', type=int, choices=range(8), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    g = args.group
    receipt_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    receipt = json.loads(receipt_path.read_text())
    planes = receipt['new_masks'][g]
    selected = planes + [r+64 for r in planes]
    missing = sorted(set(range(128))-set(selected))
    gamma = torch.tensor(receipt['new_group_affine_bf16'][g], dtype=torch.bfloat16)
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float()
                    for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    weights = dict(original)
    weights['q_proj'] = paid.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    weights['k_proj'] = paid.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    xs = [finite.load_capture(args.layer, split).reshape(-1, 256, 1024)
          for split in ('train', 'validation')]
    raw, queries, teacher = [], [], []
    causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
    for x in xs:
        raw.append((x @ weights['k_proj'].T).to(torch.bfloat16).reshape(-1, 256, 8, 128)[:, :, g])
        q, _ = paid.paid.projected(x, weights, original['k_norm'])
        queries.append(q[:, 2*g:2*g+2, :, selected])
        tq, tk = paid.paid.projected(x, original, original['k_norm'])
        reference = (tq[:, 2*g:2*g+2] @ tk[:, g:g+1].transpose(-1, -2)/math.sqrt(128)).masked_fill(causal, -1e9)
        teacher.append(reference.softmax(-1))
    phase = torch.outer(torch.arange(256).float(), 1/(1_000_000.**(torch.arange(64).float()*2/128)))
    cos, sin = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    z = norm.score_base(raw[0], selected, gamma, queries[0], cos, sin)
    positions = json.loads((DATA/f'paid-qk-plane-gain/layer{args.layer:02d}.json').read_text())['train_query_positions']
    train_energy = raw[0].float().square().mean((0, 1)).numpy()
    rows, weights = sample.draw(missing, train_energy, 16, 20260923+g*1009+args.layer, True)
    tf = norm.features(raw[0], selected, rows, weights)
    hf = norm.features(raw[1], selected, rows, weights)
    initial = np.ones(5, dtype=np.float64)
    coeff, training = norm.fit(z, tf, teacher[0].numpy().astype(np.float64), positions, initial)
    held_denominator = raw[1].float().square().mean(-1, keepdim=True)
    values = {}
    for name, denominator in [('full', held_denominator),
                              ('unfit', (hf*torch.tensor(initial, dtype=torch.float32)).sum(-1, keepdim=True)),
                              ('causal_fit', (hf*torch.tensor(coeff, dtype=torch.float32)).sum(-1, keepdim=True))]:
        values[name] = sample.score(raw[1], selected, denominator, gamma, queries[1], teacher[1],
                                    teacher[1].clamp_min(1e-30).log(), cos, sin, causal)
    result = {'layer': args.layer, 'group': g, 'selected_planes': planes, 'sampled_rows': rows,
              'sample_expansion_weights': weights, 'denominator_coeff_fp16': coeff.tolist(),
              'train': training, 'held_kl_by_window': values, 'train_query_positions': positions,
              'cost': {'selected_rows': len(selected), 'sampled_rows': 16, 'factor_rank': 256,
                       'k_common_terms_per_layer': 262144, 'score_products_per_key_both_heads': 2*len(selected)},
              'source_sha256': sha(Path(__file__)), 'norm_source_sha256': sha(ROOT/'causal-key-norm/measure.py'),
              'cache_slack_receipt_sha256': sha(receipt_path), 'model_sha256': sha(finite.MODEL),
              'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'group': g, 'mask_size': len(planes),
                      'held': {name: float(np.mean(v)) for name, v in values.items()}}, indent=2), flush=True)


if __name__ == '__main__':
    main()
