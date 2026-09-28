#!/usr/bin/env python3
"""Frozen complete-model comparison of fresh scale and bounded code/scale recovery."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
TERNARY = HERE.parent
ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary')
OUT = ROOT / 'coupled-fresh-eval'
SOURCE = 'fresh-duration32'
SCALE = 'coupled-fresh-scale'
COUPLED = 'coupled-fresh-codes'

spec = importlib.util.spec_from_file_location('ternary_complete_evaluator', TERNARY / 'fresh-duration/run.py')
evaluator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evaluator)
evaluator.OUT = OUT


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def freeze():
    from transformers import AutoTokenizer
    corpus = ROOT.parent / 'corpus/wikitext-2-raw/test.txt'
    tokenizer = AutoTokenizer.from_pretrained(ROOT.parent / 'models/qwen3-0.6b', local_files_only=True)
    tokenizer.model_max_length = 10**12
    ids = np.asarray(tokenizer(corpus.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32)
    sources = [ROOT.parent / 'fixtures/qwen3-0.6b-wikitext/manifest.json',
               ROOT.parent / 'fresh-evaluation/manifest.json'] + [ROOT / p for p in (
                   'tokens.json', 'scale-extrapolation/tokens.json', 'fresh-recovery/tokens.json',
                   'fresh-duration/tokens.json', 'fresh-duration32-eval/tokens.json',
                   'latest-extrapolate/tokens.json')]
    occupied = []
    for source in sources:
        record = json.loads(source.read_text())
        if 'window_starts' in record:
            occupied.extend((s, s + record['length']) for s in record['window_starts']['test'])
        elif 'windows' in record:
            for key, part in record['windows'].items():
                if key.startswith('test'):
                    occupied.extend((s, s + part.get('length', record.get('length'))) for s in part['starts'])
        else:
            occupied.extend((s, s + record['length']) for s in record['starts'])
    eligible = [s for s in range(0, len(ids) - 255, 256)
                if all(s >= end or s + 256 <= start for start, end in occupied)]
    starts = sorted(np.random.default_rng(2026092457).choice(eligible, 16, replace=False).tolist())
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / 'tokens.npz'
    if target.exists():
        raise FileExistsError(target)
    np.savez(target, test=np.stack([ids[s:s + 256] for s in starts]))
    record = dict(starts=starts, length=256, eligible=len(eligible), seed=2026092457,
                  excluded_sources={str(p): sha(p) for p in sources}, excluded=occupied,
                  split='first 8 selection; last 8 held; frozen before image training',
                  corpus_sha256=sha(corpus), fixture_sha256=sha(target), source_sha256=sha(__file__))
    (OUT / 'tokens.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(dict(starts=starts, eligible=len(eligible), fixture_sha256=sha(target))))


def summarize():
    fixture = json.loads((OUT / 'tokens.json').read_text())
    assert fixture['fixture_sha256'] == sha(OUT / 'tokens.npz')
    records = {}
    for name in (SOURCE, SCALE, COUPLED):
        image = ROOT / name
        manifest = json.loads((image / 'manifest.json').read_text())
        assert manifest['complete'] and manifest['matrix_count'] == 197
        per_window = []
        for offset in (0, 8):
            path = OUT / f'{name}-{offset}.json'
            rec = json.loads(path.read_text())
            assert rec['fixture_sha256'] == fixture['fixture_sha256']
            assert rec['image_manifest_sha256'] == sha(image / 'manifest.json')
            per_window.extend(rec['per_window_nll'])
        page_name = {SOURCE: 'fresh-duration32-code-page-16384',
                     SCALE: 'coupled-fresh-scale-code-page',
                     COUPLED: 'coupled-fresh-codes-code-page'}[name]
        page_path = ROOT / page_name / 'receipt.json'
        page = json.loads(page_path.read_text())
        assert page['source_manifest_sha256'] == sha(image / 'manifest.json')
        assert page['page_bytes'] == 16384 and page['code_pages'] == 7360
        records[name] = dict(per_window=per_window, manifest_sha256=sha(image / 'manifest.json'),
                             raw_payload_bytes=manifest['payload_bytes'], bpw=manifest['bpw'],
                             paid_payload_bytes=page['paid_payload_bytes'], paid_bpw=page['paid_bpw'],
                             paid_page_receipt_sha256=sha(page_path),
                             training_sha256=sha(image / 'training.json') if name != SOURCE else None)
    assert len({r['raw_payload_bytes'] for r in records.values()}) == 1
    a = np.array(records[SOURCE]['per_window'])
    b = np.array(records[SCALE]['per_window'])
    c = np.array(records[COUPLED]['per_window'])
    def contrast(x, y):
        d = x - y
        return dict(selection=[float(np.mean(x[:8])), float(np.mean(y[:8]))],
                    held=[float(np.mean(x[8:])), float(np.mean(y[8:]))],
                    held_gain=float(np.mean(d[8:])), held_se=float(np.std(d[8:], ddof=1) / np.sqrt(8)),
                    held_wins=int(np.count_nonzero(d[8:] > 0)))
    receipt = dict(fixture_sha256=fixture['fixture_sha256'], script_sha256=sha(__file__), images=records,
                   scale_vs_source=contrast(a, b), coupled_vs_scale=contrast(b, c),
                   coupled_vs_source=contrast(a, c))
    (OUT / 'summary.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=('freeze', 'evaluate', 'summarize'))
    p.add_argument('--name', choices=(SOURCE, SCALE, COUPLED))
    p.add_argument('--offset', type=int, choices=(0, 8))
    args = p.parse_args()
    if args.action == 'freeze':
        freeze()
    elif args.action == 'evaluate':
        if args.name is None or args.offset is None:
            p.error('evaluate requires --name and --offset')
        evaluator.evaluate(args.name, args.offset)
    else:
        summarize()
