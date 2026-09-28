#!/usr/bin/env python3
"""Compare sub-bit projection images through the unchanged complete Qwen model."""
import argparse
import json
import math
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

from pilot import MODEL, ROOT, sha
from spectral_quant import decode, quantize


def load_spectral(path):
    with np.load(path) as f:
        arrays = {k: f[k] for k in f.files}
    left, right = decode(arrays, 'left'), decode(arrays, 'right')
    return left @ right, sum(a.nbytes for a in arrays.values())


def load_binary(path):
    with np.load(path) as f:
        arrays = {k: f[k] for k in f.files}
    n, k, rank = arrays['dimensions'].tolist()
    left = torch.from_numpy(np.unpackbits(arrays['U'], axis=1, bitorder='little')[:, :rank].astype(np.float32)*2-1)
    right = torch.from_numpy(np.unpackbits(arrays['V'], axis=1, bitorder='little')[:, :k].astype(np.float32)*2-1)
    left *= torch.from_numpy(arrays['scale_post'].astype(np.float32))[:, None]
    right *= torch.from_numpy(arrays['scale_pre'].astype(np.float32))[None, :]
    return left @ right, sum(a.nbytes for a in arrays.values())


def run(args):
    torch.set_num_threads(4)
    torch.manual_seed(42)
    torch.backends.cuda.matmul.allow_tf32 = False
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True, dtype=torch.bfloat16,
                                                attn_implementation='sdpa').eval().to('cuda')
    parameter = model.get_submodule(args.module).weight
    original = parameter.detach().float().cpu().clone()
    unique = sum(p.numel() for p in model.parameters())
    fixtures = ROOT / 'fixtures/qwen3-0.6b-wikitext'
    with np.load(fixtures / 'tokens.npz') as f:
        tokens = {split: f[split].copy() for split in ('validation', 'test')}
    spectral, spectral_bytes = load_spectral(args.spectral)
    binary, binary_bytes = load_binary(args.binary)
    scalar_arrays = quantize(original, 4, 128, 'weight')
    scalar = decode(scalar_arrays, 'weight')
    args.out.mkdir(parents=True, exist_ok=True)
    scalar_path = args.out / (args.module.replace('.', '_') + '-scalar4.npz')
    np.savez(scalar_path, **scalar_arrays)
    arms = [('reference', original, original.numel()*2, None),
            ('spectral', spectral, spectral_bytes, args.spectral),
            ('nanoquant-admm', binary, binary_bytes, args.binary),
            ('scalar4-ls', scalar, sum(a.nbytes for a in scalar_arrays.values()), scalar_path)]
    reference = {}
    result = {'module': args.module, 'model_source_sha256': sha(MODEL / 'source.json'),
              'model_revision': json.loads((MODEL / 'source.json').read_text())['revision'],
              'token_file_sha256': sha(fixtures / 'tokens.npz'), 'torch': torch.__version__,
              'hip': torch.version.hip, 'device': torch.cuda.get_device_name(),
              'sources': {p.name: sha(p) for p in (Path(__file__), Path(__file__).with_name('pilot.py'),
                                                  Path(__file__).with_name('spectral_quant.py'))},
              'execution': 'one projection replaced, all other weights original; factors expanded in FP32 then rounded to dense BF16 for quality only',
              'unique_parameters': unique, 'projection_parameters': original.numel(), 'arms': []}
    with torch.inference_mode():
        for label, weight, payload_bytes, image in arms:
            parameter.copy_(weight.to(device='cuda', dtype=parameter.dtype))
            record = {'label': label, 'payload_bytes': payload_bytes,
                      'matrix_bpw': payload_bytes*8/original.numel(),
                      'all_unique_parameter_bpw': (16*(unique-original.numel())+8*payload_bytes)/unique,
                      'image': str(image) if image else None,
                      'image_sha256': sha(image) if image else None, 'splits': {}}
            for split, batch in tokens.items():
                rows = []
                for index, token_row in enumerate(batch):
                    x = torch.tensor(token_row, device='cuda', dtype=torch.long).unsqueeze(0)
                    logits = model(x, use_cache=False).logits[0, :-1].float()
                    logp = logits.log_softmax(-1)
                    targets = x[0, 1:]
                    nll = -logp.gather(1, targets[:, None]).sum().item()
                    if label == 'reference':
                        reference[split, index] = logp.cpu()
                    ref = reference[split, index].to('cuda')
                    kl = (ref.exp() * (ref-logp)).sum().item()
                    agreement = int((ref.argmax(-1) == logp.argmax(-1)).sum())
                    rows.append({'window': index, 'predictions': len(targets), 'nll_sum': nll,
                                 'reference_kl_sum': kl, 'argmax_agreements': agreement})
                    del logits, logp, ref
                count = sum(r['predictions'] for r in rows)
                mean = sum(r['nll_sum'] for r in rows)/count
                record['splits'][split] = {'nll': mean, 'perplexity': math.exp(mean),
                    'reference_kl': sum(r['reference_kl_sum'] for r in rows)/count,
                    'argmax_agreement': sum(r['argmax_agreements'] for r in rows)/count,
                    'predictions': count, 'windows': rows}
            result['arms'].append(record)
            print(json.dumps(record), flush=True)
    path = args.out / (args.module.replace('.', '_') + '.json')
    path.write_text(json.dumps(result, indent=2)+'\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--module', default='model.layers.0.self_attn.q_proj')
    p.add_argument('--spectral', type=Path, default=ROOT / 'spectral-quant/layer00-self_attn_q_proj-b0.539062-l4r4-g128-s0.5-f1.npz')
    p.add_argument('--binary', type=Path, default=ROOT / 'binary-factors/fixtures/model_layers_0_self_attn_q_proj_weight_0.55.npz')
    p.add_argument('--out', type=Path, default=ROOT / 'continuation')
    run(p.parse_args())
