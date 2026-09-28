#!/usr/bin/env python3
"""Check whether token IDs are exact keys for the paid layer-0 narrow-V dictionary."""
import hashlib
import json
from pathlib import Path

import numpy as np

ROOT = Path('/path/to/workspace/data/kelana-subbit')
HERE = Path(__file__).resolve().parent


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for part in iter(lambda: stream.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def evaluate(layer, split):
    capture_path = ROOT / 'full-model/capture' / f'layer{layer:02d}.npz'
    token_path = ROOT / 'fixtures/qwen3-0.6b-wikitext/tokens.npz'
    parent_path = ROOT / 'value-label-histogram' / f'layer{layer:02d}.json'
    with np.load(capture_path) as captured, np.load(token_path) as fixture:
        tokens = fixture[split].copy()
        # Raw BF16 bits preserve the complete 1024-dimensional equality question.
        inputs = captured[f'{split}_qkv'].copy().reshape(tokens.shape + (1024,))
    parent = json.loads(parent_path.read_text())
    assert digest(capture_path) == parent['capture_sha256']
    windows = []
    for token_row, input_row in zip(tokens, inputs):
        first_token = {}
        first_input = {}
        first_vector = {}
        token_labels = []
        input_labels = []
        false_hits = 0
        for token, vector in zip(token_row, input_row):
            token = int(token)
            bits = vector.tobytes()
            if token in first_vector and first_vector[token] != bits:
                false_hits += 1
            first_vector.setdefault(token, bits)
            token_labels.append(first_token.setdefault(token, len(first_token)))
            input_labels.append(first_input.setdefault(bits, len(first_input)))
        mismatches = sum(a != b for a, b in zip(token_labels, input_labels))
        unique = len(first_token)
        windows.append(dict(unique_tokens=unique, unique_inputs=len(first_input),
                            repeated_tokens=256-unique, false_token_hits=false_hits,
                            first_seen_label_mismatches=mismatches,
                            token_id_sha256=hashlib.sha256(token_row.tobytes()).hexdigest(),
                            input_bits_sha256=hashlib.sha256(input_row.tobytes()).hexdigest(),
                            label_sha256=hashlib.sha256(np.asarray(token_labels, dtype=np.uint8).tobytes()).hexdigest()))
    assert split != 'validation' or [w['unique_inputs'] for w in windows] == parent['distinct_qkv_inputs_per_window']
    result = dict(layer=layer, split=split, windows=windows,
                  repeated_tokens=sum(w['repeated_tokens'] for w in windows),
                  false_token_hits=sum(w['false_token_hits'] for w in windows),
                  label_mismatches=sum(w['first_seen_label_mismatches'] for w in windows),
                  code_row_bytes=224, paid_right_terms_per_new_value=8*28*1024,
                  saved_right_terms=sum(w['repeated_tokens'] - w['false_token_hits'] for w in windows)*8*28*1024,
                  source_sha256=digest(HERE / 'measure.py'), capture_sha256=digest(capture_path),
                  token_fixture_sha256=digest(token_path), parent_sha256=digest(parent_path),
                  domain='Separate 256-token Qwen3-0.6B original-producer windows; first-seen token-ID table versus raw BF16 QKV input equality. No inference of native time from term count.')
    out = ROOT / 'value-token-id-cache' / f'layer{layer:02d}-{split}.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + '\n')
    print(out, [(w['unique_tokens'], w['unique_inputs'], w['false_token_hits'], w['first_seen_label_mismatches']) for w in windows])


if __name__ == '__main__':
    for layer in (0, 14):
        for split in ('train', 'validation'):
            evaluate(layer, split)
