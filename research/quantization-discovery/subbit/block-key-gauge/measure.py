#!/usr/bin/env python3
"""Block-anchor nibble keys on the pinned paid Q/K observer."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import importlib.util

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def imported(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


parent = imported(ROOT/'key-nibble-cache/measure.py', 'block_parent')
paid = parent.paid
finite = parent.finite


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def rounded(x, step):
    return (x / step).round().clamp(-7, 7)


def block_labels(keys, origin, step, width, blend):
    """A static first nibble predicts a blended block center without extra stored bits."""
    static = rounded(keys - origin, step)
    if width == 1:
        return origin + static * step, static, None
    anchor = origin + static[:, :, ::width, :] * step
    center = origin + blend * (anchor - origin)
    residual = rounded(keys.reshape(*keys.shape[:2], -1, width, keys.shape[-1]) - center.unsqueeze(-2), step)
    result = center.unsqueeze(-2) + residual * step
    result[:, :, :, 0, :] = anchor
    return result.reshape_as(keys), static[:, :, ::width, :], residual


def kl_by_window(q, k, teacher, positions):
    estimate = (q[:, :, positions].double() @ k.double().transpose(-1, -2)) / math.sqrt(128)
    mask = torch.arange(k.shape[2])[None, :] > torch.tensor(positions)[:, None]
    logp = teacher.masked_fill(mask, -1e9).log_softmax(-1)
    loghat = estimate.masked_fill(mask, -1e9).log_softmax(-1)
    return (logp.exp() * (logp - loghat)).sum(-1).mean((1, 2)).tolist()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    prior_path = DATA/f'key-nibble-cache/layer{args.layer:02d}.json'
    prior = json.loads(prior_path.read_text())
    image_path = DATA/f'paid-qk-cache-slack/layer{args.layer:02d}.json'
    image = json.loads(image_path.read_text())
    q_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_q_proj.npz'
    k_path = DATA/f'full-model/image-binary055-refined/layer{args.layer:02d}-self_attn_k_proj.npz'
    with safe_open(finite.MODEL, framework='pt', device='cpu') as model:
        prefix = f'model.layers.{args.layer}.self_attn.'
        original = {n: model.get_tensor(prefix+n+'.weight').float() for n in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    paid_weights = dict(original)
    paid_weights['q_proj'] = paid.helper.binary_weight(q_path).to(torch.bfloat16).float()
    paid_weights['k_proj'] = paid.helper.binary_weight(k_path).to(torch.bfloat16).float()
    gamma = torch.tensor(image['new_group_affine_bf16'], dtype=torch.bfloat16).float()
    captures = [finite.load_capture(args.layer, split).reshape(windows, 256, 1024)
                for split, windows in (('train', 8), ('validation', 4))]
    projected = []
    for x in captures:
        q, k = paid.projected(x, paid_weights, gamma)
        tq, tk = paid.projected(x, original, original['k_norm'])
        projected.append((q, k, tq, tk))
    positions = [list(range(64, 256, 12)), list(range(256))]
    configs = [(1, 0.)] + [(width, blend) for width in (8, 32) for blend in (.125, .25, .5, 1.)]
    names = {config: f'{config[0]}x{config[1]:g}' for config in configs}
    groups = []
    for g, mask in enumerate(image['new_masks']):
        idx = mask + [p + 64 for p in mask]
        arm = prior['groups'][g]['int4']
        choice = prior['group_arms_selected_by_train']['coordinate'][g]
        step = torch.tensor(arm[choice+'_coordinate']['steps'], dtype=torch.float16).float().reshape(1, 1, 1, 32)
        origin = torch.tensor(prior['groups'][g]['train_center'] if choice == 'centered' else [0]*32,
                              dtype=torch.float16).float().reshape(1, 1, 1, 32)
        per_width = {}
        for w, blend in configs:
            splits = []
            for which, (q, k, tq, tk) in enumerate(projected):
                keys = k[:, g:g+1, :, idx]
                query = q[:, 2*g:2*g+2, :, idx]
                center = origin
                decoded, anchors, residual = block_labels(keys, center, step, w, blend)
                # Score each first key as a static nibble; later keys use a block center
                # dot plus one residual nibble dot. FP32 reconstruction is only for replay.
                if w > 1 and which == 1 and g == 0 and blend == 1.:
                    anchor_values = origin + anchors * step
                    direct = (query[:, :, :, None, :].double() * anchor_values[:, :, None, :, :].double()).sum(-1)
                    direct = direct.repeat_interleave(w, dim=-1)
                    dots = (query.double() @ (residual.reshape_as(keys)*step).double().transpose(-1, -2))
                    dots[:, :, :, ::w] = 0
                    discrepancy = (direct + dots - query.double() @ decoded.double().transpose(-1, -2)).abs().max()
                    assert discrepancy < 5e-5, discrepancy
                teacher = parent.scores(tq[:, 2*g:2*g+2], tk[:, g:g+1], positions[which])
                splits.append(kl_by_window(query, decoded, teacher, positions[which]))
            per_width[names[(w, blend)]] = {'train': sum(splits[0])/8, 'held': splits[1]}
        best = min(per_width, key=lambda name: per_width[name]['train'])
        groups.append({'group': g, 'static_choice': choice, 'step_fp16': step.flatten().tolist(),
                       'train_selected': best, 'configs': per_width})
        print('group', g, 'choice', best, 'held', {name: round(sum(entry['held'])/4, 6) for name, entry in per_width.items()}, flush=True)
    aggregate = {}
    for name in names.values():
        aggregate[name] = [sum(g['configs'][name]['held'][window] for g in groups)/8 for window in range(4)]
    aggregate['train_selected'] = [sum(g['configs'][g['train_selected']]['held'][window] for g in groups)/8 for window in range(4)]
    report = {'layer': args.layer, 'description': 'Frozen 128-plane paid binary Q/K, BF16 norm, FP32 RoPE, original-producer train/held; original Q/K teacher, double causal softmax. Static train-selected origin and coordinate FP16 steps from key-nibble-cache; first nibble of each block is the static-code anchor, later nibbles quantize key minus the train-selected blend of static origin and decoded anchor using the same step. No held labels used for fitting.',
              'block_width_blend_configs': [{'width': w, 'blend': blend, 'name': names[(w, blend)]} for w, blend in configs], 'positions_train': positions[0], 'groups': groups,
              'held_by_window': aggregate, 'held_mean': {name: sum(values)/4 for name, values in aggregate.items()},
              'cost': {'payload_bytes_per_key_layer': 128, 'static_origin_and_step_bytes_from_parent': 'unchanged',
                       'anchor_extra_bytes': 0, 'extra_nibble_score_products': 0,
                       'score_program': 'first static nibble dot A is also the anchor score. Later scores are alpha*A plus one residual nibble dot, after discarding common q dot static origin. Exactly 512 nibble products/key/layer for both heads, with one scalar multiply and add per later key/head; no expanded int4 buffer',
                       'online_producer': 'decode first static-nibble key anchor per block, blend toward global static origin, then subtract the 32-real-coordinate center before quantizing later keys; at most 256 real center operations per appended key/layer beyond static quantization, plus first-key block setup',
                       'native_timing_measured': False},
              'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(prior_path), 'image_sha256': sha(image_path),
              'model_sha256': sha(finite.MODEL), 'capture_sha256': sha(finite.value_fit.CAPTURES/f'layer{args.layer:02d}.npz'),
              'paid_q_sha256': sha(q_path), 'paid_k_sha256': sha(k_path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print('held', report['held_mean'], flush=True)


if __name__ == '__main__':
    main()
