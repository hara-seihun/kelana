#!/usr/bin/env python3
"""Fit paid down-factor signs to the composed first-layer endpoint on a damaged producer."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch

from mlp_factor_response import ROOT, PARTS, digest, error, unpack_bf16
from mlp_quantized_scale_fit import CAPTURE

BASE = ROOT / 'mlp-quantized-scale-2048-image'
OUTPUT = ROOT / 'mlp-quantized-down-codes-image'


def image(path):
    with np.load(path) as f:
        payload = {key: f[key].copy() for key in f.files}
    n, k, rank = payload['dimensions'].tolist()
    u = torch.from_numpy(np.unpackbits(payload['U'], axis=1, bitorder='little')[:, :rank].copy()).float() * 2 - 1
    v = torch.from_numpy(np.unpackbits(payload['V'], axis=1, bitorder='little')[:, :k].copy()).float() * 2 - 1
    pre = torch.from_numpy(payload['scale_pre'].astype(np.float32))
    post = torch.from_numpy(payload['scale_post'].astype(np.float32))
    return payload, u, v, pre, post


def fit(args):
    torch.set_num_threads(8)
    source = {str(CAPTURE): digest(CAPTURE)}
    projections = {}
    for part in PARTS:
        path = BASE / f'layer00-mlp_{part}_proj.npz'
        source[str(path)] = digest(path)
        projections[part] = image(path)
    with np.load(CAPTURE) as capture:
        rows = {}
        for split, count in (('train', args.train_rows), ('validation', 1024)):
            x = unpack_bf16(capture[f'{split}_damaged_input'][:count])
            pre = unpack_bf16(capture[f'{split}_damaged_pre'][:count])
            endpoint = unpack_bf16(capture[f'{split}_teacher_post'][:count])
            rows[split] = (x, endpoint - pre)
    features = {}
    for split, (x, _) in rows.items():
        gate = ((x * projections['gate'][3]) @ projections['gate'][2].T) @ projections['gate'][1].T
        up = ((x * projections['up'][3]) @ projections['up'][2].T) @ projections['up'][1].T
        hidden = torch.nn.functional.silu(gate * projections['gate'][4]) * (up * projections['up'][4])
        features[split] = ((hidden * projections['down'][3]) @ projections['down'][2].T)
    payload, u, _, _, post = projections['down']
    initial_u = u.clone()
    target = rows['train'][1]
    z = features['train']
    gram = z.T @ z / len(z)
    cross = target.T @ z / len(z)
    current = u @ gram
    history = []
    for sweep in range(args.sweeps):
        changed = 0
        for r in range(u.shape[1]):
            score = cross[:, r] - post * (current[:, r] - u[:, r] * gram[r, r])
            updated = torch.where(score >= 0, 1., -1.)
            delta = updated - u[:, r]
            changed += int((delta != 0).sum())
            u[:, r] = updated
            current += delta[:, None] * gram[r][None, :]
        # Post scales occupy the same FP16 slots. Refit after each code pass.
        raw = z @ u.T
        post = ((target * raw).sum(0) / raw.square().sum(0).clamp_min(1e-20)).clamp_min(0).half().float()
        scores = {split: error(rows[split][1], (features[split] @ u.T) * post)
                  for split in rows}
        history.append({'sweep': sweep + 1, 'changed_signs': changed, 'scores': scores})
        print(json.dumps(history[-1]), flush=True)
    baseline = {split: error(rows[split][1], (features[split] @ initial_u.T) * projections['down'][4])
                for split in rows}
    payload['U'] = np.packbits((u.numpy() > 0).astype(np.uint8), axis=1, bitorder='little')
    payload['scale_post'] = post.numpy().astype(np.float16)
    output = ROOT / ('mlp-quantized-one-sweep-image' if args.one_sweep else 'mlp-quantized-down-codes-image')
    output.mkdir(exist_ok=True)
    hashes = {}
    for part in PARTS:
        destination = output / f'layer00-mlp_{part}_proj.npz'
        if part != 'down':
            # No change to gate/up image; copy only for a self-contained three-projection image.
            with np.load(BASE / destination.name) as f:
                np.savez_compressed(destination, **{key: f[key] for key in f.files})
        else:
            np.savez_compressed(destination, **payload)
        hashes[str(destination)] = digest(destination)
    receipt = {'format': 'layer0-quantized-down-sign-fit/1', 'source_sha256': digest(Path(__file__)),
               'inputs_sha256': source, 'output_sha256': hashes, 'train_rows': args.train_rows,
               'held_rows': 1024, 'sweeps': args.sweeps, 'baseline': baseline, 'history': history,
               'payload_bytes_before': sum(sum(a.nbytes for a in p[0].values()) for p in projections.values()),
               'payload_bytes_after': sum(sum(a.nbytes for a in (payload if name == 'down' else p[0]).values()) for name, p in projections.items()),
               'observation': 'Actual BF16 layer0 binary Q/K, norms and narrow rank28 V/O producer, original tied embedding. Frozen gate/up codes and paid scales. Down V/pre scales fixed; coordinate-optimal U sign changes and FP16 output scale refits on train endpoint-minus-damaged-residual. Previously inspected held validation capture. FP32 response model, not full BF16 model loss.'}
    path = ROOT / ('mlp-quantized-one-sweep.json' if args.one_sweep else 'mlp-quantized-down-codes.json')
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'baseline': baseline, 'final': history[-1]}), flush=True)


def evaluate(args):
    from transformers import AutoModelForCausalLM
    from image import binary_weight
    from narrow_prefix import IMAGE, VALUE, MODEL, FIXTURE, QUANTIZER, narrow, sha

    torch.backends.cuda.matmul.allow_tf32 = False
    spec = importlib.util.spec_from_file_location('narrow_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    narrow_path = VALUE / 'layer00-joint-r28.npz'
    nv, no, _ = narrow(narrow_path, quantizer.decode)
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    files = {str(manifest_path): sha(manifest_path), str(narrow_path): sha(narrow_path),
             str(MODEL / 'model.safetensors'): sha(MODEL / 'model.safetensors')}
    params = {}
    for entry in manifest['body']:
        if int(entry['key'].split('.')[2]) >= 14:
            continue
        path = IMAGE / entry['path']
        assert sha(path) == entry['sha256']
        files[str(path)] = entry['sha256']
        params[entry['key']] = binary_weight(path)
    norm_path = IMAGE / manifest['norms']['path']
    files[str(norm_path)] = sha(norm_path)
    with np.load(norm_path) as data:
        for name in data.files:
            if name == 'model.norm.weight' or int(name.split('.')[2]) >= 14:
                continue
            params[name] = torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16)
    v_key, o_key = (f'model.layers.0.self_attn.{part}_proj.weight' for part in ('v', 'o'))
    params[v_key], params[o_key] = nv.cpu(), no.cpu()
    variants = ({'scale_fit': {}, 'one_sweep': {}} if args.one_sweep
                else {'binary': {}, 'scale_fit': {}, 'down_codes': {}})
    directories = (('scale_fit', BASE), ('one_sweep', ROOT / 'mlp-quantized-one-sweep-image')) if args.one_sweep else (('scale_fit', BASE), ('down_codes', OUTPUT))
    for arm, directory in directories:
        for part in PARTS:
            path = directory / f'layer00-mlp_{part}_proj.npz'
            files[str(path)] = sha(path)
            variants[arm][f'model.layers.0.mlp.{part}_proj.weight'] = binary_weight(path)
    token_path = FIXTURE / 'tokens.npz'
    fixture_path = FIXTURE / 'manifest.json'
    fixture = json.loads(fixture_path.read_text())
    assert sha(token_path) == fixture['tokens_sha256']
    files[str(token_path)] = sha(token_path)
    with np.load(token_path) as data:
        rows = data[args.split + '_256'][args.start:args.start + args.count].copy()
    assert len(rows) == args.count
    result = {'format': 'layer0-quantized-down-sign-model-loss/1', 'source_sha256': digest(Path(__file__)),
              'inputs_sha256': files, 'split': args.split, 'start': args.start,
              'observation': 'Binary body and norms layers 0..13, shared rank28 V/O at layer0, original tied endpoints and later layers. BF16-expanded equal-payload MLP arms; 255 gold targets per window. Not native inference timing.',
              'windows': []}
    label = 'mlp-quantized-one-sweep' if args.one_sweep else 'mlp-quantized-down-codes'
    out = ROOT / f'{label}-{args.split}-{args.start}-{args.count}.json'
    with torch.inference_mode():
        for index, row in enumerate(rows, args.start):
            ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
            scores = {}
            for arm in variants:
                for name, value in params.items():
                    model.get_parameter(name).copy_(variants[arm].get(name, value).to('cuda'))
                logits = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                scores[arm] = float(-logits.gather(-1, ids[:, 1:, None]).mean())
            result['windows'].append({'index': index, 'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'nll': scores})
            out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result['windows'][-1]), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('fit', 'evaluate'))
    parser.add_argument('--train-rows', type=int, default=2048)
    parser.add_argument('--sweeps', type=int, default=2)
    parser.add_argument('--one-sweep', action='store_true', help='save first-sweep image or compare it with the scale-only control')
    parser.add_argument('--split', choices=('validation', 'test'), default='test')
    parser.add_argument('--start', type=int, default=56)
    parser.add_argument('--count', type=int, default=2)
    args = parser.parse_args()
    if args.mode == 'fit':
        fit(args)
    else:
        evaluate(args)
