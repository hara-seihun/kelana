#!/usr/bin/env python3
"""Check selected-key RMS affine against the frozen group-indexed map."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
DATA = Path('/path/to/workspace/data/kelana-subbit')


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    group_path = DATA / f'rope-group-affine/layer{args.layer:02d}.json'
    gain_path = DATA / f'rope-causal-gain/layer{args.layer:02d}.json'
    group = json.loads(group_path.read_text())
    gains = json.loads(gain_path.read_text())
    finite = load_module('finite_selected', HERE.parent / 'rope-finite-kl/fit.py')
    model_path = finite.MODEL
    with safe_open(model_path, framework='pt', device='cpu') as model:
        weight = model.get_tensor(f'model.layers.{args.layer}.self_attn.k_proj.weight').float()
        shared_gamma = model.get_tensor(f'model.layers.{args.layer}.self_attn.k_norm.weight').to(torch.bfloat16)
    masks = gains['masks']
    gamma = torch.tensor(group['group_affine_bf16'], dtype=torch.bfloat16)
    selected_indices = [list(m) + [p + 64 for p in m] for m in masks]
    packed_gamma = torch.cat([gamma[g, indices] for g, indices in enumerate(selected_indices)])
    offsets = [0]
    for indices in selected_indices:
        offsets.append(offsets[-1] + len(indices))
    union = sorted(set().union(*map(set, selected_indices)))
    x = finite.load_capture(args.layer, 'validation').reshape(4, 256, 1024)
    raw = (x @ weight.T).to(torch.bfloat16).reshape(4, 256, 8, 128)
    # The BF16 numerator and full-width FP32 denominator are identical in both arms.
    normalized = (raw.float() * torch.rsqrt(raw.float().square().mean(-1, keepdim=True) + 1e-6)).to(torch.bfloat16)
    dense = (normalized * gamma).float()
    selected = []
    per_group_difference = []
    for g, indices in enumerate(selected_indices):
        out = (normalized[:, :, g, indices] * packed_gamma[offsets[g]:offsets[g+1]]).float()
        reference = dense[:, :, g, indices]
        per_group_difference.append(int((out.view(torch.int32) != reference.view(torch.int32)).sum()))
        selected.append(out)
    # A whole selected RoPE plane never reads a coordinate from another plane.
    # Check its two rotated coordinates on all validation positions too.
    phase = torch.outer(torch.arange(256).float(), 1 / (1_000_000. ** (torch.arange(64).float() * 2 / 128)))
    cosine = phase.cos().to(torch.bfloat16).float()
    sine = phase.sin().to(torch.bfloat16).float()
    rotary_differences = []
    for g, planes in enumerate(masks):
        n = len(planes)
        compact = selected[g]
        real = dense[:, :, g]
        c, s = cosine[:, planes], sine[:, planes]
        first = compact[..., :n] * c - compact[..., n:] * s
        second = compact[..., n:] * c + compact[..., :n] * s
        ref_first = real[..., planes] * c - real[..., [p + 64 for p in planes]] * s
        ref_second = real[..., [p + 64 for p in planes]] * c + real[..., planes] * s
        rotary_differences.append(int((first.view(torch.int32) != ref_first.view(torch.int32)).sum() +
                                      (second.view(torch.int32) != ref_second.view(torch.int32)).sum()))
    assert max(per_group_difference + rotary_differences) == 0
    assert all(len(m) <= 16 for m in masks)
    result = {
        'layer': args.layer,
        'selected_planes_per_group': [len(m) for m in masks],
        'selected_coordinates': offsets[-1],
        'selected_gamma_bf16': packed_gamma.float().tolist(),
        'selected_gamma_bytes': packed_gamma.numel() * 2,
        'shared_selected_gamma_bytes': len(union) * 2,
        'dense_group_gamma_bytes': gamma.numel() * 2,
        'dense_shared_gamma_bytes': shared_gamma.numel() * 2,
        'selected_input_bf16_differences_by_group': per_group_difference,
        'selected_rotated_fp32_differences_by_group': rotary_differences,
        'checked_positions': [4, 256],
        'held_kl_by_window_inherited_exactly': group['kl_by_window']['group_bf16_affine'],
        'source_sha256': sha(Path(__file__)), 'model_sha256': sha(model_path),
        'capture_sha256': gains['capture_sha256'],
        'group_receipt_sha256': sha(group_path), 'gain_receipt_sha256': sha(gain_path),
        'observation': 'original producer; selected plane coordinates after BF16 RMSNorm and FP32 RoPE. Full 128-coordinate raw K denominator retained. All four existing validation windows, every token; KL identity follows from equal selected rotated bits and unchanged query/score schedule.'
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('layer', 'selected_gamma_bytes', 'shared_selected_gamma_bytes', 'selected_input_bf16_differences_by_group', 'selected_rotated_fp32_differences_by_group')}, indent=2))


if __name__ == '__main__':
    main()
