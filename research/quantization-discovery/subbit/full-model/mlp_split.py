#!/usr/bin/env python3
"""Price frozen layer-0 MLP projections with a narrow V/O under a damaged prefix."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from image import binary_weight
from narrow_prefix import IMAGE, VALUE, MODEL, FIXTURE, QUANTIZER, narrow, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--split', choices=('test', 'validation'), required=True)
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, default=2)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    fixture_path = FIXTURE / 'manifest.json'
    fixture = json.loads(fixture_path.read_text())
    token_path = FIXTURE / 'tokens.npz'
    assert sha(token_path) == fixture['tokens_sha256']
    key = args.split + '_256'
    with np.load(token_path) as data:
        assert args.start >= 0 and args.count > 0 and args.start + args.count <= len(data[key])
        rows = data[key][args.start:args.start + args.count].copy()
    spec = importlib.util.spec_from_file_location('value_observer_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    narrow_path = VALUE / 'layer00-joint-r28.npz'
    narrow_v, narrow_o, narrow_bytes = narrow(narrow_path, quantizer.decode)
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    params = {}
    paid = {}
    with torch.no_grad():
        for entry in manifest['body']:
            layer = int(entry['key'].split('.')[2])
            if layer >= 14:
                continue
            path = IMAGE / entry['path']
            assert sha(path) == entry['sha256']
            p = model.get_parameter(entry['key'])
            params[entry['key']] = (layer, p, p.detach().clone(), binary_weight(path))
            if layer == 0:
                paid[entry['key']] = 2 * p.numel() - entry['payload_bytes']
        norm_path = IMAGE / manifest['norms']['path']
        assert sha(norm_path) == manifest['norms']['sha256']
        with np.load(norm_path) as data:
            for name in data.files:
                if name == 'model.norm.weight' or int(name.split('.')[2]) >= 14:
                    continue
                p = model.get_parameter(name)
                quant = torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16).to('cuda')
                params[name] = (int(name.split('.')[2]), p, p.detach().clone(), quant)
    v_key, o_key = (f'model.layers.0.self_attn.{part}_proj.weight' for part in ('v', 'o'))
    mlp = {part: f'model.layers.0.mlp.{part}_proj.weight' for part in ('gate', 'up', 'down')}
    arms = {'narrow': (), 'gate': ('gate',), 'up': ('up',), 'down': ('down',),
            'gate_up': ('gate', 'up'), 'gate_down': ('gate', 'down'),
            'up_down': ('up', 'down'), 'all': ('gate', 'up', 'down')}
    result = {'format': 'qwen-layer0-mlp-split/1', 'split': args.split, 'start': args.start,
        'count': args.count, 'fixture_sha256': sha(fixture_path), 'tokens_sha256': sha(token_path),
        'model_sha256': sha(MODEL / 'model.safetensors'), 'manifest_sha256': sha(manifest_path),
        'norms_sha256': sha(norm_path),
        'source_sha256': {p.name: sha(p) for p in (Path(__file__), Path(__file__).with_name('narrow_prefix.py'), QUANTIZER)},
        'narrow_image_sha256': sha(narrow_path), 'narrow_image_bytes': narrow_bytes,
        'additional_bytes_vs_narrow': {arm: sum(paid[mlp[part]] for part in parts) for arm, parts in arms.items()},
        'observation': 'Frozen BF16-expanded rank-28 layer-0 V/O; binary layers 0..13, original tied endpoints and layers 14..27; BF16 MLP module substitutions; 255 gold targets/window; no native timing',
        'torch': torch.__version__, 'hip': torch.version.hip,
        'device': torch.cuda.get_device_name(), 'windows': []}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with torch.inference_mode():
        for index, row in enumerate(rows, args.start):
            ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
            record = {'index': index, 'token_start': fixture['windows'][key]['starts'][index],
                      'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'arms': {}}
            for arm, parts in arms.items():
                restored = {mlp[part] for part in parts}
                for name, (_, p, original, quant) in params.items():
                    p.copy_(original if name in restored else quant)
                model.get_parameter(v_key).copy_(narrow_v)
                model.get_parameter(o_key).copy_(narrow_o)
                logp = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                record['arms'][arm] = -logp.gather(-1, ids[:, 1:, None]).sum().item() / (len(row)-1)
            result['windows'].append(record)
            args.out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps({'index': index, 'nll': {arm: round(value, 5) for arm, value in record['arms'].items()}}), flush=True)


if __name__ == '__main__':
    main()
