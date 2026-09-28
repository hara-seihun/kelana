#!/usr/bin/env python3
"""Freeze disjoint, previously unused WikiText-2 windows for paired Q continuation."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from transformers import AutoTokenizer

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = ROOT / 'models/qwen3-0.6b'
CORPUS = ROOT / 'corpus/wikitext-2-raw'
PRIOR = ROOT / 'fixtures/qwen3-0.6b-wikitext/manifest.json'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def overlaps(start, length, intervals):
    return any(start < b and a < start + length for a, b in intervals)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    tokenizer = AutoTokenizer.from_pretrained(MODEL, local_files_only=True)
    tokenizer.model_max_length = 10**12
    previous = json.loads(PRIOR.read_text())
    config = {'validation': (32, 8, 7391), 'test': (64, 8, 7491)}
    arrays = {}
    manifest = {'model_revision': json.loads((MODEL / 'source.json').read_text())['revision'],
                'tokenizer_sha256': sha(MODEL / 'tokenizer.json'),
                'prior_fixture_sha256': sha(PRIOR), 'excluded_windows': previous['window_starts'],
                'tokenization': 'AutoTokenizer add_special_tokens=False; each window starts at a multiple of its length',
                'windows': {}, 'corpus': {}}
    for split, (short_count, long_count, seed) in config.items():
        text_file = CORPUS / f'{split}.txt'
        ids = np.asarray(tokenizer(text_file.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32)
        occupied = [(s, s + previous['length']) for s in previous['window_starts'][split]]
        rng = np.random.default_rng(seed)
        manifest['corpus'][split] = {'text_sha256': sha(text_file), 'token_count': len(ids), 'seed': seed}
        for length, count in ((256, short_count), (1024, long_count)):
            eligible = [s for s in range(0, len(ids) - length + 1, length)
                        if not overlaps(s, length, occupied)]
            selected = sorted(rng.choice(eligible, size=count, replace=False).tolist())
            for s in selected:
                occupied.append((s, s + length))
            key = f'{split}_{length}'
            arrays[key] = np.stack([ids[s:s + length] for s in selected])
            manifest['windows'][key] = {'length': length, 'starts': selected, 'count': count,
                                        'predictions': count * (length - 1)}
    token_file = a.out / 'tokens.npz'
    np.savez(token_file, **arrays)
    manifest['tokens_sha256'] = sha(token_file)
    manifest_file = a.out / 'manifest.json'
    manifest_file.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'manifest': str(manifest_file), 'tokens_sha256': manifest['tokens_sha256'],
                      'windows': manifest['windows']}), flush=True)


if __name__ == '__main__':
    main()
