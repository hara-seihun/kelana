#!/usr/bin/env python3
"""Capture real complete-model producers and score packed gate/up substitutions."""
import argparse
import json
from pathlib import Path
import sys
import time

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'ternary'))
from pilot import MODEL, ROOT, expanded, load_model, sha

DATA = ROOT.parent / 'vector-full'
SOURCE = ROOT / 'expanded-scale384'
FIXTURE = ROOT / 'expanded-tokens.npz'


def atomic_json(path, value):
    if path.exists():
        raise FileExistsError(path)
    temp = path.with_suffix(path.suffix + '.partial')
    temp.write_text(json.dumps(value, indent=2) + '\n')
    temp.rename(path)


def installed(source):
    manifest = json.loads((source / 'manifest.json').read_text())
    if not manifest['complete'] or len(manifest['matrices']) != 197:
        raise ValueError('complete 197-matrix source required')
    if manifest['model_source_sha256'] != sha(MODEL / 'source.json'):
        raise ValueError('source checkpoint changed')
    model = load_model()
    with torch.inference_mode():
        for entry in manifest['matrices']:
            path = source / (entry['key'].replace('.', '_') + '.npz')
            if sha(path) != entry['sha256']:
                raise ValueError(f'image changed: {path}')
            model.get_parameter(entry['key']).copy_(expanded(path))
    if model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr():
        raise ValueError('tied head detached')
    return model, manifest


def token_rows(split, offset, windows):
    with np.load(FIXTURE) as f:
        rows = f[split][offset:offset + windows].copy()
    if offset < 0 or windows < 1 or rows.shape != (windows, 256):
        raise ValueError('token panel incomplete')
    return rows


@torch.inference_mode()
def capture(args):
    destination = DATA / 'capture'
    destination.mkdir(parents=True, exist_ok=True)
    stem = f'{args.producer}-{args.split}-{args.offset}-{args.windows}'
    path = destination / (stem + '.npz')
    receipt = path.with_suffix('.json')
    if path.exists() or receipt.exists():
        raise FileExistsError(path)
    start = time.monotonic()
    if args.producer == 'ternary':
        model, manifest = installed(SOURCE)
    else:
        model, manifest = load_model(), None
    rows = token_rows(args.split, args.offset, args.windows)
    captures = {layer: [] for layer in args.layers}
    hooks = []
    for layer in args.layers:
        def save(_module, inputs, layer=layer):
            captures[layer].append(inputs[0].detach().reshape(-1, inputs[0].shape[-1]).cpu().view(torch.int16).numpy().copy())
        hooks.append(model.model.layers[layer].mlp.gate_proj.register_forward_pre_hook(save))
    try:
        for row in rows:
            model.model(torch.tensor(row, device='cuda', dtype=torch.long)[None], use_cache=False)
    finally:
        for hook in hooks:
            hook.remove()
    arrays = {f'layer{layer:02}': np.concatenate(parts).view(np.uint16) for layer, parts in captures.items()}
    arrays['tokens'] = rows
    with path.with_suffix('.npz.partial').open('wb') as f:
        np.savez(f, **arrays)
    path.with_suffix('.npz.partial').rename(path)
    result = dict(producer=args.producer, split=args.split, offset=args.offset,
                  windows=args.windows, tokens_per_window=256, layers=args.layers,
                  input_dtype='BF16 bits in uint16', capture_sha256=sha(path),
                  source_manifest_sha256=sha(SOURCE / 'manifest.json') if manifest else None,
                  model_source_sha256=sha(MODEL / 'source.json'), fixture_sha256=sha(FIXTURE),
                  source_sha256=sha(Path(__file__)), seconds=time.monotonic() - start,
                  shapes={k: list(v.shape) for k, v in arrays.items()})
    atomic_json(receipt, result)
    print(json.dumps(dict(path=str(path), **result)), flush=True)


def replacement_weights(replacement):
    if replacement.get('format', 'vector-pair') == 'scalar4-g128':
        sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'subbit'))
        from spectral_quant import decode
        accounting_path = Path(replacement['accounting'])
        if sha(accounting_path) != replacement['accounting_sha256']:
            raise ValueError('scalar accounting changed')
        accounting = json.loads(accounting_path.read_text())
        weights, records = [], []
        for projection in ['gate_proj', 'up_proj']:
            key = f'model.layers.{replacement["layer"]}.mlp.{projection}.weight'
            matches = [e for e in accounting['entries'] if e['name'] == key and e['bits'] == 4]
            if len(matches) != 1:
                raise ValueError('scalar matrix missing or ambiguous')
            entry = matches[0]
            path = Path(entry['image'])
            if sha(path) != entry['sha256']:
                raise ValueError('frozen scalar image changed')
            with np.load(path) as image:
                weights.append(decode(image, 'weight').cpu().numpy())
            records.append(entry)
        if sum(e['payload_bytes'] for e in records) != replacement['payload_bytes']:
            raise ValueError('scalar byte accounting changed')
        return *weights, dict(replacement, matrices=records,
            decoder_sha256=sha(Path(__file__).resolve().parents[2] / 'subbit/spectral_quant.py'))
    if replacement.get('format', 'vector-pair') != 'vector-pair':
        raise ValueError('unknown replacement format')
    from codec import decode_image
    path = Path(replacement['image'])
    image_hash = sha(path)
    if image_hash != replacement['sha256']:
        raise ValueError('frozen image changed')
    receipt = json.loads(path.with_suffix('.json').read_text())
    if receipt['image_sha256'] != image_hash or receipt['layer'] != replacement['layer']:
        raise ValueError('image receipt mismatch')
    if receipt['physical_bytes'] != replacement['payload_bytes']:
        raise ValueError('frozen byte accounting differs from image receipt')
    record = dict(replacement, container_bytes=path.stat().st_size,
                  image_receipt_sha256=sha(path.with_suffix('.json')))
    return *decode_image(path), record


@torch.inference_mode()
def evaluate(args):
    config = json.loads(args.config.read_text())
    if 'source' in config['arms']:
        raise ValueError('source is the reserved unchanged-image control')
    destination = DATA / 'model-quality'
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / f'{config["name"]}-{args.split}-{args.offset}-{args.windows}.json'
    if output.exists():
        raise FileExistsError(output)
    model, manifest = installed(SOURCE)
    entries = {entry['key']: entry for entry in manifest['matrices']}
    rows = token_rows(args.split, args.offset, args.windows)
    result = dict(name=config['name'], split=args.split, offset=args.offset,
                  source_manifest_sha256=sha(SOURCE / 'manifest.json'),
                  model_source_sha256=sha(MODEL / 'source.json'), fixture_sha256=sha(FIXTURE),
                  config_sha256=sha(args.config), source_sha256=sha(Path(__file__)),
                  codec_sha256=sha(Path(__file__).with_name('codec.py')),
                  execution='Expanded BF16 quality only; unchanged ternary down and all other matrices',
                  unique_parameters=manifest['unique_parameters'], arms={})
    for name, replacements in {'source': [], **config['arms']}.items():
        payload = manifest['payload_bytes']
        changed = []
        recorded_replacements = []
        try:
            used_layers = set()
            for replacement in replacements:
                layer = replacement['layer']
                if layer in used_layers or layer not in range(28):
                    raise ValueError('duplicate or invalid layer')
                used_layers.add(layer)
                gate, up, replacement = replacement_weights(replacement)
                if gate.shape != (3072, 1024) or up.shape != gate.shape:
                    raise ValueError('unexpected gate/up image shape')
                for projection, weight in [('gate_proj', gate), ('up_proj', up)]:
                    key = f'model.layers.{layer}.mlp.{projection}.weight'
                    model.get_parameter(key).copy_(torch.as_tensor(weight, device='cuda'))
                    payload -= entries[key]['payload_bytes']
                    changed.append(key)
                payload += replacement['payload_bytes']
                recorded_replacements.append(replacement)
            losses = []
            for index, row in enumerate(rows):
                x = torch.tensor(row, device='cuda', dtype=torch.long)[None]
                logits = model(x, use_cache=False).logits[:, :-1].float()
                value = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                    x[:, 1:].reshape(-1), reduction='sum')
                losses.append(dict(index=args.offset + index, predictions=len(row) - 1,
                                   nll_sum=float(value)))
            result['arms'][name] = dict(payload_bytes=payload,
                bpw=8 * payload / manifest['unique_parameters'], replacements=recorded_replacements,
                windows=losses, nll=sum(r['nll_sum'] for r in losses) / sum(r['predictions'] for r in losses))
            print(json.dumps(dict(arm=name, nll=result['arms'][name]['nll'], payload_bytes=payload)), flush=True)
        finally:
            for key in changed:
                model.get_parameter(key).copy_(expanded(SOURCE / (key.replace('.', '_') + '.npz')))
    atomic_json(output, result)
    print(json.dumps(dict(receipt=str(output))), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['capture', 'evaluate'])
    parser.add_argument('--config', type=Path)
    parser.add_argument('--producer', choices=['ternary', 'reference'], default='ternary')
    parser.add_argument('--split', choices=['train', 'validation', 'test'], default='train')
    parser.add_argument('--offset', type=int, default=464)
    parser.add_argument('--windows', type=int, default=4)
    parser.add_argument('--layers', type=lambda text: [int(s) for s in text.split(',')], default=[0, 14, 27])
    args = parser.parse_args()
    if len(set(args.layers)) != len(args.layers) or any(layer not in range(28) for layer in args.layers):
        raise ValueError('distinct layers 0..27 required')
    torch.set_num_threads(2)
    torch.backends.cuda.matmul.allow_tf32 = False
    if args.action == 'capture':
        capture(args)
    elif args.config is None:
        parser.error('evaluate requires --config')
    else:
        evaluate(args)


if __name__ == '__main__':
    main()
