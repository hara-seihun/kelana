#!/usr/bin/env python3
"""Evaluate one frozen 1.7B projection image at its actual downstream model consumer."""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-1.7b'
DATA = ROOT / 'size-transfer'
TOKENS = ROOT / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
SPECTRAL_SOURCE = Path(__file__).resolve().parents[1] / 'spectral_quant.py'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def binary_weight(record):
    image = Path(record['image'])
    if sha(image) != record['image_sha256']:
        raise ValueError('binary image hash changed')
    with np.load(image) as f:
        n, k, rank = [int(x) for x in f['dimensions']]
        u = torch.from_numpy(np.unpackbits(f['U'], axis=1, bitorder='little')[:, :rank].copy().astype(np.float32)) * 2 - 1
        v = torch.from_numpy(np.unpackbits(f['V'], axis=1, bitorder='little')[:, :k].copy().astype(np.float32)) * 2 - 1
        pre = torch.from_numpy(f['scale_pre'].copy()).float()
        post = torch.from_numpy(f['scale_post'].copy()).float()
    return (u @ v) * post[:, None] * pre[None, :]


def spectral_weight(entry):
    image = Path(entry['image'])
    if sha(image) != entry['image_sha256']:
        raise ValueError('spectral image hash changed')
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SPECTRAL_SOURCE)
    method = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(method)
    with np.load(image) as f:
        arrays = {key: f[key].copy() for key in f.files}
    left, right = method.decode(arrays, 'left'), method.decode(arrays, 'right')
    return left @ right


def loss_metrics(logits, reference_logits, labels):
    nll = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                                            labels.flatten(), reduction='sum').item()
    logq = torch.nn.functional.log_softmax(logits, dim=-1)
    logp = torch.nn.functional.log_softmax(reference_logits, dim=-1)
    p = logp.exp()
    kl = (p * (logp - logq)).sum().item()
    agreement = (logits.argmax(-1) == reference_logits.argmax(-1)).sum().item()
    return nll, kl, agreement


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-name', required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    factors = DATA / 'factors'
    binary = json.loads((factors / f'{args.fixture_name}-binary.json').read_text())
    spectral = json.loads((factors / f'{args.fixture_name}-spectral.json').read_text())
    selected = next(e for e in spectral['entries'] if e['image'] == spectral['selected_image'])
    fixture = DATA / 'fixtures' / (args.fixture_name + '.npz')
    if sha(fixture) != binary['fixture_sha256'] or sha(fixture) != spectral['fixture_sha256']:
        raise ValueError('fixture changed')
    manifest = json.loads((DATA / 'fixtures/manifest.json').read_text())
    module_name = manifest['files'][fixture.name]['module']
    candidate_cpu = {'binary': binary_weight(binary).to(torch.bfloat16),
                     'spectral': spectral_weight(selected).to(torch.bfloat16)}
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
                                                dtype=torch.bfloat16,
                                                attn_implementation='sdpa').eval().to('cuda')
    weight = model.get_submodule(module_name).weight
    original = weight.detach().clone()
    for label, candidate in candidate_cpu.items():
        if candidate.shape != weight.shape:
            raise ValueError(f'{label} image has incorrect matrix shape')
    with np.load(TOKENS) as f:
        windows = {split: f[split].copy() for split in ('validation', 'test')}
    splits = {}
    with torch.inference_mode():
        for split, batch_tokens in windows.items():
            rows = []
            for i, row in enumerate(batch_tokens):
                tokens = torch.tensor(row, dtype=torch.long, device='cuda')[None]
                weight.copy_(original)
                ref = model(tokens, use_cache=False).logits[:, :-1].float()
                labels = tokens[:, 1:]
                ref_nll = torch.nn.functional.cross_entropy(ref.reshape(-1, ref.shape[-1]),
                                                            labels.flatten(), reduction='sum').item()
                outcomes = {}
                for name, replacement in candidate_cpu.items():
                    weight.copy_(replacement.to('cuda'))
                    logits = model(tokens, use_cache=False).logits[:, :-1].float()
                    nll, kl, agreement = loss_metrics(logits, ref, labels)
                    outcomes[name] = {'nll': nll, 'teacher_kl': kl,
                                      'top_token_agreement': agreement}
                    del logits
                rows.append({'window': i, 'reference_nll': ref_nll, 'predictions': len(row) - 1,
                             'candidates': outcomes})
                del ref
            count = sum(r['predictions'] for r in rows)
            reference_nll = sum(r['reference_nll'] for r in rows) / count
            splits[split] = {'reference_nll': reference_nll,
                             'reference_perplexity': math.exp(reference_nll),
                             'predictions': count, 'windows': rows, 'candidates': {}}
            for name in candidate_cpu:
                nll = sum(r['candidates'][name]['nll'] for r in rows) / count
                kl = sum(r['candidates'][name]['teacher_kl'] for r in rows) / count
                agreement = sum(r['candidates'][name]['top_token_agreement'] for r in rows) / count
                splits[split]['candidates'][name] = {'nll': nll, 'perplexity': math.exp(nll),
                                                      'delta_nll': nll-reference_nll,
                                                      'teacher_kl': kl, 'top_token_agreement': agreement}
            print(json.dumps({'module': module_name, 'split': split,
                              'reference_nll': reference_nll,
                              'candidates': splits[split]['candidates']}), flush=True)
        weight.copy_(original)
    unique = sum(p.numel() for p in model.parameters())
    n, k = weight.shape
    images = {'binary': {'path': binary['image'], 'sha256': binary['image_sha256'],
                         'matrix_payload_bpw': binary['matrix_payload_bpw'],
                         'matrix_payload_bytes': binary['matrix_payload_bytes']},
              'spectral': {'path': selected['image'], 'sha256': selected['image_sha256'],
                           'matrix_payload_bpw': selected['payload_bpw'],
                           'matrix_payload_bytes': selected['payload_bytes_including_shapes']}}
    images['binary']['dimension_descriptor_bytes'] = binary.get('dimension_descriptor_bytes', 12)
    for item in images.values():
        paid_bytes = item['matrix_payload_bytes'] + item.get('dimension_descriptor_bytes', 0)
        item['full_model_bits_per_unique_parameter'] = (16 * (unique - n*k) +
                                                      8 * paid_bytes) / unique
    output = {'model_revision': json.loads((MODEL / 'source.json').read_text())['revision'],
              'unique_parameters': unique, 'token_sha256': sha(TOKENS),
              'fixture_sha256': sha(fixture), 'module': module_name,
              'matrix_dimensions': [n, k], 'images': images,
              'evaluation': 'isolated BF16-expanded factor replacement, not compressed-runtime timing',
              'splits': splits}
    destination = DATA / f'continuation-{args.fixture_name}.json'
    destination.write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({'report': str(destination)}), flush=True)


if __name__ == '__main__':
    main()
