#!/usr/bin/env python3
"""Fit a paid layer-0 V/O output gain after the gold-selected MLP down gain."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from gold_gain_fit import BASE, binary_weight_from_payload
from image import binary_weight
from mlp_factor_response import ROOT, digest
from narrow_prefix import IMAGE, MODEL, QUANTIZER, VALUE, sha

GAINS = (0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25)
CHOICE = ROOT / 'mlp-vo-joint-gain.json'
NARROW = VALUE / 'layer00-joint-r28.npz'
DOWN = BASE / 'layer00-mlp_down_proj.npz'
DOWN_GAIN = ROOT / 'mlp-gold-down-gain.json'


def value_weights(payload, decode):
    v = torch.zeros(1024, 1024, dtype=torch.bfloat16, device='cuda')
    o = torch.zeros(1024, 2048, dtype=torch.bfloat16, device='cuda')
    for group in range(8):
        arrays = {key: payload[key][group].copy() for key in payload}
        rank = int(arrays['right_shape'][0])
        assert rank == 28 and tuple(arrays['right_shape']) == (rank, 1024, 2, 128)
        assert tuple(arrays['left_shape']) == (2048, rank, 2, 128)
        v[group*128:group*128+rank] = decode(arrays, 'right').to('cuda', dtype=torch.bfloat16)
        left = decode(arrays, 'left').to('cuda', dtype=torch.bfloat16)
        for local in range(2):
            o[:, (2*group+local)*128:(2*group+local)*128+rank] = left[local*1024:(local+1)*1024]
    return v, o


@torch.inference_mode()
def run(args):
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    spec = importlib.util.spec_from_file_location('joint_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    files = {str(manifest_path): sha(manifest_path), str(NARROW): sha(NARROW),
             str(DOWN_GAIN): sha(DOWN_GAIN), str(MODEL / 'model.safetensors'): sha(MODEL / 'model.safetensors')}
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
    for part in ('gate', 'up', 'down'):
        path = BASE / f'layer00-mlp_{part}_proj.npz'
        files[str(path)] = sha(path)
        params[f'model.layers.0.mlp.{part}_proj.weight'] = binary_weight(path)
    with np.load(DOWN) as data:
        down = {key: data[key].copy() for key in data.files}
    with np.load(NARROW) as data:
        narrow = {key: data[key].copy() for key in data.files}
    base_scales = narrow['left_scales'].copy()
    gain_down = json.loads(DOWN_GAIN.read_text())['selected_gain']
    assert gain_down == 2.0
    down['scale_post'] = (down['scale_post'].astype(np.float32) * gain_down).astype(np.float16)
    down_gained = binary_weight_from_payload(down)
    v, _ = value_weights(narrow, quantizer.decode)
    params['model.layers.0.self_attn.v_proj.weight'] = v.cpu()
    for name, value in params.items():
        model.get_parameter(name).copy_(value.to('cuda'))
    down_param = model.get_parameter('model.layers.0.mlp.down_proj.weight')
    o_param = model.get_parameter('model.layers.0.self_attn.o_proj.weight')
    token_path = ROOT.parent / ('fixtures/qwen3-0.6b-wikitext/tokens.npz' if args.mode == 'fit' else 'fresh-evaluation/tokens.npz')
    files[str(token_path)] = sha(token_path)
    with np.load(token_path) as data:
        key = 'train' if args.mode == 'fit' else args.split + '_256'
        rows = data[key][args.start:args.start+args.count].copy()
    assert len(rows) == args.count
    gains = GAINS if args.mode == 'fit' else (1.0, json.loads(CHOICE.read_text())['selected_gain'])
    if args.mode != 'fit':
        files[str(CHOICE)] = sha(CHOICE)
    result = {'format': 'layer0-paid-vo-down-joint-gain/1', 'source_sha256': digest(Path(__file__)),
        'inputs_sha256': files, 'mode': args.mode, 'split': 'train' if args.mode == 'fit' else args.split,
        'start': args.start, 'count': args.count, 'down_gain': gain_down, 'vo_gains': gains,
        'observation': 'BF16-expanded binary body/norms layers 0..13, narrow rank28 V/O layer0, original tied endpoints and layers 14..27. Frozen signs, right factors and down gain 2. Existing FP16 left output scales of both O consumers multiplied by one gain. 255 next-token gold labels per window.', 'windows': []}
    out = ROOT / f'mlp-vo-joint-{args.mode}-{result["split"]}-{args.start}-{args.count}.json'
    for index, row in enumerate(rows, args.start):
        ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
        scores = {}
        for gain in gains:
            narrow['left_scales'] = (base_scales.astype(np.float32) * gain).astype(np.float16)
            _, o = value_weights(narrow, quantizer.decode)
            o_param.copy_(o)
            down_param.copy_(down_gained)
            logits = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
            scores[str(gain)] = float(-logits.gather(-1, ids[:, 1:, None]).mean())
        result['windows'].append({'index': index, 'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'nll': scores})
        out.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result['windows'][-1]), flush=True)
    if args.mode == 'fit':
        totals = {str(g): sum(w['nll'][str(g)] for w in result['windows']) / args.count for g in gains}
        selected = min(gains, key=lambda g: totals[str(g)])
        CHOICE.write_text(json.dumps({'format': 'paid-fp16-vo-down-joint-gain/1',
            'source_sha256': result['source_sha256'], 'fit_receipt_sha256': sha(out),
            'input_vo_sha256': sha(NARROW), 'input_down_sha256': sha(DOWN),
            'selected_gain': selected, 'down_gain': gain_down, 'train_nll': totals,
            'vo_stored_bytes': sum(v.nbytes for v in narrow.values()), 'online_terms_delta': 0}, indent=2) + '\n')
        print(json.dumps({'choice': str(CHOICE), 'selected_gain': selected, 'train_nll': totals}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('fit', 'evaluate'))
    parser.add_argument('--split', choices=('validation', 'test'), default='test')
    parser.add_argument('--start', type=int, default=0)
    parser.add_argument('--count', type=int, default=2)
    run(parser.parse_args())
