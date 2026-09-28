#!/usr/bin/env python3
"""Capture three Qwen3-1.7B projection inputs and BF16 reference loss on fixed tokens."""
import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModelForCausalLM

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-1.7b'
TOKENS = ROOT / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
DEST = ROOT / 'size-transfer'
MODULES = ('model.layers.0.self_attn.q_proj',
           'model.layers.27.self_attn.q_proj',
           'model.layers.14.mlp.down_proj')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--split', choices=('train', 'validation', 'test'), required=True)
    args = parser.parse_args()
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    torch.manual_seed(42)
    model_source = json.loads((MODEL / 'source.json').read_text())
    if model_source['revision'] != '70d244cc86ccca08cf5af4e1e306ecf908b1ad5e':
        raise ValueError('model revision changed')
    old_tokenizer = ROOT / 'models/qwen3-0.6b/tokenizer.json'
    for name in ('tokenizer.json', 'tokenizer_config.json', 'vocab.json', 'merges.txt'):
        if sha(MODEL / name) != sha(ROOT / 'models/qwen3-0.6b' / name):
            raise ValueError(f'tokenizer differs: {name}')
    with np.load(TOKENS) as data:
        tokens = data[args.split].copy()
    model = AutoModelForCausalLM.from_pretrained(MODEL, local_files_only=True,
                                                dtype=torch.bfloat16,
                                                attn_implementation='sdpa').eval().to('cuda')
    input_embedding = model.get_input_embeddings().weight
    output_embedding = model.get_output_embeddings().weight
    unique = sum(p.numel() for p in model.parameters())
    tied = input_embedding.data_ptr() == output_embedding.data_ptr()
    if not tied:
        raise ValueError('expected tied output and input embedding parameters')
    split_dir = DEST / 'capture' / args.split
    split_dir.mkdir(parents=True, exist_ok=True)
    captures = {name: [] for name in MODULES} if args.split != 'test' else {}
    handles = []
    if captures:
        for name in MODULES:
            def hook(module, inputs, name=name):
                captures[name].append(inputs[0].detach().float().cpu().numpy().reshape(-1, inputs[0].shape[-1]))
            handles.append(model.get_submodule(name).register_forward_pre_hook(hook))
    rows = []
    with torch.inference_mode():
        for i, token_ids in enumerate(tokens):
            batch = torch.tensor(token_ids, device='cuda', dtype=torch.long)[None]
            logits = model(batch, use_cache=False).logits[:, :-1].float()
            nll = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                                                    batch[:, 1:].reshape(-1), reduction='sum').item()
            rows.append({'window': i, 'nll': nll, 'predictions': int(batch.shape[1] - 1)})
    for handle in handles:
        handle.remove()
    files = {}
    for name, observations in captures.items():
        path = split_dir / (name.replace('.', '_') + '.npy')
        np.save(path, np.concatenate(observations))
        files[name] = {'input_path': str(path), 'input_sha256': sha(path),
                       'input_shape': list(np.load(path, mmap_mode='r').shape)}
        if args.split == 'train':
            weight = split_dir / (name.replace('.', '_') + '-weight.npy')
            np.save(weight, model.get_submodule(name).weight.detach().float().cpu().numpy())
            files[name]['weight_path'] = str(weight)
            files[name]['weight_sha256'] = sha(weight)
    predictions = sum(row['predictions'] for row in rows)
    nll = sum(row['nll'] for row in rows) / predictions
    record = {'model_revision': model_source['revision'], 'model_source': str(MODEL / 'source.json'),
              'model_source_sha256': sha(MODEL / 'source.json'), 'split': args.split,
              'token_file': str(TOKENS), 'token_sha256': sha(TOKENS),
              'tokenizer_sha256': sha(old_tokenizer), 'windows': len(tokens),
              'length': len(tokens[0]), 'unique_parameters': unique,
              'tied_input_output_embedding': tied,
              'serialized_tensor_elements_including_tied_alias':
                  sum(p.numel() for p in model.state_dict().values()),
              'reference': {'nll': nll, 'perplexity': math.exp(nll),
                            'predictions': predictions, 'windows': rows},
              'files': files, 'torch': torch.__version__, 'hip': torch.version.hip,
              'device': torch.cuda.get_device_name()}
    target = DEST / f'capture-{args.split}.json'
    target.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'split': args.split, 'reference': record['reference'],
                      'unique_parameters': unique, 'tied': tied, 'capture': str(target)}), flush=True)


if __name__ == '__main__':
    main()
