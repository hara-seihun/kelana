#!/usr/bin/env python3
"""Exchange sampled K norm rows using finite causal train loss, then replay BF16 attention."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


norm = load(ROOT/'causal-key-norm/measure.py', 'exchange_norm')
paid = norm.paid
finite = norm.finite
sample = norm.sample


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def smooth(base, target, positions, f, coeff):
    d = np.maximum(np.einsum('wkc,c->wk', f, coeff), 1e-8)
    z = base[:, :, positions] / np.sqrt(d[:, None, None, :] + 1e-6)
    p = target[:, :, positions]
    mask = np.arange(z.shape[-1])[None, None, None, :] <= np.asarray(positions)[None, None, :, None]
    z = np.where(mask, z, -1e30)
    top = z.max(-1, keepdims=True)
    ex = np.exp(z-top)*mask
    probs = ex / ex.sum(-1, keepdims=True)
    ce = (np.log(ex.sum(-1)) + top[..., 0] - (p*z).sum(-1)).mean()
    derivative = ((p-probs)*z / (2*(d[:, None, None, :]+1e-6))).mean(axis=(1, 2))
    return float(ce), derivative


def run(layer, group, rounds):
    torch.set_num_threads(4)
    parent_path = DATA/f'cache-slack-norm/layer{layer:02d}-group{group}.json'
    parent = json.loads(parent_path.read_text())
    score_path = DATA/f'paid-qk-cache-slack/layer{layer:02d}.json'
    score_receipt = json.loads(score_path.read_text())
    selected = parent['selected_planes'] + [r+64 for r in parent['selected_planes']]
    missing = sorted(set(range(128))-set(selected))
    rows = list(parent['sampled_rows'])
    weights = list(parent['sample_expansion_weights'])
    coeff = np.array(parent['denominator_coeff_fp16'], dtype=np.float64)
    gamma = torch.tensor(score_receipt['new_group_affine_bf16'][group], dtype=torch.bfloat16)
    q_path = DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{layer}.self_attn.'
        original = {name: model.get_tensor(prefix+name+'.weight').float()
                    for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    paid_weights = dict(original)
    paid_weights['q_proj'] = paid.paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    paid_weights['k_proj'] = paid.paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    raw, queries, teacher = [], [], []
    causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
    for split in ('train', 'validation'):
        x = finite.load_capture(layer, split).reshape(-1, 256, 1024)
        raw.append((x @ paid_weights['k_proj'].T).to(torch.bfloat16).reshape(-1, 256, 8, 128)[:, :, group])
        q, _ = paid.paid.projected(x, paid_weights, original['k_norm'])
        queries.append(q[:, 2*group:2*group+2, :, selected])
        tq, tk = paid.paid.projected(x, original, original['k_norm'])
        logits = (tq[:, 2*group:2*group+2] @ tk[:, group:group+1].transpose(-1, -2)/math.sqrt(128)).masked_fill(causal, -1e9)
        teacher.append(logits.softmax(-1))
    phase = torch.outer(torch.arange(256).float(), 1/(1_000_000.**(torch.arange(64).float()*2/128)))
    cos, sin = phase.cos().to(torch.bfloat16).float(), phase.sin().to(torch.bfloat16).float()
    base = norm.score_base(raw[0], selected, gamma, queries[0], cos, sin)
    target = teacher[0].numpy().astype(np.float64)
    positions = parent['train_query_positions']
    energy = raw[0].float().square().mean((0, 1)).numpy()
    bins = np.array_split(sorted(missing, key=lambda r: float(energy[r])), 4)
    squares = raw[0].float().square().numpy().astype(np.float64)
    original_rows = rows.copy()
    history = []
    for turn in range(rounds):
        feat = norm.features(raw[0], selected, rows, weights).numpy().astype(np.float64)
        current_ce, gradient = smooth(base, target, positions, feat, coeff)
        options = []
        for bin_index, bucket in enumerate(bins):
            for row_index in range(4*bin_index, 4*bin_index+4):
                old = rows[row_index]
                for new in bucket:
                    new = int(new)
                    if new in rows:
                        continue
                    delta = weights[row_index]*(squares[..., new]-squares[..., old])/128
                    predicted = coeff[bin_index+1]*np.einsum('wk,wk->', gradient, delta)
                    options.append((predicted, row_index, new, delta))
        options.sort(key=lambda x: x[0])
        best = (current_ce, None)
        for _, row_index, new, delta in options[:16]:
            changed = feat.copy()
            changed[..., row_index//4+1] += delta
            ce, _ = smooth(base, target, positions, changed, coeff)
            if ce < best[0]:
                best = (ce, (row_index, new))
        if best[1] is None:
            break
        row_index, new = best[1]
        old = rows[row_index]
        rows[row_index] = new
        history.append({'removed': old, 'added': new, 'bin': row_index//4, 'train_ce_before': current_ce,
                        'train_ce_after_fixed_coeff': best[0]})
    tf = norm.features(raw[0], selected, rows, weights)
    fitted, training = norm.fit(base, tf, target, positions, coeff)
    original_feat = norm.features(raw[0], selected, original_rows, weights).numpy().astype(np.float64)
    new_feat = tf.numpy().astype(np.float64)
    train = {'parent': smooth(base, target, positions, original_feat, coeff)[0],
             'exchanged_fixed_coeff': smooth(base, target, positions, new_feat, coeff)[0],
             'exchanged_refit': smooth(base, target, positions, new_feat, fitted)[0]}
    held = {}
    for name, these_rows, these_coeff in [('parent', original_rows, coeff), ('exchanged_fixed_coeff', rows, coeff),
                                          ('exchanged_refit', rows, fitted)]:
        hf = norm.features(raw[1], selected, these_rows, weights)
        denominator = (hf*torch.tensor(these_coeff, dtype=torch.float32)).sum(-1, keepdim=True)
        held[name] = sample.score(raw[1], selected, denominator, gamma, queries[1], teacher[1],
                                  teacher[1].clamp_min(1e-30).log(), cos, sin, causal)
    return {'layer': layer, 'group': group, 'rounds_requested': rounds, 'exchanges': history,
            'parent_rows': original_rows, 'exchanged_rows': rows, 'row_weights': weights,
            'selected_planes': parent['selected_planes'], 'coeff_fp16': fitted.tolist(),
            'train_smooth_ce': train, 'refit': training, 'held_kl_by_window': held,
            'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path),
            'score_receipt_sha256': sha(score_path), 'model_sha256': sha(finite.MODEL),
            'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{layer:02d}.npz'),
            'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path),
            'observation': 'original-producer paid binary Q/K; fixed 128-plane two-head score; BF16-normalized full causal held KL',
            'cost': {'raw_rows_per_group': len(selected)+len(rows), 'signed_output_factor_terms_per_group_token': (len(selected)+len(rows))*256,
                     'padded_key_bytes_per_group': 64, 'two_head_score_products_per_key_group': 2*len(selected)}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--group', type=int, choices=range(8), required=True)
    parser.add_argument('--rounds', type=int, default=2)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = run(args.layer, args.group, args.rounds)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'group': args.group, 'exchanges': result['exchanges'],
                      'train': result['train_smooth_ce'],
                      'held': {name: float(np.mean(values)) for name, values in result['held_kl_by_window'].items()}}, indent=2), flush=True)


if __name__ == '__main__':
    main()
