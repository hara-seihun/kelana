#!/usr/bin/env python3
"""Small-model quality and activation experiments; expanded weights are not speed receipts."""
import argparse
import hashlib
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-0.6b'
CORPUS = ROOT / 'corpus/wikitext-2-raw'
LAYERS = (0, 7, 14, 27)
MODULES = ('mlp.down_proj', 'mlp.up_proj', 'self_attn.q_proj', 'self_attn.o_proj')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def windows(tokenizer, split, count, length):
    text = (CORPUS / f'{split}.txt').read_text()
    ids = np.asarray(tokenizer(text, add_special_tokens=False)['input_ids'], dtype=np.int32)
    rng = np.random.default_rng({'train': 2109, 'validation': 2209, 'test': 2309}[split])
    starts = rng.choice(len(ids) // length, count, replace=False) * length
    return np.stack([ids[s:s + length] for s in starts]), starts.tolist()


def hadamard(n, device):
    h = torch.ones((1, 1), device=device)
    while h.shape[0] < n:
        h = torch.cat((torch.cat((h, h), 1), torch.cat((h, -h), 1)), 0)
    return h


def quantize(model, mode):
    parameters = list(model.named_parameters())
    bits = 0
    manifest = []
    with torch.no_grad():
        for name, p in parameters:
            if p.ndim != 2 or mode == 'reference':
                charge = p.numel() * 16
                manifest.append({'name': name, 'shape': list(p.shape), 'bits': charge,
                                 'kind': 'bf16'})
                bits += charge
                continue
            w = p.float().reshape(p.shape[0], -1, 128)
            if mode in ('rtn4', 'rtn2'):
                b = int(mode[-1]); top = 2 ** (b - 1) - 0.5
                scale = (w.abs().amax(-1, keepdim=True) / top).clamp_min(1e-20).half().float()
                scale = scale.clamp_min(torch.finfo(torch.float16).tiny)
                codes = (w / scale + top).round().clamp(0, 2 ** b - 1)
                reconstructed = (codes - top) * scale
                charge = p.numel() * b + scale.numel() * 16
            elif mode == 'sign1':
                scale = w.abs().mean(-1, keepdim=True).half().float()
                reconstructed = torch.where(w >= 0, scale, -scale)
                charge = p.numel() + scale.numel() * 16
            elif mode == 'walsh8':
                # Each length-eight vector chooses one signed Walsh atom.
                # Sixteen labels need four bits; one FP16 scale spans 128 weights.
                h = hadamard(8, p.device)
                v = w.reshape(*w.shape[:2], 16, 8)
                responses = v @ h.T
                labels = responses.abs().argmax(-1)
                signed = responses.gather(-1, labels.unsqueeze(-1)).squeeze(-1)
                atoms = h[labels] * torch.where(signed >= 0, 1., -1.).unsqueeze(-1)
                scale = (signed.abs().mean(-1, keepdim=True) / 8).half().float()
                reconstructed = (atoms * scale.unsqueeze(-1)).reshape_as(w)
                charge = p.numel() // 8 * 4 + scale.numel() * 16
            else:
                raise ValueError(mode)
            p.copy_(reconstructed.reshape_as(p))
            bits += charge
            manifest.append({'name': name, 'shape': list(p.shape), 'bits': charge,
                             'kind': mode, 'scale_group': 128})
    total = sum(p.numel() for _, p in parameters)
    return {'unique_parameters': total, 'representation_bits': bits,
            'bits_per_unique_parameter': bits / total, 'tensors': manifest,
            'rate_scope': 'all unique parameters; tied embedding/head counted once; codes and FP16 scales',
            'serialized_image': False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', choices=('reference', 'rtn4', 'rtn2', 'sign1', 'walsh8'), default='reference')
    parser.add_argument('--capture', action='store_true')
    parser.add_argument('--windows', type=int, default=4)
    parser.add_argument('--calibration-windows', type=int, default=8)
    parser.add_argument('--length', type=int, default=256)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.capture and args.mode != 'reference':
        raise ValueError('research fixtures use the unquantized producer')
    torch.set_num_threads(4)
    torch.manual_seed(42)
    torch.backends.cuda.matmul.allow_tf32 = False
    tokenizer = AutoTokenizer.from_pretrained(MODEL, local_files_only=True)
    tokenizer.model_max_length = 10 ** 12
    batches = {}; starts = {}
    for split in ('train', 'validation', 'test'):
        count = args.calibration_windows if split == 'train' else args.windows
        batches[split], starts[split] = windows(tokenizer, split, count, args.length)
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
                                                dtype=torch.bfloat16,
                                                attn_implementation='sdpa').eval().to('cuda')
    rate = quantize(model, args.mode)
    destination = args.output or ROOT / 'runs' / f'{args.mode}-w{args.windows}-l{args.length}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    captures = {}; handles = []; split_now = ''
    if args.capture:
        for layer in LAYERS:
            for suffix in MODULES:
                name = f'model.layers.{layer}.{suffix}'
                def hook(module, values, name=name):
                    if split_now in ('train', 'validation'):
                        captures.setdefault((name, split_now), []).append(values[0].detach().float().cpu().numpy().reshape(-1, values[0].shape[-1]))
                handles.append(model.get_submodule(name).register_forward_pre_hook(hook))
    result = {'mode': args.mode, 'source_sha256': sha(Path(__file__)),
              'model_source': json.loads((MODEL / 'source.json').read_text()),
              'corpus_source': json.loads((CORPUS / 'text-source.json').read_text()),
              'torch': torch.__version__, 'hip': torch.version.hip,
              'device': torch.cuda.get_device_name(), 'rate': rate,
              'length': args.length, 'window_starts': starts, 'splits': {},
              'execution': 'BF16 expanded reference for quality, not compressed inference timing'}
    with torch.inference_mode():
        for split in ('train', 'validation', 'test'):
            if split == 'train' and not args.capture:
                continue
            split_now = split
            rows = []
            for i, tokens in enumerate(batches[split]):
                x = torch.tensor(tokens, device='cuda', dtype=torch.long).unsqueeze(0)
                logits = model(x, use_cache=False).logits[:, :-1].float()
                nll = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                                                        x[:, 1:].reshape(-1), reduction='sum').item()
                rows.append({'window': i, 'nll': nll, 'predictions': args.length - 1})
                del logits
            count = sum(r['predictions'] for r in rows)
            mean = sum(r['nll'] for r in rows) / count
            result['splits'][split] = {'nll': mean, 'perplexity': math.exp(mean),
                                       'predictions': count, 'windows': rows}
            print(json.dumps({'mode': args.mode, 'split': split, **result['splits'][split]}), flush=True)
    for handle in handles:
        handle.remove()
    if args.capture:
        folder = ROOT / 'fixtures/qwen3-0.6b-wikitext'
        folder.mkdir(parents=True, exist_ok=True)
        fixture_manifest = {'model_revision': result['model_source']['revision'],
                            'window_starts': starts, 'length': args.length,
                            'source_sha256': result['source_sha256'], 'files': {}}
        for layer in LAYERS:
            for suffix in MODULES:
                name = f'model.layers.{layer}.{suffix}'
                target = folder / f'layer{layer:02}-{suffix.replace(".", "_")}.npz'
                np.savez(target, weight=model.get_submodule(name).weight.detach().float().cpu().numpy(),
                         train=np.concatenate(captures[name, 'train']),
                         validation=np.concatenate(captures[name, 'validation']))
                fixture_manifest['files'][target.name] = {'sha256': sha(target), 'module': name}
        np.savez(folder / 'tokens.npz', **batches)
        fixture_manifest['tokens_sha256'] = sha(folder / 'tokens.npz')
        (folder / 'manifest.json').write_text(json.dumps(fixture_manifest, indent=2) + '\n')
        result['fixtures'] = str(folder)
    destination.write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
