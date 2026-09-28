#!/usr/bin/env python3
"""Independent text and complete-model comparison for another scale-only continuation."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
TERNARY = HERE.parent
spec = importlib.util.spec_from_file_location('fresh_duration_replay', TERNARY / 'fresh-duration/run.py')
replay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(replay)
replay.OUT = replay.ROOT / 'fresh-duration32-eval'
replay.SOURCE = 'fresh-duration16'
replay.CANDIDATE = 'fresh-duration32'


def freeze():
    from transformers import AutoTokenizer
    out = replay.OUT
    out.mkdir(parents=True, exist_ok=True)
    target = out / 'tokens.npz'
    if target.exists():
        raise FileExistsError(target)
    corpus = replay.DATA / 'corpus/wikitext-2-raw/test.txt'
    tokenizer = AutoTokenizer.from_pretrained(replay.DATA / 'models/qwen3-0.6b', local_files_only=True)
    tokenizer.model_max_length = 10**12
    ids = np.asarray(tokenizer(corpus.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32)
    prior = json.loads((replay.DATA / 'fixtures/qwen3-0.6b-wikitext/manifest.json').read_text())
    occupied = [(s, s + prior['length']) for s in prior['window_starts']['test']]
    for location in (replay.DATA / 'fresh-evaluation/manifest.json',
                     replay.ROOT / 'tokens.json',
                     replay.ROOT / 'scale-extrapolation/tokens.json',
                     replay.ROOT / 'fresh-recovery/tokens.json',
                     replay.ROOT / 'fresh-duration/tokens.json'):
        record = json.loads(location.read_text())
        if 'windows' in record:
            for key, window in record['windows'].items():
                if key.startswith('test'):
                    occupied.extend((s, s + window.get('length', record.get('length'))) for s in window['starts'])
        else:
            occupied.extend((s, s + record['length']) for s in record['starts'])
    eligible = [s for s in range(0, len(ids) - 255, 256)
                if all(s >= end or s + 256 <= start for start, end in occupied)]
    starts = sorted(np.random.default_rng(2026092432).choice(eligible, 16, replace=False).tolist())
    np.savez(target, test=np.stack([ids[s:s+256] for s in starts]))
    receipt = dict(starts=starts, length=256, source_sha256=replay.sha(corpus),
                   tokens_sha256=replay.sha(target), excluded=occupied,
                   split='first 8 selection, last 8 held, frozen before training', seed=2026092432,
                   wrapper_sha256=replay.sha(__file__))
    (out / 'tokens.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(dict(eligible=len(eligible), starts=starts, sha256=replay.sha(target))))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('command', choices=['freeze', 'evaluate', 'summarize'])
    p.add_argument('--name', choices=[replay.SOURCE, replay.CANDIDATE])
    p.add_argument('--offset', type=int, choices=[0, 8])
    a = p.parse_args()
    if a.command == 'freeze':
        freeze()
    elif a.command == 'evaluate':
        if a.name is None or a.offset is None:
            p.error('evaluate requires --name and --offset')
        replay.evaluate(a.name, a.offset)
    else:
        replay.summarize()
        summary = replay.OUT / 'summary.json'
        record = json.loads(summary.read_text())
        record['comparison_wrapper_sha256'] = replay.sha(__file__)
        record['candidate_page_receipt_sha256'] = replay.sha(replay.ROOT / 'fresh-duration32-page-256/receipt.json')
        record['source_page_receipt_sha256'] = replay.sha(replay.ROOT / 'fresh-duration-page-256/receipt.json')
        summary.write_text(json.dumps(record, indent=2) + '\n')
