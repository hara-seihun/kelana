#!/usr/bin/env python3
"""Generate exact layer-0 k-projection inputs from Qwen embeddings and RMSNorm."""
import argparse
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from transformers import AutoTokenizer

MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
CORPUS = Path('/path/to/workspace/data/kelana-subbit/corpus/wikitext-2-raw')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--model', type=Path, default=MODEL)
    p.add_argument('--corpus', type=Path, default=CORPUS)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--tokens', type=int, default=512)
    a = p.parse_args()
    tokenizer = AutoTokenizer.from_pretrained(a.model, local_files_only=True)
    with safe_open(a.model / 'model.safetensors', framework='pt', device='cpu') as f:
        embedding = f.get_tensor('model.embed_tokens.weight')
        norm = f.get_tensor('model.layers.0.input_layernorm.weight')
    a.out.mkdir(parents=True, exist_ok=True)
    for split in ('train', 'test'):
        text = (a.corpus / f'{split}.txt').read_text()[:100_000]
        ids = tokenizer(text, add_special_tokens=False)['input_ids'][:a.tokens]
        x = embedding[ids]
        # Qwen3RMSNorm casts the normalized activations back to their input dtype
        # before multiplying by the learned norm weight.
        x = (x.float() * torch.rsqrt(x.float().square().mean(-1, keepdim=True) + 1e-6)).to(x.dtype) * norm
        np.save(a.out / f'layer0_k_proj_{split}.npy', x.float().numpy())
        (a.out / f'layer0_k_proj_{split}.json').write_text(json.dumps({
            'model': str(a.model), 'corpus': str(a.corpus / f'{split}.txt'),
            'tokens': len(ids), 'tensor': 'model.layers.0.self_attn.k_proj input',
            'construction': 'embed_tokens then input_layernorm, Qwen3RMSNorm epsilon 1e-6'}, indent=2) + '\n')
        print(split, len(ids), flush=True)


if __name__ == '__main__':
    main()
