#!/usr/bin/env python3
"""Select already-paid first-layer scales on the complete quantized model."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from gold_gain_fit import BASE, binary_weight_from_payload
from image import binary_weight, head_weight
from joint_gain_fit import value_weights
from mlp_factor_response import ROOT, digest
from narrow_prefix import IMAGE, MODEL, QUANTIZER, sha

VALUE = ROOT.parent / 'value-observer/layer00-joint-r28.npz'
DOWN = BASE / 'layer00-mlp_down_proj.npz'
GRID = ((1., 1.), (1., 1.5), (1., 2.), (1.5, 1.), (1.5, 1.5),
        (1.5, 2.), (2., 1.), (2., 1.5), (2., 2.))
CHOICE = ROOT / 'complete-paid-gain-choice.json'


def scaled(weights, field, gain):
    result = {key: weights[key].copy() for key in weights}
    result[field] = (weights[field].astype(np.float32) * gain).astype(np.float16)
    return result


def stored_bytes(path):
    with np.load(path) as data:
        return sum(data[key].nbytes for key in data.files)


@torch.inference_mode()
def run(args):
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    spec = importlib.util.spec_from_file_location('complete_paid_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    files = {str(p): sha(p) for p in (manifest_path, VALUE, DOWN, MODEL / 'model.safetensors', QUANTIZER)}
    replaced = {'model.layers.0.self_attn.v_proj.weight', 'model.layers.0.self_attn.o_proj.weight',
                'model.layers.0.mlp.gate_proj.weight', 'model.layers.0.mlp.up_proj.weight',
                'model.layers.0.mlp.down_proj.weight'}
    payload = 2 * sum(p.numel() for p in model.parameters())
    payload += sum(entry['payload_bytes'] - 2 * entry['parameters'] for entry in manifest['body'])
    payload -= sum(entry['payload_bytes'] for entry in manifest['body'] if entry['key'] in replaced)
    payload += stored_bytes(VALUE) + sum(stored_bytes(BASE / f'layer00-mlp_{part}_proj.npz')
                                         for part in ('gate', 'up', 'down'))
    for entry in manifest['body']:
        path = IMAGE / entry['path']
        assert sha(path) == entry['sha256']
        files[str(path)] = entry['sha256']
        model.get_parameter(entry['key']).copy_(binary_weight(path))
    norm_path = IMAGE / manifest['norms']['path']
    assert sha(norm_path) == manifest['norms']['sha256']
    files[str(norm_path)] = sha(norm_path)
    with np.load(norm_path) as data:
        for name in data.files:
            model.get_parameter(name).copy_(torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16).to('cuda'))
    for part in ('gate', 'up'):
        path = BASE / f'layer00-mlp_{part}_proj.npz'
        files[str(path)] = sha(path)
        model.get_parameter(f'model.layers.0.mlp.{part}_proj.weight').copy_(binary_weight(path))
    head_record_path = IMAGE / 'head.json'
    head_record = json.loads(head_record_path.read_text())
    head_path = IMAGE / head_record['path']
    assert sha(head_path) == head_record['sha256']
    files[str(head_path)] = sha(head_path)
    files[str(head_record_path)] = sha(head_record_path)
    payload += head_record['payload_bytes'] - 2 * head_record['parameters']
    head, rare, correction = head_weight(head_path)
    model.model.embed_tokens.weight.copy_(head)
    assert model.lm_head.weight.data_ptr() == model.model.embed_tokens.weight.data_ptr()
    with np.load(VALUE) as data:
        vo = {key: data[key].copy() for key in data.files}
    with np.load(DOWN) as data:
        down = {key: data[key].copy() for key in data.files}
    v, _ = value_weights(vo, quantizer.decode)
    model.get_parameter('model.layers.0.self_attn.v_proj.weight').copy_(v)
    o_param = model.get_parameter('model.layers.0.self_attn.o_proj.weight')
    down_param = model.get_parameter('model.layers.0.mlp.down_proj.weight')
    if args.mode == 'fit':
        gains = GRID
        token_path = ROOT.parent / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
        key = 'train'
    else:
        choice = json.loads(CHOICE.read_text())
        files[str(CHOICE)] = sha(CHOICE)
        gains = tuple(dict.fromkeys(((1., 1.), (2., 1.75), tuple(choice['selected']))))
        token_path = ROOT.parent / 'fresh-evaluation/tokens.npz'
        key = args.split + '_256'
    files[str(token_path)] = sha(token_path)
    with np.load(token_path) as data:
        rows = data[key][args.start:args.start + args.count].copy()
    assert len(rows) == args.count
    prepared = {}
    for dg, og in gains:
        prepared[f'{dg:g},{og:g}'] = (value_weights(scaled(vo, 'left_scales', og), quantizer.decode)[1],
                                   binary_weight_from_payload(scaled(down, 'scale_post', dg)))
    result = {'format': 'complete-paid-gain/1', 'source_sha256': digest(Path(__file__)),
              'inputs_sha256': files, 'mode': args.mode, 'split': key, 'start': args.start,
              'count': args.count, 'gains': list(prepared), 'payload_bytes': payload,
              'payload_bpw': 8 * payload / sum(p.numel() for p in model.parameters()),
              'online_terms_delta': 0, 'windows': []}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    for index, row in enumerate(rows, args.start):
        ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
        scores = {}
        for name, (o, d) in prepared.items():
            o_param.copy_(o)
            down_param.copy_(d)
            logits = model(ids, use_cache=False).logits[:, :-1].float()
            logits[:, :, rare] = logits[:, :, rare] * float(correction[0]) + float(correction[1])
            scores[name] = float(-logits.log_softmax(-1).gather(-1, ids[:, 1:, None]).mean())
        result['windows'].append({'index': index, 'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(),
                                  'nll': scores})
        args.out.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps(result['windows'][-1]), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('fit', 'evaluate'))
    parser.add_argument('--split', choices=('validation', 'test'), default='test')
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, default=2)
    parser.add_argument('--out', type=Path, required=True)
    run(parser.parse_args())
