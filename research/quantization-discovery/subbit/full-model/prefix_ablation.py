#!/usr/bin/env python3
"""Fresh causal prefix and leave-group-out loss for the refined binary body."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from image import binary_weight

ROOT = Path('/path/to/workspace/data/kelana-subbit')
IMAGE = ROOT / 'full-model/image-binary055-refined'
MODEL = ROOT / 'models/qwen3-0.6b'
FIXTURE = ROOT / 'fresh-evaluation'


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--split', choices=('test', 'validation'), default='test')
    parser.add_argument('--start', type=int, required=True)
    parser.add_argument('--count', type=int, default=1)
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
        rows = data[key][args.start:args.start + args.count].copy()
    assert args.start >= 0 and len(rows) == args.count
    manifest_path = IMAGE / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
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
            params[entry['key']] = (layer, p, p.detach().clone(), binary_weight(path), entry['payload_bytes'])
        norms = manifest['norms']
        norm_path = IMAGE / norms['path']
        assert sha(norm_path) == norms['sha256']
        with np.load(norm_path) as data:
            for name in data.files:
                if name == 'model.norm.weight' or int(name.split('.')[2]) >= 14:
                    continue
                p = model.get_parameter(name)
                quant = torch.from_numpy(data[name].view(np.int16).copy()).view(torch.bfloat16).to('cuda')
                params[name] = (int(name.split('.')[2]), p, p.detach().clone(), quant, 2 * p.numel())
    groups = ((0, 2), (2, 4), (4, 8), (8, 14))
    arms = [('original', set(), set())] + [(f'prefix_{n}', set(range(n)), set()) for n in (1, 2, 4, 8, 14)]
    arms += [(f'restore_{lo}_{hi}', set(range(14)) - set(range(lo, hi)), set()) for lo, hi in groups]
    arms += [(f'restore_{lo}_{lo + 1}', set(range(14)) - {lo}, set()) for lo in (0, 1)]
    layer0 = [name for name, (layer, *_) in params.items() if layer == 0]
    for part, selected in (
        ('qk', ('q_proj', 'k_proj')),
        ('vo', ('v_proj', 'o_proj')),
        ('attention', ('self_attn.',)),
        ('mlp', ('.mlp.',)),
    ):
        excluded = {name for name in layer0 if any(label in name for label in selected)}
        arms.append((f'restore_0_{part}', set(range(14)), excluded))
    result =  {'format': 'qwen-binary-prefix-ablation/1', 'split': args.split,
        'start': args.start, 'count': args.count, 'model_sha256': sha(MODEL / 'model.safetensors'),
        'fixture_sha256': sha(fixture_path), 'tokens_sha256': sha(token_path),
        'image_manifest_sha256': sha(manifest_path), 'norms_sha256': sha(norm_path),
        'source_sha256': sha(__file__), 'torch': torch.__version__, 'hip': torch.version.hip,
        'device': torch.cuda.get_device_name(), 'observation': 'BF16-expanded refined binary body and paid norms in specified layers 0..13; original tied embedding/head and later layers; teacher-forced gold NLL; not compressed inference',
        'arms': {name: {'quantized_layers': sorted(layers), 'original_parameter_keys': sorted(excluded),
                        'windows': []} for name, layers, excluded in arms}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with torch.inference_mode():
        for name, layers, excluded in arms:
            for param_name, (layer, p, original, quant, _) in params.items():
                p.copy_(quant if layer in layers and param_name not in excluded else original)
            for index, row in enumerate(rows, args.start):
                ids = torch.as_tensor(row.astype(np.int64), device='cuda')[None]
                logp = model(ids, use_cache=False).logits[:, :-1].float().log_softmax(-1)
                nll = -logp.gather(-1, ids[:, 1:, None]).sum().item() / (len(row) - 1)
                result['arms'][name]['windows'].append({'index': index,
                    'token_start': fixture['windows'][key]['starts'][index],
                    'token_sha256': hashlib.sha256(row.tobytes()).hexdigest(),
                    'predictions': len(row) - 1, 'nll': nll})
            args.out.write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps({'arm': name, 'nll': [round(x['nll'], 5) for x in result['arms'][name]['windows']]}), flush=True)


if __name__ == '__main__':
    main()
