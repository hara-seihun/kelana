#!/usr/bin/env python3
"""Price selected-row RMSNorm against the actual paid binary K image."""
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


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def squared(raw, indices):
    return raw[..., indices].float().square().mean(-1, keepdim=True)


def fit(train_raw, indices):
    selected = squared(train_raw, indices).flatten().double()
    full = train_raw.float().square().mean(-1).flatten().double()
    a = (selected @ full / (selected @ selected)).item()
    x = torch.stack((selected, torch.ones_like(selected)), -1)
    affine = torch.linalg.lstsq(x, full).solution.tolist()
    return a, (max(0., affine[0]), max(0., affine[1]))


def normalized(raw, denominator, gamma):
    return ((raw.float() * torch.rsqrt(denominator + 1e-6)).to(torch.bfloat16) * gamma).float()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    finite = module(ROOT/'rope-finite-kl/fit.py', 'key_factor_finite')
    helper = module(ROOT/'value-observer/measure.py', 'key_factor_helper')
    selected_path = DATA/f'rope-group-affine/layer{args.layer:02d}.json'
    gain_path = DATA/f'rope-causal-gain/layer{args.layer:02d}.json'
    image_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    selected = json.loads(selected_path.read_text())
    masks = json.loads(gain_path.read_text())['masks']
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        wq = model.get_tensor(prefix+'q_proj.weight').float()
        wk = model.get_tensor(prefix+'k_proj.weight').float()
        qgamma = model.get_tensor(prefix+'q_norm.weight').float()
        kgamma = model.get_tensor(prefix+'k_norm.weight').float()
    paid = helper.binary_weight(image_path).to(torch.bfloat16).float()
    gamma = torch.tensor(selected['group_affine_bf16'], dtype=torch.bfloat16)
    train_x = finite.load_capture(args.layer, 'train').reshape(8, 256, 1024)
    held_x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    train_raw = (train_x @ paid.T).to(torch.bfloat16).reshape(8, 256, 8, 128)
    held_raw = (held_x @ paid.T).to(torch.bfloat16).reshape(4, 256, 8, 128)
    # The teacher keeps original weights and the original shared RMSNorm affine.
    teacher_q, teacher_k = finite.projections(held_x, dict(q_proj=wq, k_proj=wk, q_norm=qgamma, k_norm=kgamma))
    cosine_phase = 1 / (1_000_000. ** (torch.arange(64).float() * 2 / 128))
    phase = torch.outer(torch.arange(256).float(), cosine_phase)
    c = phase.cos().to(torch.bfloat16).float()
    s = phase.sin().to(torch.bfloat16).float()
    causal = torch.ones(256, 256, dtype=torch.bool).triu(1)
    entries = []
    for g, planes in enumerate(masks):
        indices = planes + [p+64 for p in planes]
        tr = train_raw[:, :, g]
        raw = held_raw[:, :, g]
        slope, (affine_slope, intercept) = fit(tr, indices)
        norm = raw.float().square().mean(-1, keepdim=True)
        sample = squared(raw, indices)
        denom = {'full': norm, 'selected': sample,
                 'fitted_scale': sample*slope,
                 'fitted_affine': sample*affine_slope + intercept}
        q = teacher_q[:, 2*g:2*g+2, :, indices]
        teacher_logits = teacher_q[:, 2*g:2*g+2] @ teacher_k[:, g:g+1].transpose(-1, -2) / math.sqrt(128)
        teacher_logits = teacher_logits.masked_fill(causal, -1e9)
        p = teacher_logits.softmax(-1)
        logp = teacher_logits.log_softmax(-1)
        scores = {}
        match = {}
        base = None
        for arm, d in denom.items():
            k = normalized(raw[:, :, indices], d, gamma[g, indices])
            if arm == 'full':
                base = k
            else:
                match[arm] = int((k.to(torch.bfloat16).view(torch.int16) == base.to(torch.bfloat16).view(torch.int16)).sum())
            n = len(planes)
            rot = torch.cat((k[..., :n]*c[:, planes] - k[..., n:]*s[:, planes],
                             k[..., n:]*c[:, planes] + k[..., :n]*s[:, planes]), -1)
            logits = (q @ rot[:, None].transpose(-1, -2) / math.sqrt(128)).masked_fill(causal, -1e9)
            kl = (p*(logp-logits.log_softmax(-1)).masked_fill(causal, 0)).sum(-1).mean(dim=(1, 2))
            scores[arm] = kl.tolist()
        n_total = raw.float().square().sum(-1)
        n_sample = sample.squeeze(-1)*128
        entries.append({'group': g, 'planes': len(planes), 'fit_slope': slope,
                        'fit_affine': [affine_slope, intercept],
                        'selected_energy_fraction_held_mean': float((n_sample/n_total).mean()),
                        'denominator_relative_rms_error': {arm: float(torch.sqrt(((d.squeeze(-1)/norm.squeeze(-1)-1)**2).mean())) for arm, d in denom.items() if arm != 'full'},
                        'selected_bf16_equal_count': match, 'selected_bf16_total': raw.shape[0]*raw.shape[1]*len(indices),
                        'kl_by_held_window': scores})
    summary = {arm: float(np.mean([np.mean(entry['kl_by_held_window'][arm]) for entry in entries]))
               for arm in ('full', 'selected', 'fitted_scale', 'fitted_affine')}
    receipt = {'layer': args.layer, 'train_windows': 8, 'held_windows': 4,
               'source_sha256': sha(Path(__file__)), 'model_sha256': sha(finite.MODEL),
               'image_sha256': sha(image_path), 'group_receipt_sha256': sha(selected_path),
               'gain_receipt_sha256': sha(gain_path),
               'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
               'map': 'paid BF16-expanded K binary image; original-producer Q and teacher K; original-producer train/validation capture; selected group affine and fixed RoPE masks; BF16 raw K and selected normalized K; FP32 RoPE/score, causal KL',
               'group': entries, 'mean_held_kl': summary,
               'work': {'rank': 256, 'input_stage_signed_terms': 256*1024,
                        'full_output_stage_signed_terms': 256*1024,
                        'selected_output_stage_signed_terms': 256*224,
                        'full_raw_key_coordinates': 1024, 'selected_raw_key_coordinates': 224}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'layer': args.layer, 'mean_held_kl': summary,
                      'mean_relative_denominator_error': {arm: float(np.mean([e['denominator_relative_rms_error'][arm] for e in entries])) for arm in ('selected','fitted_scale','fitted_affine')}}, indent=2))


if __name__ == '__main__':
    main()
