#!/usr/bin/env python3
"""Score paid narrow value caches against the real causal Q/K attention consumer."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

from fit import MODEL, OUTPUT, INDEPENDENT, CAPTURES, load_capture, unpack
from fit_direct import FAMILIES, SOURCE


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def binary_weight(path):
    with np.load(path) as image:
        n, k, r = [int(v) for v in image['dimensions']]
        u = unpack(image['U'], r)
        v = unpack(image['V'], k)
        pre = torch.from_numpy(image['scale_pre'].copy()).float()
        post = torch.from_numpy(image['scale_post'].copy()).float()
    return (u * post[:, None]) @ (v * pre[None, :])


def rms(x, gamma):
    x = x.to(torch.bfloat16)
    return ((x.float() * torch.rsqrt(x.float().square().mean(-1, keepdim=True) + 1e-6))
            .to(torch.bfloat16) * gamma.to(torch.bfloat16)).float()


def rotary(q, k):
    length = q.shape[2]
    inverse = 1 / (1_000_000. ** (torch.arange(0, 128, 2).float() / 128))
    phase = torch.outer(torch.arange(length).float(), inverse)
    phase = torch.cat((phase, phase), dim=-1)
    cosine = phase.cos().to(torch.bfloat16).float()[None, None]
    sine = phase.sin().to(torch.bfloat16).float()[None, None]
    def rotate(x):
        return torch.cat((-x[..., 64:], x[..., :64]), -1)
    return q * cosine + rotate(q) * sine, k * cosine + rotate(k) * sine


def probabilities(x, wq, wk, qgamma, kgamma):
    batch, length, _ = x.shape
    q = rms((x @ wq.T).to(torch.bfloat16).float().reshape(batch, length, 16, 128), qgamma)
    k = rms((x @ wk.T).to(torch.bfloat16).float().reshape(batch, length, 8, 128), kgamma)
    q, k = rotary(q.permute(0, 2, 1, 3), k.permute(0, 2, 1, 3))
    k = k.repeat_interleave(2, dim=1)
    logits = (q @ k.transpose(-1, -2)) / math.sqrt(128)
    mask = torch.ones(length, length, dtype=torch.bool).triu(1)
    return logits.masked_fill(mask, -1e9).softmax(-1)


def dense_context(prob, x, wv):
    batch, length, _ = x.shape
    value = (x @ wv.T).to(torch.bfloat16).float().reshape(batch, length, 8, 128)
    value = value.permute(0, 2, 1, 3).repeat_interleave(2, dim=1)
    return (prob @ value).permute(0, 2, 1, 3).reshape(batch, length, -1)


def dense_attention(prob, x, wv, wo):
    return dense_context(prob, x, wv) @ wo.T


def narrow_attention(prob, x, group_factors):
    batch, length, _ = x.shape
    out = torch.zeros(batch, length, 1024)
    for group, (left, right) in enumerate(group_factors):
        compressed_value = (x @ right.T).to(torch.bfloat16).float()
        for local in range(2):
            head = 2 * group + local
            output_slice = left[local*1024:(local+1)*1024]
            out += (prob[:, head] @ compressed_value) @ output_slice.T
    return out


def error(estimate, teacher):
    return ((estimate-teacher).square().sum()/teacher.square().sum()).item()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, choices=(0, 14), required=True)
    p.add_argument('--threads', type=int, default=8)
    p.add_argument('--variant', choices=('direct', 'refined', 'joint'), default='direct')
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    with safe_open(MODEL, framework='pt', device='cpu') as source:
        names = {name: source.get_tensor(f'model.layers.{args.layer}.self_attn.{name}.weight').float()
                 for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    independent_paths = {name: INDEPENDENT / f'layer{args.layer:02d}-self_attn_{name}_proj.npz'
                         for name in ('v', 'o')}
    independent = {name: binary_weight(path) for name, path in independent_paths.items()}
    spec = importlib.util.spec_from_file_location('spectral_quant_pinned', SOURCE)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    direct = OUTPUT / f'layer{args.layer:02d}-direct'
    fit_report = json.loads((direct / 'fit.json').read_text())
    refined_report = (json.loads((OUTPUT / f'layer{args.layer:02d}-refined/refine.json').read_text())
                      if args.variant in ('refined', 'joint') else None)
    families = {}
    family_names = (refined_report['train_selected_family'],) if args.variant == 'joint' else FAMILIES
    for family in family_names:
        groups = []
        if args.variant == 'joint':
            joint = refined_report['selected_joint_image']
            if sha(Path(joint['path'])) != joint['sha256']:
                raise ValueError('combined image changed')
            with np.load(joint['path']) as f:
                source_arrays = [{key: f[key][g].copy() for key in f.files} for g in range(8)]
        else:
            rows = (refined_report['families'][family]['images'] if refined_report
                    else fit_report['families'][family]['groups'])
            source_arrays = []
            for row in rows:
                image = Path(row.get('path', row.get('image')))
                if sha(image) != row['sha256' if refined_report else 'image_sha256']:
                    raise ValueError(f'factor image changed: {image}')
                with np.load(image) as f:
                    source_arrays.append({key: f[key].copy() for key in f.files})
        for arrays in source_arrays:
            groups.append((quantizer.decode(arrays, 'left'), quantizer.decode(arrays, 'right')))
        families[family] = groups
    splits = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(args.layer, split).reshape(count, 256, 1024)
        prob = probabilities(x, names['q_proj'], names['k_proj'], names['q_norm'], names['k_norm'])
        context = dense_context(prob, x, names['v_proj'])
        with np.load(CAPTURES / f'layer{args.layer:02d}.npz') as capture:
            original_bits = capture[f'{split}_attn_out'].copy()
        actual_context = torch.from_numpy(original_bits.view(np.int16)).view(torch.bfloat16).float().reshape_as(context)
        replay_error = error(context, actual_context)
        teacher = context @ names['o_proj'].T
        independent_out = dense_attention(prob, x, independent['v'], independent['o'])
        results = {'independent_binary': error(independent_out, teacher)}
        per_window = {'independent_binary': [error(independent_out[i], teacher[i]) for i in range(count)]}
        for family, factors in families.items():
            estimate = narrow_attention(prob, x, factors)
            results[family] = error(estimate, teacher)
            per_window[family] = [error(estimate[i], teacher[i]) for i in range(count)]
        splits[split] = {'reference_squared_norm': teacher.square().sum().item(),
                         'original_attention_input_replay_error': replay_error,
                         'relative_squared_output_error': results,
                         'per_window_relative_squared_error': per_window}
    report = {'model_revision': json.loads((MODEL.parent / 'source.json').read_text())['revision'],
              'layer': args.layer, 'attention_consumer': 'original BF16 Q/K, Q/K head RMSNorm, RoPE theta 1e6, 16 Q heads/8 KV groups, 256-token causal attention',
              'capture': str(CAPTURES / f'layer{args.layer:02d}.npz'),
              'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz'),
              'independent_images': {name: {'path': str(path), 'sha256': sha(path)}
                                     for name, path in independent_paths.items()},
              'train_windows': 8, 'validation_windows': 4, 'variant': args.variant,
              'frozen_family_images': str((OUTPUT / f'layer{args.layer:02d}-refined/refine.json')
                                          if refined_report else direct / 'fit.json'),
              'train_selected_family': refined_report['train_selected_family'] if refined_report else None,
              'splits': splits}
    output = OUTPUT / f'layer{args.layer:02d}-{args.variant}-consumer.json'
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'layer': args.layer,
                      'train': splits['train']['relative_squared_output_error'],
                      'validation': splits['validation']['relative_squared_output_error'],
                      'receipt': str(output)}), flush=True)


if __name__ == '__main__':
    main()
