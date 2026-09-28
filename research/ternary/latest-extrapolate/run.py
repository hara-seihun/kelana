#!/usr/bin/env python3
"""Frozen complete-image extrapolation of the latest Qwen3-0.6B scale update."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
TERNARY = HERE.parent
DATA = Path('/path/to/workspace/data/kelana-subbit')
ROOT = DATA / 'ternary'
OUT = ROOT / 'latest-extrapolate'
EARLY, LATE, CANDIDATE = 'fresh-duration16', 'fresh-duration32', 'latest-extrapolate-1.5'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def freeze():
    from transformers import AutoTokenizer
    OUT.mkdir(exist_ok=True)
    target = OUT / 'tokens.npz'
    if target.exists():
        raise FileExistsError(target)
    corpus = DATA / 'corpus/wikitext-2-raw/test.txt'
    tokenizer = AutoTokenizer.from_pretrained(DATA / 'models/qwen3-0.6b', local_files_only=True)
    tokenizer.model_max_length = 10**12
    ids = np.asarray(tokenizer(corpus.read_text(), add_special_tokens=False)['input_ids'], dtype=np.int32)
    first = json.loads((DATA / 'fixtures/qwen3-0.6b-wikitext/manifest.json').read_text())
    occupied = [(s, s + first['length']) for s in first['window_starts']['test']]
    for location in (DATA / 'fresh-evaluation/manifest.json', ROOT / 'tokens.json',
                     ROOT / 'scale-extrapolation/tokens.json', ROOT / 'fresh-recovery/tokens.json',
                     ROOT / 'fresh-duration/tokens.json', ROOT / 'fresh-duration32-eval/tokens.json'):
        rec = json.loads(location.read_text())
        if 'windows' in rec:
            for key, window in rec['windows'].items():
                if key.startswith('test'):
                    occupied.extend((s, s + window.get('length', rec.get('length'))) for s in window['starts'])
        else:
            occupied.extend((s, s + rec['length']) for s in rec['starts'])
    eligible = [s for s in range(0, len(ids) - 255, 256)
                if all(s >= end or s + 256 <= start for start, end in occupied)]
    starts = sorted(np.random.default_rng(2026092441).choice(eligible, 16, replace=False).tolist())
    np.savez(target, test=np.stack([ids[s:s+256] for s in starts]))
    rec = dict(starts=starts, length=256, source_sha256=sha(corpus), tokens_sha256=sha(target),
               excluded=occupied, eligible=len(eligible), seed=2026092441,
               split='first eight select fixed 1.5 arm; last eight withheld until selection', source_sha256_script=sha(__file__))
    (OUT / 'tokens.json').write_text(json.dumps(rec, indent=2) + '\n')
    print(json.dumps(dict(starts=starts, eligible=len(eligible))))


def build():
    early, late, output = (ROOT / EARLY, ROOT / LATE, ROOT / CANDIDATE)
    output.mkdir(exist_ok=False)
    before = json.loads((early / 'manifest.json').read_text())
    after = json.loads((late / 'manifest.json').read_text())
    assert before['complete'] and after['complete'] and len(before['matrices']) == len(after['matrices']) == 197
    assert before['payload_bytes'] == after['payload_bytes'] == 128678649
    assert sha(early/'norms.npz') == sha(late/'norms.npz')
    older = {r['key']: r for r in before['matrices']}
    records = []
    changed = 0
    for r in after['matrices']:
        name = r['key'].replace('.', '_') + '.npz'
        b, a = early/name, late/name
        assert sha(b) == older[r['key']]['sha256'] and sha(a) == r['sha256']
        with np.load(b) as z: first = {k: z[k] for k in z.files}
        with np.load(a) as z: last = {k: z[k] for k in z.files}
        assert set(first) == set(last)
        for key in set(first) - {'scales'}:
            assert np.array_equal(first[key], last[key]), (r['key'], key)
        proposed = 1.5*last['scales'].astype(np.float32) - .5*first['scales'].astype(np.float32)
        assert np.isfinite(proposed).all() and np.abs(proposed).max() < 65504
        last['scales'] = proposed.astype(np.float16)
        changed += int(np.count_nonzero(last['scales'].view(np.uint16) != np.asarray(first['scales']).view(np.uint16)))
        np.savez(output/name, **last)
        new = dict(r, sha256=sha(output/name), payload_bytes=sum(x.nbytes for x in last.values()), file_bytes=(output/name).stat().st_size)
        (output/name).with_suffix('.json').write_text(json.dumps(new, indent=2)+'\n')
        records.append(new)
    (output/'norms.npz').write_bytes((late/'norms.npz').read_bytes())
    manifest = dict(after, matrices=records)
    assert manifest['payload_bytes'] == sum(r['payload_bytes'] for r in records) + (after['payload_bytes'] - sum(r['payload_bytes'] for r in after['matrices']))
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    receipt = dict(early_manifest_sha256=sha(early/'manifest.json'), late_manifest_sha256=sha(late/'manifest.json'),
                   candidate_manifest_sha256=sha(output/'manifest.json'), source_sha256=sha(__file__),
                   changed_scale_words=changed, raw_bytes=manifest['payload_bytes'], raw_bpw=manifest['bpw'])
    (output/'construction.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt))


def evaluate(name, offset):
    import torch
    import torch.nn.functional as F
    sys.path.insert(0, str(TERNARY))
    from pilot import expanded, load_model
    torch.set_num_threads(4)
    torch.backends.cuda.matmul.allow_tf32 = False
    image = ROOT / name
    manifest = json.loads((image/'manifest.json').read_text())
    assert manifest['complete'] and manifest['matrix_count'] == 197
    model = load_model()
    with torch.no_grad():
        for record in manifest['matrices']:
            path = image / (record['key'].replace('.', '_') + '.npz')
            assert sha(path) == record['sha256']
            model.get_parameter(record['key']).copy_(expanded(path))
    assert model.lm_head.weight.data_ptr() == model.model.embed_tokens.weight.data_ptr()
    with np.load(OUT/'tokens.npz') as z:
        rows = z['test'][offset:offset+8].copy()
    assert len(rows) == 8
    losses = []
    with torch.inference_mode():
        for row in rows:
            tokens = torch.as_tensor(row, dtype=torch.long, device='cuda')[None]
            logits = model(tokens, use_cache=False).logits[:, :-1].float()
            losses.append(float(F.cross_entropy(logits.reshape(-1, logits.shape[-1]), tokens[:, 1:].reshape(-1), reduction='sum')) / 255)
    receipt = dict(name=name, offset=offset, per_window_nll=losses, mean_nll=float(np.mean(losses)),
                   image_manifest_sha256=sha(image/'manifest.json'), fixture_sha256=sha(OUT/'tokens.npz'),
                   source_sha256=sha(__file__), bpw=manifest['bpw'],
                   contract='full 197-matrix BF16-expanded model; 255 next-token predictions/window; no native timing')
    target = OUT/f'{name}-{offset}.json'
    if target.exists():
        raise FileExistsError(target)
    target.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt), flush=True)


def summarize():
    names = (LATE, CANDIDATE)
    fixture = json.loads((OUT/'tokens.json').read_text())
    assert fixture['tokens_sha256'] == sha(OUT/'tokens.npz')
    scores = {}
    hashes = {}
    for name in names:
        scores[name] = []
        for offset in (0, 8):
            path = OUT/f'{name}-{offset}.json'
            r = json.loads(path.read_text())
            assert r['fixture_sha256'] == fixture['tokens_sha256'] and r['image_manifest_sha256'] == sha(ROOT/name/'manifest.json')
            scores[name].extend(r['per_window_nll'])
            hashes[path.name] = sha(path)
    delta = np.asarray(scores[LATE]) - np.asarray(scores[CANDIDATE])
    receipt = dict(source=LATE, candidate=CANDIDATE, source_manifest_sha256=sha(ROOT/LATE/'manifest.json'),
                   candidate_manifest_sha256=sha(ROOT/CANDIDATE/'manifest.json'), construction_sha256=sha(ROOT/CANDIDATE/'construction.json'),
                   fixture_sha256=fixture['tokens_sha256'], source_sha256=sha(__file__), evaluation_sha256=hashes,
                   selection_nll=[float(np.mean(scores[n][:8])) for n in names],
                   held_nll=[float(np.mean(scores[n][8:])) for n in names],
                   held_paired_improvement=float(np.mean(delta[8:])),
                   held_paired_standard_error=float(np.std(delta[8:], ddof=1)/np.sqrt(8)),
                   held_improving_windows=int(np.sum(delta[8:] > 0)), per_window_improvement=delta.tolist(),
                   raw_bytes=128678649, raw_bpw=json.loads((ROOT/LATE/'manifest.json').read_text())['bpw'])
    (OUT/'summary.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('command', choices=['freeze', 'build', 'evaluate', 'summarize'])
    p.add_argument('--name', choices=[LATE, CANDIDATE])
    p.add_argument('--offset', type=int, choices=[0, 8])
    a = p.parse_args()
    if a.command == 'freeze': freeze()
    elif a.command == 'build': build()
    elif a.command == 'evaluate':
        if a.name is None or a.offset is None: p.error('evaluate needs --name and --offset')
        evaluate(a.name, a.offset)
    else: summarize()
