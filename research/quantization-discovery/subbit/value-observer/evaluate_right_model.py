#!/usr/bin/env python3
"""Fresh gold loss with frozen layer-14 narrow values and quantized upstream layers."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from evaluate_fresh import pruned_weights
from evaluate_model import ROOT, MODEL, JOINT, QUANTIZER, sha, scores

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'full-model'))
from image import binary_weight

UPSTREAM = ROOT / 'full-model/image-binary055-refined'
FIXTURE = ROOT / 'fresh-evaluation'
IMAGES = {
    'old_selected': JOINT / 'layer14-quantized-upstream-selected192.npz',
    'old_uniform': JOINT / 'layer14-quantized-upstream-uniform192.npz',
    'new_selected': JOINT / 'layer14-quantized-upstream-right-selected192.npz',
    'new_uniform': JOINT / 'layer14-quantized-upstream-right-uniform192.npz',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--split', choices=('validation', 'test'), default='test')
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, default=1)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    fixture_path = FIXTURE / 'manifest.json'
    token_path = FIXTURE / 'tokens.npz'
    fixture = json.loads(fixture_path.read_text())
    assert sha(token_path) == fixture['tokens_sha256']
    key = f'{args.split}_256'
    with np.load(token_path) as data:
        rows = data[key][args.start:args.start + args.count].copy()
        assert len(rows) == args.count and args.start >= 0
    upstream_manifest_path = UPSTREAM / 'manifest.json'
    upstream_manifest = json.loads(upstream_manifest_path.read_text())
    spec = importlib.util.spec_from_file_location('narrow_quantizer', QUANTIZER)
    quantizer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(quantizer)
    transfer = json.loads((JOINT / 'layer14-quantized-upstream-transfer.json').read_text())
    for arm, path in IMAGES.items():
        if arm.startswith('old_'):
            expected = transfer['images_sha256'][arm.removeprefix('old_') + '192_producer_refit']
        else:
            expected = json.loads(path.with_suffix('.json').read_text())['output_image_sha256']
        assert sha(path) == expected, arm
    weights = {arm: pruned_weights(path, quantizer.decode) for arm, path in IMAGES.items()}
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
        dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    applied = {}
    with torch.no_grad():
        for entry in upstream_manifest['body']:
            if int(entry['key'].split('.')[2]) >= 14:
                continue
            path = UPSTREAM / entry['path']
            assert sha(path) == entry['sha256']
            model.get_parameter(entry['key']).copy_(binary_weight(path))
            applied[entry['key']] = entry['sha256']
        norms = upstream_manifest['norms']
        path = UPSTREAM / norms['path']
        assert sha(path) == norms['sha256']
        with np.load(path) as data:
            for name in data.files:
                if name == 'model.norm.weight' or int(name.split('.')[2]) >= 14:
                    continue
                bits = torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16)
                model.get_parameter(name).copy_(bits)
    pv = model.get_parameter('model.layers.14.self_attn.v_proj.weight')
    po = model.get_parameter('model.layers.14.self_attn.o_proj.weight')
    original = (pv.detach().clone(), po.detach().clone())
    arms = {'original_vo': (*original, 2 * (pv.numel() + po.numel())), **weights}
    result = {'format': 'qwen-quantized-upstream-narrow-value-fresh-loss/1',
              'observation': 'layers 0..13 quantized body and norms; original tied embedding, layer14 Q/K, later layers and head; only layer14 V/O differs; BF16-expanded paid images, not native timing',
              'split': args.split, 'start': args.start, 'count': args.count,
              'fixture_sha256': sha(fixture_path), 'tokens_sha256': sha(token_path),
              'model_sha256': sha(MODEL / 'model.safetensors'),
              'upstream_manifest_sha256': sha(upstream_manifest_path), 'upstream_norms_sha256': norms['sha256'],
              'upstream_body_sha256': applied,
              'source_sha256': {p.name: sha(p) for p in (Path(__file__), QUANTIZER, Path(__file__).with_name('evaluate_fresh.py'))},
              'images_sha256': {arm: sha(path) for arm, path in IMAGES.items()},
              'torch': torch.__version__, 'hip': torch.version.hip, 'device': torch.cuda.get_device_name(),
              'windows': []}
    with torch.inference_mode():
        for index, row in enumerate(rows, args.start):
            ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
            target = ids[:, 1:]
            teacher = None
            record = {'index': index, 'token_start': fixture['windows'][key]['starts'][index],
                      'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(), 'arms': {}}
            for arm, (v, o, paid) in arms.items():
                pv.copy_(v)
                po.copy_(o)
                logp = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                if teacher is None:
                    teacher = logp
                record['arms'][arm] = {**scores(logp, teacher, target)[0], 'v_o_payload_bytes': paid}
                del logp
            result['windows'].append(record)
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps({'window': index, 'nll': {arm: round(m['nll'], 6) for arm, m in record['arms'].items()}}), flush=True)


if __name__ == '__main__':
    main()
