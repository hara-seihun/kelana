#!/usr/bin/env python3
"""Freeze disjoint Qwen3-0.6B text, replay complete packed images, reconcile rate/quality."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = Path('/path/to/workspace/data/kelana-subbit/ternary')
DATA = ROOT.parent
OUT = ROOT / 'fresh-duration'
SOURCE = 'fresh-scale8'
CANDIDATE = 'fresh-duration16'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def freeze():
    from transformers import AutoTokenizer
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / 'tokens.npz'
    if target.exists():
        raise FileExistsError(target)
    corpus = DATA / 'corpus/wikitext-2-raw/test.txt'
    tokenizer = AutoTokenizer.from_pretrained(DATA / 'models/qwen3-0.6b', local_files_only=True)
    tokenizer.model_max_length = 10**12
    ids = np.asarray(tokenizer(corpus.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32)
    previous = json.loads((DATA / 'fixtures/qwen3-0.6b-wikitext/manifest.json').read_text())
    fresh = json.loads((DATA / 'fresh-evaluation/manifest.json').read_text())
    pilot = json.loads((ROOT / 'tokens.json').read_text())
    extrap = json.loads((ROOT / 'scale-extrapolation/tokens.json').read_text())
    newest = json.loads((ROOT / 'fresh-recovery/tokens.json').read_text())
    occupied = [(s, s + previous['length']) for s in previous['window_starts']['test']]
    for key, record in fresh['windows'].items():
        if key.startswith('test_'):
            occupied.extend((s, s + record['length']) for s in record['starts'])
    occupied.extend((s, s + pilot['length']) for s in pilot['windows']['test']['starts'])
    for record in (extrap, newest):
        occupied.extend((s, s + record['length']) for s in record['starts'])
    eligible = [s for s in range(0, len(ids) - 255, 256)
                if all(s >= end or s + 256 <= start for start, end in occupied)]
    starts = sorted(np.random.default_rng(2026092431).choice(eligible, 16, replace=False).tolist())
    np.savez(target, test=np.stack([ids[s:s+256] for s in starts]))
    receipt = dict(starts=starts, length=256, source_sha256=sha(corpus), tokens_sha256=sha(target),
                   excluded=occupied, split='first 8 selection, last 8 held, frozen before evaluation', seed=2026092431)
    (OUT / 'tokens.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(dict(eligible=len(eligible), starts=starts, sha256=sha(target))))


def evaluate(name, offset):
    import torch
    import torch.nn.functional as F
    sys.path.insert(0, str(HERE.parent))
    from pilot import expanded, load_model
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    image = ROOT / name
    manifest = json.loads((image / 'manifest.json').read_text())
    assert manifest['complete'] and manifest['matrix_count'] == 197
    model = load_model()
    with torch.no_grad():
        for record in manifest['matrices']:
            path = image / (record['key'].replace('.', '_') + '.npz')
            assert sha(path) == record['sha256']
            model.get_parameter(record['key']).copy_(expanded(path))
    assert model.lm_head.weight.data_ptr() == model.model.embed_tokens.weight.data_ptr()
    with np.load(OUT / 'tokens.npz') as z:
        rows = z['test'][offset:offset+8].copy()
    assert len(rows) == 8
    losses = []
    with torch.inference_mode():
        for row in rows:
            ids = torch.as_tensor(row, dtype=torch.long, device='cuda')[None]
            logits = model(ids, use_cache=False).logits[:, :-1].float()
            losses.append(float(F.cross_entropy(logits.reshape(-1, logits.shape[-1]),
                                                ids[:, 1:].reshape(-1), reduction='sum')) / 255)
    receipt = dict(name=name, offset=offset, per_window_nll=losses, mean_nll=float(np.mean(losses)),
                   image_manifest_sha256=sha(image / 'manifest.json'), fixture_sha256=sha(OUT / 'tokens.npz'),
                   script_sha256=sha(__file__), bpw=manifest['bpw'])
    target = OUT / f'{name}-{offset}.json'
    if target.exists():
        raise FileExistsError(target)
    target.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt), flush=True)


def summarize():
    fixture = json.loads((OUT / 'tokens.json').read_text())
    assert fixture['tokens_sha256'] == sha(OUT / 'tokens.npz')
    before = json.loads((ROOT / SOURCE / 'manifest.json').read_text())
    after = json.loads((ROOT / CANDIDATE / 'manifest.json').read_text())
    assert before['payload_bytes'] == after['payload_bytes'] == 128678649
    assert sha(ROOT / SOURCE / 'norms.npz') == sha(ROOT / CANDIDATE / 'norms.npz')
    old = {r['key']: r for r in before['matrices']}
    changed = 0
    for rec in after['matrices']:
        left = ROOT / SOURCE / (rec['key'].replace('.', '_') + '.npz')
        right = ROOT / CANDIDATE / left.name
        assert sha(left) == old[rec['key']]['sha256'] and sha(right) == rec['sha256']
        with np.load(left) as a, np.load(right) as b:
            assert set(a.files) == set(b.files)
            for key in set(a.files) - {'scales'}:
                assert np.array_equal(a[key], b[key]), (rec['key'], key)
            changed += int(np.count_nonzero(a['scales'].view(np.uint16) != b['scales'].view(np.uint16)))
    arms, receipt_hashes = {}, {}
    for name in (SOURCE, CANDIDATE):
        arms[name] = []
        for offset in (0, 8):
            path = OUT / f'{name}-{offset}.json'
            r = json.loads(path.read_text())
            assert r['fixture_sha256'] == fixture['tokens_sha256']
            assert r['image_manifest_sha256'] == sha(ROOT / name / 'manifest.json')
            arms[name] += r['per_window_nll']
            receipt_hashes[path.name] = sha(path)
    delta = np.asarray(arms[SOURCE]) - np.asarray(arms[CANDIDATE])
    receipt = dict(source=SOURCE, candidate=CANDIDATE, source_manifest_sha256=sha(ROOT / SOURCE / 'manifest.json'),
                   candidate_manifest_sha256=sha(ROOT / CANDIDATE / 'manifest.json'),
                   training_sha256=sha(ROOT / CANDIDATE / 'training.json'),
                   fixture_sha256=fixture['tokens_sha256'], script_sha256=sha(__file__),
                   evaluation_receipts=receipt_hashes, changed_fp16_scale_words=changed,
                   unchanged_codes_signs_shapes_norms=True, raw_payload_bytes=before['payload_bytes'],
                   bpw=before['bpw'], selection_nll=[float(np.mean(arms[n][:8])) for n in (SOURCE, CANDIDATE)],
                   held_nll=[float(np.mean(arms[n][8:])) for n in (SOURCE, CANDIDATE)],
                   held_paired_improvement=float(np.mean(delta[8:])),
                   held_paired_standard_error=float(np.std(delta[8:], ddof=1) / np.sqrt(8)),
                   held_improving_windows=int(np.count_nonzero(delta[8:] > 0)),
                   per_window_improvement=delta.tolist())
    (OUT / 'summary.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['freeze', 'evaluate', 'summarize'])
    parser.add_argument('--name', choices=[SOURCE, CANDIDATE])
    parser.add_argument('--offset', type=int, choices=[0, 8])
    args = parser.parse_args()
    if args.command == 'freeze':
        freeze()
    elif args.command == 'evaluate':
        if args.name is None or args.offset is None:
            parser.error('evaluate requires --name and --offset')
        evaluate(args.name, args.offset)
    else:
        summarize()


if __name__ == '__main__':
    main()
