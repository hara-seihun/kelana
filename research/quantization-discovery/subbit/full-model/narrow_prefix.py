#!/usr/bin/env python3
"""Test frozen paid layer-0 narrow V/O inside the refined binary prefix."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from image import binary_weight

ROOT = Path('/path/to/workspace/data/kelana-subbit')
IMAGE = ROOT / 'full-model/image-binary055-refined'
VALUE = ROOT / 'value-observer'
MODEL = ROOT / 'models/qwen3-0.6b'
FIXTURE = ROOT / 'fresh-evaluation'
QUANTIZER = Path(__file__).resolve().parents[1] / 'spectral_quant.py'


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def narrow(path, decode):
    with np.load(path) as image:
        paid = sum(image[key].nbytes for key in image.files)
        v = torch.zeros(1024, 1024, dtype=torch.bfloat16, device='cuda')
        o = torch.zeros(1024, 2048, dtype=torch.bfloat16, device='cuda')
        if 'left_shape' in image and image['left_shape'].ndim == 2:
            groups = ({key: image[key][g].copy() for key in image.files} for g in range(8))
        else:
            groups = ({key: image[f'group{g}_{key}'].copy() for key in
                       ('left_shape', 'left_codes', 'left_scales', 'right_shape', 'right_codes', 'right_scales')}
                      for g in range(8))
        for g, arrays in enumerate(groups):
            rank = int(arrays['right_shape'][0])
            assert tuple(arrays['right_shape']) == (rank, 1024, 2, 128)
            assert tuple(arrays['left_shape']) == (2048, rank, 2, 128)
            v[g*128:g*128+rank] = decode(arrays, 'right').to('cuda', dtype=torch.bfloat16)
            left = decode(arrays, 'left').to('cuda', dtype=torch.bfloat16)
            for h in range(2):
                o[:, (2*g+h)*128:(2*g+h)*128+rank] = left[h*1024:(h+1)*1024]
    return v, o, paid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--split', choices=('test', 'validation'), default='test')
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, default=1)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    token_path = FIXTURE / 'tokens.npz'
    fixture_path = FIXTURE / 'manifest.json'
    fixture = json.loads(fixture_path.read_text())
    assert sha(token_path) == fixture['tokens_sha256']
    key = args.split + '_256'
    with np.load(token_path) as data:
        assert 0 <= args.start and args.count > 0 and args.start + args.count <= len(data[key])
        rows = data[key][args.start:args.start+args.count].copy()
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    spec = importlib.util.spec_from_file_location('value_observer_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    narrow_paths = {
        'narrow28': VALUE / 'layer00-joint-r28.npz',
        'narrow192': VALUE / 'layer00-causal-refit-train_causal_optimum.npz',
        'uniform192': VALUE / 'layer00-causal-refit-uniform_24.npz',
    }
    images = {name: narrow(path, quantizer.decode) for name, path in narrow_paths.items()}
    assert [images[k][2] for k in images] == [208640, 183552, 183552]
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    params = {}
    with torch.no_grad():
        for entry in manifest['body']:
            layer = int(entry['key'].split('.')[2])
            if layer >= 14:
                continue
            path = IMAGE / entry['path']
            assert sha(path) == entry['sha256']
            p = model.get_parameter(entry['key'])
            params[entry['key']] = (layer, p, p.detach().clone(), binary_weight(path))
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
    original_bytes = 2 * sum(p.numel() for p in model.parameters())
    binary_bytes = sum(entry['payload_bytes'] for entry in manifest['body'] if int(entry['key'].split('.')[2]) < 14)
    result = {'format': 'qwen-layer0-narrow-binary-prefix/1', 'split': args.split, 'start': args.start,
        'count': args.count, 'fixture_sha256': sha(fixture_path), 'tokens_sha256': sha(token_path),
        'model_sha256': sha(MODEL / 'model.safetensors'), 'manifest_sha256': sha(manifest_path),
        'norms_sha256': sha(norm_path), 'source_sha256': {p.name: sha(p) for p in
            (Path(__file__), QUANTIZER)}, 'images': {name: {'path': str(path), 'sha256': sha(path),
            'payload_bytes': images[name][2]} for name, path in narrow_paths.items()},
        'observation': 'quantized layers 0..13, original tied embedding/head and later layers; frozen BF16-expanded layer-0 narrow V/O substituted inside quantized prefix; 255 gold targets/window; no compressed inference timing',
        'torch': torch.__version__, 'hip': torch.version.hip,
        'device': torch.cuda.get_device_name(), 'original_unique_bytes': original_bytes,
        'binary_prefix_body_bytes': binary_bytes, 'windows': []}
    arms = ('binary_prefix', 'narrow28', 'narrow192', 'uniform192', 'original_vo', 'original_layer0')
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with torch.inference_mode():
        for index, row in enumerate(rows, args.start):
            ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
            record = {'index': index, 'token_start': fixture['windows'][key]['starts'][index],
                      'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'arms': {}}
            for arm in arms:
                for name, (layer, p, original, quant) in params.items():
                    chosen = original if (arm == 'original_layer0' and layer == 0) or (
                        arm == 'original_vo' and name in (v_key, o_key)) else quant
                    p.copy_(chosen)
                if arm in images:
                    model.get_parameter(v_key).copy_(images[arm][0])
                    model.get_parameter(o_key).copy_(images[arm][1])
                logp = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                nll = -logp.gather(-1, ids[:, 1:, None]).sum().item() / (len(row)-1)
                record['arms'][arm] = {'nll': nll, 'predictions': len(row)-1}
            result['windows'].append(record)
            args.out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps({'index': index, 'nll': {arm: round(record['arms'][arm]['nll'], 5)
                             for arm in arms}}), flush=True)


if __name__ == '__main__':
    main()
