#!/usr/bin/env python3
"""Check every candidate against the committed scalar reference and price the query."""
import gc
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
from time import perf_counter
import tracemalloc
import types

import numpy as np
import torch
from transformers import AutoTokenizer

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DATA = Path('/path/to/workspace/data/kelana-speculative')
CORPUS = Path('/path/to/workspace/data/kelana-subbit/corpus/wikitext-2-raw')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
REFERENCE = '1db86dcf7cd6c53ed5ca155bf4d5e55ebd20d60f'
sys.path.insert(0, str(HERE))
from candidates import SpanIndex


def sha(data):
    return hashlib.sha256(data).hexdigest()


def reference_module():
    raw = subprocess.check_output(['git', 'show', f'{REFERENCE}:research/speculative-maps/retrieved-spans/candidates.py'], cwd=ROOT)
    module = types.ModuleType('scalar_span_reference')
    sys.modules[module.__name__] = module
    exec(compile(raw, REFERENCE + '/candidates.py', 'exec'), module.__dict__)
    return module, sha(raw)


def queries():
    tok = AutoTokenizer.from_pretrained(MODEL, local_files_only=True)
    tok.model_max_length = 10**12
    result = []
    for split in ('validation', 'test'):
        text = tok((CORPUS / f'{split}.txt').read_text(), add_special_tokens=False)['input_ids']
        starts = json.loads((DATA / f'{split}-greedy.json').read_text())['starts']
        targets = torch.load(DATA / f'{split}-greedy.pt', weights_only=True, map_location='cpu')['future'][:, 0]
        result.extend((text[start:start+64], int(root)) for start, root in zip(starts, targets))
    return result


def main():
    reference, old_sha = reference_module()
    tokens = np.load(DATA / 'retrieved-spans/train-token-ids.npy')
    old, new = reference.SpanIndex(tokens), SpanIndex(tokens)
    cases = queries()
    for prompt, first in cases:
        for width, postings in ((8, 4096), (16, 4096), (1, 4096), (8, 64)):
            a, stats_a = old.propose(prompt, first, max_matches=width, max_postings=postings)
            b, stats_b = new.propose(prompt, first, max_matches=width, max_postings=postings)
            assert a == b, (prompt, first, width, postings, a, b)
            assert (stats_a.postings_examined, stats_a.tokens_compared) == (stats_b.postings_examined, stats_b.tokens_compared)
    for prompt, first in (([1, 4, 1, 4, 1], 4), ([4, 4, 4, 4], 4), ([8, 9, 8], 9)):
        for tokenset in ([4] * 60, [1, 4] * 30, [8, 9, 8, 4] * 15):
            a = reference.SpanIndex(tokenset).propose(prompt, first, horizon=2)[0]
            b = SpanIndex(tokenset).propose(prompt, first, horizon=2)[0]
            assert a == b, (a, b)
    trials = {'scalar': [], 'vectorized': []}
    for repetition in range(8):
        for name, index in ((('scalar', old), ('vectorized', new)) if repetition % 2 else (('vectorized', new), ('scalar', old))):
            begun = perf_counter()
            for prompt, first in cases:
                index.propose(prompt, first)
            trials[name].append(perf_counter() - begun)
    peaks = {}
    for name, index in (('scalar', old), ('vectorized', new)):
        gc.collect()
        tracemalloc.start()
        index.propose(*cases[0])
        peaks[name] = tracemalloc.get_traced_memory()[1]
        tracemalloc.stop()
    record = {
        'reference_commit': REFERENCE, 'reference_source_sha256': old_sha,
        'new_source_sha256': sha((HERE / 'candidates.py').read_bytes()),
        'train_cache_sha256': sha((DATA / 'retrieved-spans/train-token-ids.npy').read_bytes()),
        'queries': len(cases), 'matched_calls': len(cases)*4+9,
        'repetitions': 8, 'paired_seconds_per_64_queries': trials,
        'mean_ms_per_query': {name: 1000*sum(values)/len(values)/len(cases) for name, values in trials.items()},
        'peak_tracemalloc_bytes_single_first_query': peaks, 'resident_index_bytes_each': new.bytes,
        'max_postings': 4096, 'max_results': 8,
    }
    (HERE / 'query-benchmark.json').write_text(json.dumps(record, indent=2)+'\n')
    print(json.dumps({k: record[k] for k in ('matched_calls', 'mean_ms_per_query', 'peak_tracemalloc_bytes_single_first_query')}))


if __name__ == '__main__':
    main()
