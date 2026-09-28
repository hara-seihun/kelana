#!/usr/bin/env python3
"""CPU-only token-copy proposal study on the held greedy Qwen fixtures."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from time import perf_counter

import numpy as np
import torch
from transformers import AutoTokenizer

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from candidates import SpanIndex, copy_tree

DATA = Path('/path/to/workspace/data/kelana-speculative')
CORPUS = Path('/path/to/workspace/data/kelana-subbit/corpus/wikitext-2-raw')
MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b')
STORE = DATA / 'retrieved-spans'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def tokenizer():
    tok = AutoTokenizer.from_pretrained(MODEL, local_files_only=True)
    tok.model_max_length = 10**12
    return tok


def train_index(tok):
    STORE.mkdir(parents=True, exist_ok=True)
    source = CORPUS / 'train.txt'
    cache = STORE / 'train-token-ids.npy'
    if not cache.exists():
        np.save(cache, np.asarray(tok(source.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32))
    assert sha(source) == json.loads((DATA / 'train.json').read_text())['corpus_sha256']
    return SpanIndex(np.load(cache)), cache


def model_proposals():
    spec = importlib.util.spec_from_file_location('direct_producer', HERE.parent / 'direct-producer' / 'experiment.py')
    direct = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(direct)
    state = torch.load(DATA/'direct-producer/direct-s200.pt', weights_only=True, map_location='cpu')
    model = direct.Direct()
    model.load_state_dict(state)
    model.eval()
    return direct, model


def score(nodes, target):
    lookup = set(nodes)
    return next((j for j in range(1, 7) if target[:j] not in lookup), 7)


def evaluate(split, with_learned):
    torch.set_num_threads(4)
    tok = tokenizer()
    index, cache = train_index(tok)
    fixture_path = DATA / f'{split}-greedy.pt'
    receipt_path = DATA / f'{split}-greedy.json'
    fixture = torch.load(fixture_path, weights_only=True, map_location='cpu')
    starts = json.loads(receipt_path.read_text())['starts']
    assert len(starts) == len(fixture['future']) == 32
    raw = CORPUS / f'{split}.txt'
    ids = tok(raw.read_text(), add_special_tokens=False)['input_ids']
    assert sha(raw) == json.loads(receipt_path.read_text())['corpus_sha256']
    direct = model = None
    if with_learned:
        direct, model = model_proposals()
    records = []
    begun = perf_counter()
    with torch.inference_mode():
        for row, (start, labels) in enumerate(zip(starts, fixture['future'])):
            prompt = ids[start:start + 64]
            target = tuple(map(int, labels.tolist()))
            assert int(fixture['anchor'][row]) == prompt[-1]
            found, stats = index.propose(prompt, target[0])
            learned = []
            if model is not None:
                vocab = model.vocabulary.tolist()
                root_lookup = {id_: i for i, id_ in enumerate(vocab)}
                root_code = root_lookup.get(target[0], direct.VOCAB)
                ordered, _, _, _ = direct.proposed(model, fixture['hidden'][row].float(), root_code, False)
                learned = [(target[0],) + tuple(vocab[i] for i in path[1:]) for path in ordered]
            scores = {}
            for budget in (6, 18):
                scores[str(budget)] = {
                    'copy_chain': score(copy_tree(target[0], found[:1], budget), target),
                    'copy': score(copy_tree(target[0], found, budget), target),
                    'copy_then_direct': score(copy_tree(target[0], found, budget, learned=learned), target) if learned else None,
                    'copy_edge_then_direct': score(copy_tree(target[0], [{'path': found[0]['path'][:2]}] if found else [], budget, learned=learned), target) if learned else None,
                    'direct': score(learned[:budget], target) if learned else None,
                }
            records.append({'start': start, 'retained_first': target[0], 'target': target,
                            'candidate_count': len(found),
                            'candidate_prefix_lengths': [p['matched_prefix'] for p in found],
                            'candidate_sources': [p['source'] for p in found],
                            'root_following_target_in_candidates': any(p['path'][:2] == target[:2] for p in found),
                            'stats': vars(stats), 'scores': scores})
    output = {
        'split': split, 'fixture_sha256': sha(fixture_path), 'source_sha256': sha(__file__),
        'candidate_source_sha256': sha(HERE/'candidates.py'),
        'train_corpus_sha256': sha(CORPUS/'train.txt'), 'split_corpus_sha256': sha(raw),
        'train_token_cache_sha256': sha(cache), 'train_tokens': len(index.tokens),
        'index_bytes': index.bytes, 'index_build_seconds': index.build_seconds,
        'train_token_cache_bytes': cache.stat().st_size, 'search_max_postings': 4096,
        'search_max_distinct_candidates': 8, 'prefix_window_tokens': 64,
        'learned_checkpoint_sha256': sha(DATA/'direct-producer/direct-s200.pt') if model else None,
        'seconds_evaluation_excluding_tokenization_and_index': perf_counter() - begun,
        'rows': records,
        'means': {str(b): {arm: round(sum(r['scores'][str(b)][arm] for r in records)/len(records), 5)
                           if all(r['scores'][str(b)][arm] is not None for r in records) else None
                           for arm in ('copy_chain', 'copy', 'copy_then_direct', 'copy_edge_then_direct', 'direct')} for b in (6, 18)},
    }
    path = HERE / f'{split}.json'
    path.write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({'path': str(path), 'means': output['means'],
                      'root_following_hits': sum(r['root_following_target_in_candidates'] for r in records),
                      'index_build_seconds': index.build_seconds,
                      'evaluation_seconds': output['seconds_evaluation_excluding_tokenization_and_index']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('split', choices=('validation', 'test'))
    parser.add_argument('--with-learned', action='store_true')
    args = parser.parse_args()
    evaluate(args.split, args.with_learned)
