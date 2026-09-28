#!/usr/bin/env python3
"""Select a paid global down-row gain on train gold loss, then replay frozen images."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from image import binary_weight
from mlp_factor_response import ROOT, digest
from narrow_prefix import IMAGE, VALUE, MODEL, QUANTIZER, narrow, sha

BASE = ROOT / 'mlp-quantized-scale-2048-image'
CHOSEN = ROOT / 'mlp-gold-down-gain.json'
GAINS = (1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5)


@torch.inference_mode()
def run(args):
    torch.set_num_threads(4)
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
    for part, value in zip(('v', 'o'), (nv, no)):
        params[f'model.layers.0.self_attn.{part}_proj.weight'] = value.cpu()
    for part in ('gate', 'up', 'down'):
        path = BASE / f'layer00-mlp_{part}_proj.npz'
        files[str(path)] = sha(path)
        params[f'model.layers.0.mlp.{part}_proj.weight'] = binary_weight(path)
    down_key = 'model.layers.0.mlp.down_proj.weight'
    down_image = BASE / 'layer00-mlp_down_proj.npz'
    with np.load(down_image) as f:
        down_payload = {key: f[key].copy() for key in f.files}
    original_scale = down_payload['scale_post'].copy()
    for name, value in params.items():
        model.get_parameter(name).copy_(value.to('cuda'))
    token_path = ROOT.parent / ('fixtures/qwen3-0.6b-wikitext/tokens.npz' if args.mode == 'fit' else 'fresh-evaluation/tokens.npz')
    files[str(token_path)] = sha(token_path)
    with np.load(token_path) as data:
        key = 'train' if args.mode == 'fit' else args.split + '_256'
        rows = data[key][args.start:args.start + args.count].copy()
    assert len(rows) == args.count
    if args.mode == 'fit':
        gains = GAINS
    else:
        choice = json.loads(CHOSEN.read_text())
        files[str(CHOSEN)] = sha(CHOSEN)
        gains = (1.0, choice['selected_gain'])
    result = {'format': 'layer0-paid-down-gold-gain/1', 'source_sha256': digest(Path(__file__)),
        'inputs_sha256': files, 'mode': args.mode, 'split': 'train' if args.mode == 'fit' else args.split,
        'start': args.start, 'count': args.count, 'gains': gains,
        'observation': 'BF16-expanded binary layers 0..13 and norms; shared rank28 V/O layer0; original tied endpoints and later layers. All down U/V codes, input scales and row scale slots fixed; one common positive gain multiplies existing FP16 down output scales. 255 gold next-token labels per 256-token window. No native timing.', 'windows': []}
    out = ROOT / f'mlp-gold-down-{args.mode}-{args.split if args.mode == "evaluate" else "train"}-{args.start}-{args.count}.json'
    with torch.inference_mode():
        for index, row in enumerate(rows, args.start):
            ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
            scores = {}
            for gain in gains:
                rounded = (original_scale.astype(np.float32) * gain).astype(np.float16)
                down_payload['scale_post'] = rounded
                # The stored FP16 image determines the rounded BF16 execution, not an FP32 proxy.
                down = binary_weight_from_payload(down_payload)
                model.get_parameter(down_key).copy_(down.to('cuda'))
                logits = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                scores[str(gain)] = float(-logits.gather(-1, ids[:, 1:, None]).mean())
            result['windows'].append({'index': index, 'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'nll': scores})
            out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result['windows'][-1]), flush=True)
    if args.mode == 'fit':
        totals = {str(g): sum(w['nll'][str(g)] for w in result['windows']) / args.count for g in GAINS}
        selected = min(GAINS, key=lambda g: totals[str(g)])
        CHOSEN.write_text(json.dumps({'format': 'paid-fp16-global-down-gain/1', 'source_sha256': result['source_sha256'],
            'fit_receipt_sha256': sha(out), 'input_down_sha256': sha(down_image),
            'selected_gain': selected, 'train_nll': totals, 'stored_bytes': sum(v.nbytes for v in down_payload.values()),
            'online_terms_delta': 0}, indent=2) + '\n')
        print(json.dumps({'choice': str(CHOSEN), 'selected_gain': selected, 'train_nll': totals}), flush=True)


def binary_weight_from_payload(payload):
    # Read the same factor decoder as image.binary_weight, without writing a temporary NPZ.
    n, k, rank = payload['dimensions'].tolist()
    u = np.unpackbits(payload['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32) * 2 - 1
    v = np.unpackbits(payload['V'], axis=1, bitorder='little')[:, :k].astype(np.float32) * 2 - 1
    u *= payload['scale_post'].astype(np.float32)[:, None]
    v *= payload['scale_pre'].astype(np.float32)[None, :]
    return torch.from_numpy(u).to('cuda') @ torch.from_numpy(v).to('cuda')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode', choices=('fit', 'evaluate'))
    p.add_argument('--split', choices=('validation', 'test'), default='test')
    p.add_argument('--start', type=int, default=0)
    p.add_argument('--count', type=int, default=2)
    run(p.parse_args())
