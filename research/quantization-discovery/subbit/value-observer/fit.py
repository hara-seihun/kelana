#!/usr/bin/env python3
"""Factor each GQA value group through the shared output-side binary O basis."""
import argparse
import hashlib
import importlib.util
import json
import time
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-0.6b/model.safetensors'
SOURCE = Path(__file__).resolve().parents[1] / 'binary-factors/nanoquant_admm.py'
INDEPENDENT = ROOT / 'full-model/image-binary055-refined'
CAPTURES = ROOT / 'full-model/capture'
OUTPUT = ROOT / 'value-observer'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def unpack(packed, columns):
    return torch.from_numpy(np.unpackbits(packed, axis=1, bitorder='little')[:, :columns].copy().astype(np.float32)) * 2 - 1


def load_capture(layer, split):
    with np.load(CAPTURES / f'layer{layer:02d}.npz') as data:
        bits = data[f'{split}_qkv'].copy()
    return torch.from_numpy(bits.view(np.int16)).view(torch.bfloat16).float()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--layer', type=int, choices=(0, 14), required=True)
    p.add_argument('--rank', type=int, default=76)
    p.add_argument('--groups', type=int, nargs='+', default=list(range(8)))
    p.add_argument('--iterations', type=int, default=400)
    p.add_argument('--threads', type=int, default=8)
    args = p.parse_args()
    torch.set_num_threads(args.threads)
    torch.manual_seed(0)
    target = OUTPUT / f'layer{args.layer:02d}-r{args.rank}'
    target.mkdir(parents=True, exist_ok=True)
    with safe_open(MODEL, framework='pt', device='cpu') as source:
        wv = source.get_tensor(f'model.layers.{args.layer}.self_attn.v_proj.weight').float()
        wo = source.get_tensor(f'model.layers.{args.layer}.self_attn.o_proj.weight').float()
    o_image = INDEPENDENT / f'layer{args.layer:02d}-self_attn_o_proj.npz'
    with np.load(o_image) as img:
        on, ok, orank = [int(v) for v in img['dimensions']]
        left = unpack(img['U'], orank)
        post = torch.from_numpy(img['scale_post'].copy()).float()
    output_basis = left * post[:, None]
    gram = output_basis.T @ output_basis
    # This is a projection onto the paid O output basis, not a learned free decoder.
    pinv = torch.linalg.solve(gram + torch.eye(orank) * 1e-5, output_basis.T)
    xtrain = load_capture(args.layer, 'train')
    xval = load_capture(args.layer, 'validation')
    i_norm = .6 * xtrain.square().mean(0) + .4 * xtrain.square().mean()
    spec = importlib.util.spec_from_file_location('pinned_nanoquant', SOURCE)
    method = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(method)
    for group in args.groups:
        if group not in range(8):
            raise ValueError('group must be 0..7')
        heads = (2*group, 2*group+1)
        group_value = wv[group*128:(group+1)*128]
        output_pair = torch.cat([wo[:, h*128:(h+1)*128] for h in heads], dim=0)
        projected_pair = torch.cat([(pinv @ wo[:, h*128:(h+1)*128]) @ group_value
                                    for h in heads], dim=0)
        teacher_pair = output_pair @ group_value
        projected_map = torch.cat([output_basis @ projected_pair[h*orank:(h+1)*orank]
                                   for h in range(2)], dim=0)
        projection_floor = {}
        for split, x in (('train', xtrain), ('validation', xval)):
            reference = x @ teacher_pair.T
            projection_floor[split] = ((x @ projected_map.T - reference).square().sum() /
                                       reference.square().sum()).item()
        torch.manual_seed(group)
        start = time.monotonic()
        result = method.factorize_admm_nanoquant(projected_pair, i_norm,
                                                  gram.diagonal().repeat(2), args.rank,
                                                  outer_iters=args.iterations, inner_iters=5,
                                                  rho_scheduler='linear', is_transpose=True)
        elapsed = time.monotonic() - start
        c = result['A'].T.sign()
        b = result['B'].sign()
        c[c == 0] = 1
        b[b == 0] = 1
        c_packed = np.packbits((c.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
        b_packed = np.packbits((b.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
        pre = result['scale_pre'].flatten().half().float()
        mid_post = result['scale_post'].flatten().half().float()
        c_dec, b_dec = unpack(c_packed, args.rank), unpack(b_packed, xtrain.shape[1])
        candidate = (c_dec * mid_post[:, None]) @ (b_dec * pre[None, :])
        approximation = torch.cat([output_basis @ candidate[h*orank:(h+1)*orank]
                                   for h in range(2)], dim=0)
        error = {}
        for split, x in (('train', xtrain), ('validation', xval)):
            reference = x @ teacher_pair.T
            error[split] = ((x @ approximation.T - reference).square().sum() /
                            reference.square().sum()).item()
        image = target / f'group{group}.npz'
        np.savez(image, C=c_packed, B=b_packed, pre=pre.numpy().astype(np.float16),
                 mid_post=mid_post.numpy().astype(np.float16),
                 dimensions=np.array([2*orank, xtrain.shape[1], args.rank, group], dtype=np.int32))
        payload = c_packed.nbytes + b_packed.nbytes + 2 * (2*orank + xtrain.shape[1]) + 16
        report = {'layer': args.layer, 'group': group, 'heads': list(heads), 'rank': args.rank,
                  'output_basis_image': str(o_image), 'output_basis_sha256': sha(o_image),
                  'source_model_revision': json.loads((MODEL.parent / 'source.json').read_text())['revision'],
                  'capture_sha256': sha(CAPTURES / f'layer{args.layer:02d}.npz'),
                  'upstream_admm_sha256': sha(SOURCE), 'outer_iters': args.iterations,
                  'input_tokens_train': len(xtrain), 'input_tokens_validation': len(xval),
                  'full_rank_fixed_output_basis_error': projection_floor,
                  'joint_factor_response_error': error,
                  'solver_seconds_cpu': elapsed, 'factor_payload_bytes_including_descriptor': payload,
                  'image': str(image), 'image_sha256': sha(image),
                  'serialized_bytes': image.stat().st_size}
        (target / f'group{group}.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
