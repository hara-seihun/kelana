#!/usr/bin/env python3
"""Freeze unseen validation text, then replay paid complete-model images without refitting."""
import argparse
import json
from pathlib import Path

import numpy as np
from transformers import AutoTokenizer

from fresh_validation import ARMS, ROOT, evaluate
from calibrated_splice import SOURCE
from pilot import MODEL, sha

DATA = Path('/path/to/workspace/data/kelana-subbit')
TEXT = DATA / 'corpus/wikitext-2-raw/validation.txt'
EXISTING = DATA / 'ternary/tokens.json'
PREVIOUS = DATA / 'fixtures/qwen3-0.6b-wikitext/manifest.json'
FRESH = DATA / 'fresh-evaluation/manifest.json'


def freeze(path, count):
    if path.exists() or path.with_suffix('.json').exists():
        raise FileExistsError(path)
    meta = json.loads(EXISTING.read_text())
    if sha(TEXT) != meta['windows']['validation']['text_sha256']:
        raise ValueError('Validation source changed')
    tokenizer = AutoTokenizer.from_pretrained(DATA / 'models/qwen3-0.6b', local_files_only=True)
    tokenizer.model_max_length = 10**12
    ids = np.asarray(tokenizer(TEXT.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32)
    prior = json.loads(PREVIOUS.read_text())
    newer = json.loads(FRESH.read_text())
    occupied = [(s, s + prior['length']) for s in prior['window_starts']['validation']]
    occupied += [(s, s + 256) for s in meta['windows']['validation']['starts']]
    for key, record in newer['windows'].items():
        if key.startswith('validation_'):
            occupied += [(s, s + record['length']) for s in record['starts']]
    eligible = [s for s in range(0, len(ids) - 255, 256)
                if all(s + 256 <= a or b <= s for a, b in occupied)]
    if len(eligible) < count:
        raise ValueError(f'Only {len(eligible)} unused validation windows')
    starts = sorted(np.random.default_rng(20260923).choice(eligible, count, replace=False).tolist())
    rows = np.stack([ids[s:s+256] for s in starts])
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez(path, validation=rows)
    path.with_suffix('.json').write_text(json.dumps(dict(starts=starts, source_sha256=sha(TEXT),
        tokenizer_source_sha256=sha(MODEL / 'source.json'), excluded=occupied,
        fixture_sha256=sha(path), count=count, length=256), indent=2) + '\n')
    print(json.dumps(dict(starts=starts, fixture_sha256=sha(path), eligible=len(eligible))), flush=True)


def score(path, output):
    if output.exists():
        raise FileExistsError(output)
    manifest = json.loads(path.with_suffix('.json').read_text())
    if sha(path) != manifest['fixture_sha256']:
        raise ValueError('Frozen fixture changed')
    with np.load(path) as fixture:
        rows = fixture['validation'].copy()
    if rows.shape != (manifest['count'], 256):
        raise ValueError('Unexpected fixture shape')
    import torch
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    source_manifest = SOURCE / 'manifest.json'
    arms = {name: evaluate(name, rows, json.loads(source_manifest.read_text())) for name in ARMS}
    delta = np.asarray(arms[ARMS[1]]['per_window']) - np.asarray(arms[ARMS[0]]['per_window'])
    result = dict(contract='Frozen complete-model BF16-expanded image gold NLL on new disjoint validation windows; no fitting',
                  starts=manifest['starts'], predictions=len(rows)*255,
                  fixture_sha256=sha(path), fixture_manifest_sha256=sha(path.with_suffix('.json')),
                  script_sha256=sha(Path(__file__)), model_source_sha256=sha(MODEL / 'source.json'),
                  source_manifest_sha256=sha(source_manifest), arms=arms,
                  q4_minus_ternary=float(delta.mean()),
                  paired_standard_error=float(delta.std(ddof=1)/np.sqrt(len(delta))),
                  wins=int((delta < 0).sum()))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'arms'}), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('freeze', 'score'))
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--count', type=int, default=16)
    args = parser.parse_args()
    if args.mode == 'freeze':
        freeze(args.fixture, args.count)
    elif args.output is not None:
        score(args.fixture, args.output)
    else:
        parser.error('score requires --output')


if __name__ == '__main__':
    main()
