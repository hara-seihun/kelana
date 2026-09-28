#!/usr/bin/env python3
"""Pilot full-model quality of one frozen grouped-LS scalar image, expanded to BF16."""
import argparse
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from spectral_quant import decode
sys.path.insert(0, str(Path(__file__).resolve().parent))
from fit import MODEL, sha, image_path

DATA = Path('/path/to/workspace/data/kelana-subbit/full-scalar')
FIXTURE = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bits', type=int, choices=(2, 4), required=True)
    p.add_argument('--split', choices=('validation', 'test'), required=True)
    p.add_argument('--data', type=Path, default=DATA)
    args = p.parse_args()
    torch.set_num_threads(4)
    torch.manual_seed(42)
    torch.backends.cuda.matmul.allow_tf32 = False
    accounting = json.loads((args.data/'accounting.json').read_text())
    assert accounting['token_fixture_sha256'] == sha(FIXTURE/'tokens.npz')
    with np.load(FIXTURE/'tokens.npz') as file:
        windows = file[args.split].copy()
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
                dtype=torch.bfloat16, attn_implementation='sdpa').eval().to('cuda')
    assert model.get_input_embeddings().weight.data_ptr() == model.get_output_embeddings().weight.data_ptr()
    started = time.monotonic()
    teachers = []
    rows = []
    with torch.inference_mode():
        for index, tokens in enumerate(windows):
            x = torch.tensor(tokens.astype(np.int64), device='cuda').unsqueeze(0)
            targets = x[0, 1:]
            logp = model(x, use_cache=False).logits[0, :-1].float().log_softmax(-1)
            teachers.append((x, targets, logp))
            rows.append({'index': index, 'predictions': len(targets),
                         'reference_nll_sum': -logp.gather(1, targets[:,None]).sum().item()})
        print(json.dumps({'stage': 'reference', 'seconds': time.monotonic()-started}), flush=True)
        entries = [item for item in accounting['entries'] if item['bits'] == args.bits]
        assert len(entries) == 197
        for position, item in enumerate(entries):
            image = image_path(args.data, item['name'], args.bits)
            assert item['sha256'] == sha(image)
            with np.load(image) as file:
                weight = decode(file, 'weight')
            parameter = model.get_submodule(item['name'].removesuffix('.weight'))
            parameter.weight.copy_(weight.to(device='cuda', dtype=torch.bfloat16))
            del weight
            if (position+1) % 49 == 0:
                print(json.dumps({'stage': 'loaded', 'matrices': position+1, 'seconds': time.monotonic()-started}), flush=True)
        for row, (x, targets, teacher) in zip(rows, teachers):
            logp = model(x, use_cache=False).logits[0, :-1].float().log_softmax(-1)
            row['scalar_nll_sum'] = -logp.gather(1, targets[:,None]).sum().item()
            row['teacher_kl_sum'] = (teacher.exp() * (teacher-logp)).sum().item()
            row['argmax_agreements'] = int((teacher.argmax(-1)==logp.argmax(-1)).sum().item())
    count = sum(item['predictions'] for item in rows)
    result = {'bits': args.bits, 'split': args.split, 'matrix_count': len(entries),
              'token_fixture_sha256': accounting['token_fixture_sha256'],
              'model_revision': accounting['model_revision'],
              'accounting_sha256': sha(args.data/'accounting.json'),
              'elapsed_seconds': time.monotonic()-started, 'predictions': count,
              'reference_nll': sum(item['reference_nll_sum'] for item in rows)/count,
              'scalar_nll': sum(item['scalar_nll_sum'] for item in rows)/count,
              'scalar_ppl': math.exp(sum(item['scalar_nll_sum'] for item in rows)/count),
              'teacher_kl': sum(item['teacher_kl_sum'] for item in rows)/count,
              'argmax_agreement': sum(item['argmax_agreements'] for item in rows)/count,
              'per_window': rows,
              'execution': 'all 196 body matrices and shared embedding/head decoded then rounded to BF16; norm parameters original BF16'}
    dest = args.data/f'{args.split}-b{args.bits}.json'
    dest.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'result': str(dest), 'seconds': result['elapsed_seconds'],
                      'reference_nll': result['reference_nll'], 'scalar_nll': result['scalar_nll'],
                      'teacher_kl': result['teacher_kl'],
                      'argmax_agreement': result['argmax_agreement']}), flush=True)


if __name__ == '__main__':
    main()
