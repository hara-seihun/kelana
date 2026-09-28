#!/usr/bin/env python3
"""Matched BF16, body-only, tied-only and complete four-bit loss panels."""
import argparse
import importlib.util
import json
import math
from pathlib import Path
import sys
import time

import numpy as np
import torch
from safetensors import safe_open

RESEARCH = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RESEARCH / 'ternary'))
from pilot import MODEL, ROOT, load_model, sha
sys.path.insert(0, str(RESEARCH / 'quantization-discovery/subbit'))
from spectral_quant import decode as scalar_decode

DATA = ROOT.parent
FIXTURE = ROOT / 'expanded-tokens.npz'
OUT = DATA / 'q4-diagnostic'
TIED = 'model.embed_tokens.weight'


def images(args):
    if args.converter == 'rtn':
        manifest_path = DATA / 'full-scalar/accounting.json'
        manifest = json.loads(manifest_path.read_text())
        entries = [dict(key=e['name'], path=e['image'], sha256=e['sha256'], payload_bytes=e['payload_bytes'])
                   for e in manifest['entries'] if e['bits'] == 4]
        def decode(path):
            with np.load(path) as image:
                return scalar_decode(image, 'weight')
        decoder_path = RESEARCH / 'quantization-discovery/subbit/spectral_quant.py'
    else:
        manifest_path = Path(args.manifest or OUT / 'calibrated/manifest.json')
        manifest = json.loads(manifest_path.read_text())
        entries = manifest['matrices']
        decoder_path = Path(args.decoder or Path(__file__).with_name('calibrated.py'))
        spec = importlib.util.spec_from_file_location('calibrated', decoder_path)
        module = importlib.util.module_from_spec(spec)
        sys.modules['calibrated'] = module
        spec.loader.exec_module(module)
        decode = module.decode
    if len(entries) != 197 or len({e['key'] for e in entries}) != 197 or sum(e['key'] == TIED for e in entries) != 1:
        raise ValueError('complete unique 197-matrix image required')
    for entry in entries:
        if sha(Path(entry['path'])) != entry['sha256']:
            raise ValueError('matrix hash mismatch: ' + entry['path'])
    return entries, decode, manifest_path, decoder_path


@torch.inference_mode()
def run(args):
    OUT.mkdir(parents=True, exist_ok=True)
    output = OUT / f'{args.name}-{args.split}-{args.offset}-{args.windows}.json'
    if output.exists():
        raise FileExistsError(output)
    start = time.monotonic()
    entries, decode, manifest_path, decoder_path = images(args)
    with np.load(FIXTURE) as fixture:
        rows = fixture[args.split][args.offset:args.offset + args.windows].copy()
    if rows.shape != (args.windows, 256):
        raise ValueError('incomplete panel')
    model = load_model()
    parameters = dict(model.named_parameters())
    unique = sum(p.numel() for p in parameters.values())
    assert unique == 596049920
    bf16_bytes = sum(p.numel() * p.element_size() for p in parameters.values())
    for entry in entries:
        if entry['key'] not in parameters:
            raise ValueError('unknown parameter ' + entry['key'])
    result = dict(name=args.name, converter=args.converter, split=args.split, offset=args.offset,
                  windows=args.windows, tokens_per_window=256, model_source_sha256=sha(MODEL / 'source.json'),
                  fixture_sha256=sha(FIXTURE), manifest=str(manifest_path), manifest_sha256=sha(manifest_path),
                  decoder_sha256=sha(decoder_path), script_sha256=sha(Path(__file__)), unique_parameters=unique,
                  execution='decoded actual image into BF16 SDPA model; one token window per forward; no packed speed claim',
                  arms={})
    installed = set()
    with safe_open(MODEL / 'model.safetensors', framework='pt', device='cpu') as reference:
        for arm in args.arms.split(','):
            if arm not in ('reference', 'tied', 'body', 'complete'):
                raise ValueError('unknown arm')
            wanted = {e['key'] for e in entries if arm == 'complete' or (arm == 'tied' and e['key'] == TIED)
                      or (arm == 'body' and e['key'] != TIED)}
            for key in installed - wanted:
                parameters[key].copy_(reference.get_tensor(key))
            for entry in entries:
                if entry['key'] in wanted - installed:
                    weight = decode(Path(entry['path']))
                    if tuple(weight.shape) != tuple(parameters[entry['key']].shape) or not torch.isfinite(weight).all():
                        raise ValueError('invalid decoded matrix')
                    parameters[entry['key']].copy_(weight)
                    del weight
            installed = wanted
            if model.lm_head.weight.data_ptr() != model.model.embed_tokens.weight.data_ptr():
                raise ValueError('broken tied head')
            payload = bf16_bytes + sum(e['payload_bytes'] - parameters[e['key']].numel() * 2
                                       for e in entries if e['key'] in wanted)
            losses = []
            for index, row in enumerate(rows):
                x = torch.tensor(row, device='cuda', dtype=torch.long)[None]
                logits = model(x, use_cache=False).logits[:, :-1].float()
                loss = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                    x[:, 1:].reshape(-1), reduction='sum')
                losses.append(dict(index=args.offset + index, predictions=255, nll_sum=float(loss)))
                del logits
            nll = sum(v['nll_sum'] for v in losses) / (255 * len(losses))
            result['arms'][arm] = dict(payload_bytes=payload, bpw=8 * payload / unique, nll=nll,
                perplexity=math.exp(nll), windows=losses, quantized_matrices=len(wanted))
            print(json.dumps(dict(arm=arm, nll=nll, perplexity=math.exp(nll), payload_bytes=payload)), flush=True)
    result['seconds'] = time.monotonic() - start
    partial = output.with_suffix('.json.partial')
    partial.write_text(json.dumps(result, indent=2) + '\n')
    partial.rename(output)
    print(json.dumps(dict(receipt=str(output), seconds=result['seconds'])), flush=True)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--converter', choices=['rtn', 'calibrated'], default='rtn')
    p.add_argument('--manifest', type=Path)
    p.add_argument('--decoder', type=Path)
    p.add_argument('--name', required=True)
    p.add_argument('--split', choices=['train', 'validation', 'test'], default='test')
    p.add_argument('--offset', type=int, default=0)
    p.add_argument('--windows', type=int, default=32)
    p.add_argument('--arms', default='reference,tied,complete,body')
    args = p.parse_args()
    if args.windows < 1 or args.offset < 0:
        p.error('invalid token panel')
    torch.set_num_threads(2)
    torch.backends.cuda.matmul.allow_tf32 = False
    run(args)
