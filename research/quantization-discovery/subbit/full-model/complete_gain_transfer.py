#!/usr/bin/env python3
"""Measure whether paid first-layer gains survive the complete compressed model."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from gold_gain_fit import BASE
from image import binary_weight, head_weight
from joint_gain_fit import value_weights
from mlp_factor_response import ROOT, digest
from narrow_prefix import IMAGE, MODEL, QUANTIZER, sha

NARROW = ROOT / 'mlp-vo-joint-value.npz'
DOWN = ROOT / 'mlp-vo-joint-down.npz'
BASE_VO = ROOT.parent / 'value-observer/layer00-joint-r28.npz'
BASE_DOWN = BASE / 'layer00-mlp_down_proj.npz'
# The common gains are selected from train text. The control must keep the same
# pre-gain image and only change its already-paid scale slots.


def load_value(path, decode):
    with np.load(path) as data:
        return value_weights({key: data[key].copy() for key in data.files}, decode)


def stored_bytes(path):
    with np.load(path) as data:
        return sum(data[key].nbytes for key in data.files)


@torch.inference_mode()
def run(args):
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    spec = importlib.util.spec_from_file_location('gain_transfer_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    receipt_path = ROOT / 'mlp-vo-joint-image.json'
    receipt = json.loads(receipt_path.read_text())
    assert sha(NARROW) == receipt['vo_image_sha256']
    assert sha(DOWN) == receipt['down_image_sha256']
    assert sha(BASE_VO) == receipt['vo_input_sha256']
    assert sha(BASE_DOWN) == receipt['down_input_sha256']
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    files = {str(p): sha(p) for p in (manifest_path, receipt_path, NARROW, DOWN, BASE_VO, BASE_DOWN,
                                      MODEL / 'model.safetensors', QUANTIZER)}
    full_body = args.scope in ('complete', 'late-body')
    tied_image = args.scope in ('complete', 'tied-only')
    body_entries = [entry for entry in manifest['body']
                    if full_body or int(entry['key'].split('.')[2]) < 14]
    layer0_replace = [entry for entry in body_entries if entry['key'] in {
        'model.layers.0.self_attn.v_proj.weight', 'model.layers.0.self_attn.o_proj.weight',
        'model.layers.0.mlp.gate_proj.weight', 'model.layers.0.mlp.up_proj.weight',
        'model.layers.0.mlp.down_proj.weight'}]
    payload = 2 * sum(p.numel() for p in model.parameters())
    payload += sum(entry['payload_bytes'] - 2 * entry['parameters'] for entry in body_entries)
    payload -= sum(entry['payload_bytes'] for entry in layer0_replace)
    payload += receipt['vo_payload_bytes'] + sum(
        stored_bytes(BASE / f'layer00-mlp_{part}_proj.npz') for part in ('gate', 'up'))
    payload += receipt['down_payload_bytes']
    for entry in manifest['body']:
        name = entry['key']
        if not full_body and int(name.split('.')[2]) >= 14:
            continue
        path = IMAGE / entry['path']
        assert sha(path) == entry['sha256']
        files[str(path)] = entry['sha256']
        model.get_parameter(name).copy_(binary_weight(path))
    norm_path = IMAGE / manifest['norms']['path']
    assert sha(norm_path) == manifest['norms']['sha256']
    files[str(norm_path)] = sha(norm_path)
    with np.load(norm_path) as data:
        for name in data.files:
            if not full_body and (name == 'model.norm.weight' or int(name.split('.')[2]) >= 14):
                continue
            model.get_parameter(name).copy_(torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16).to('cuda'))
    for part in ('gate', 'up'):
        path = BASE / f'layer00-mlp_{part}_proj.npz'
        files[str(path)] = sha(path)
        model.get_parameter(f'model.layers.0.mlp.{part}_proj.weight').copy_(binary_weight(path))
    if tied_image:
        head_record_path = IMAGE / 'head.json'
        head_record = json.loads(head_record_path.read_text())
        payload += head_record['payload_bytes'] - 2 * head_record['parameters']
        head_path = IMAGE / head_record['path']
        assert sha(head_path) == head_record['sha256']
        files[str(head_path)] = sha(head_path)
        files[str(head_record_path)] = sha(head_record_path)
        head, rare, correction = head_weight(head_path)
        model.model.embed_tokens.weight.copy_(head)
        # Explicitly retain one shared paid head/embedding image.
        assert model.lm_head.weight.data_ptr() == model.model.embed_tokens.weight.data_ptr()
    else:
        rare = correction = None
    v0, o0 = load_value(BASE_VO, quantizer.decode)
    v1, o1 = load_value(NARROW, quantizer.decode)
    assert torch.equal(v0, v1)
    down0 = binary_weight(BASE_DOWN)
    down1 = binary_weight(DOWN)
    v_param = model.get_parameter('model.layers.0.self_attn.v_proj.weight')
    o_param = model.get_parameter('model.layers.0.self_attn.o_proj.weight')
    down_param = model.get_parameter('model.layers.0.mlp.down_proj.weight')
    v_param.copy_(v0)
    arms = {'base': (o0, down0), 'down_gain': (o0, down1), 'joint_gain': (o1, down1)}
    token_path = ROOT.parent / 'fresh-evaluation/tokens.npz'
    files[str(token_path)] = sha(token_path)
    with np.load(token_path) as data:
        rows = data[args.split + '_256'][args.start:args.start + args.count].copy()
    assert len(rows) == args.count
    result = {'format': 'qwen-complete-gain-transfer/1', 'scope': args.scope, 'split': args.split,
              'start': args.start, 'count': args.count, 'source_sha256': digest(Path(__file__)),
              'inputs_sha256': files, 'manifest_payload_bytes': manifest['payload_bytes'],
              'head_tied': tied_image, 'payload_bytes': payload,
              'payload_bpw': 8 * payload / sum(p.numel() for p in model.parameters()),
              'vo_payload_bytes': receipt['vo_payload_bytes'],
              'down_payload_bytes': receipt['down_payload_bytes'], 'online_terms_delta': 0,
              'observation': 'BF16-expanded packed maps. Prefix has layers 0..13 binary/narrow, original later layers and tied endpoints; late-body changes later layers, tied-only changes shared embedding/head, complete changes both. Fixed layer-0 paid down/O gains and identical codes/scale-slot count within each scope; 255 gold labels/window. No native timing.', 'windows': []}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    for index, row in enumerate(rows, args.start):
        ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
        scores = {}
        for arm, (o, down) in arms.items():
            o_param.copy_(o)
            down_param.copy_(down)
            logits = model(ids, use_cache=False).logits[:, :-1].float()
            if rare is not None:
                logits[:, :, rare] = logits[:, :, rare] * float(correction[0]) + float(correction[1])
            scores[arm] = float(-logits.log_softmax(-1).gather(-1, ids[:, 1:, None]).mean())
        result['windows'].append({'index': index, 'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(),
                                  'nll': scores})
        args.out.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result['windows'][-1]), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=('prefix', 'late-body', 'tied-only', 'complete'), required=True)
    parser.add_argument('--split', choices=('test', 'validation'), default='test')
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, default=2)
    parser.add_argument('--out', type=Path, required=True)
    run(parser.parse_args())
