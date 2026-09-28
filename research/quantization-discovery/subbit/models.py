#!/usr/bin/env python3
"""Fetch the pinned small-model and corpus inputs for the sub-bit programme."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path('/path/to/workspace/data/kelana-subbit')
MODEL = 'Qwen/Qwen3-0.6B'
REVISION = 'c1899de289a04d12100db370d81485cdf75e47ca'
CORPUS = 'Salesforce/wikitext'
CORPUS_REVISION = 'b08601e04326c79dfdd32d625aee71d232d685c3'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def fetch(kind):
    from huggingface_hub import snapshot_download
    if kind == 'model':
        repo, revision, repo_type = MODEL, REVISION, 'model'
        destination = ROOT / 'models/qwen3-0.6b'
        patterns = ['*.json', '*.txt', '*.safetensors', 'LICENSE', 'README.md']
    else:
        repo, revision, repo_type = CORPUS, CORPUS_REVISION, 'dataset'
        destination = ROOT / 'corpus/wikitext-2-raw'
        patterns = ['wikitext-2-raw-v1/*.parquet', 'README.md']
    snapshot_download(repo, revision=revision, repo_type=repo_type,
                      allow_patterns=patterns, local_dir=destination, max_workers=4)
    files = {str(p.relative_to(destination)): {'bytes': p.stat().st_size, 'sha256': sha(p)}
             for p in sorted(destination.rglob('*'))
             if p.is_file() and '.cache' not in p.parts and p.name != 'source.json'}
    record = {'repository': repo, 'revision': revision, 'repo_type': repo_type, 'files': files}
    (destination / 'source.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'destination': str(destination), 'bytes': sum(f['bytes'] for f in files.values()),
                      'files': len(files), 'revision': revision}))


def corpus_text():
    import pyarrow.parquet as pq
    folder = ROOT / 'corpus/wikitext-2-raw'
    record = json.loads((folder / 'source.json').read_text())
    texts = {}
    for split in ('train', 'validation', 'test'):
        path = folder / f'wikitext-2-raw-v1/{split}-00000-of-00001.parquet'
        expected = record['files'][str(path.relative_to(folder))]['sha256']
        if sha(path) != expected:
            raise ValueError(f'corpus source changed: {path}')
        rows = pq.read_table(path, columns=['text'])['text'].to_pylist()
        target = folder / f'{split}.txt'
        target.write_text('\n\n'.join(rows))
        texts[split] = {'rows': len(rows), 'join': 'two newline characters', 'sha256': sha(target)}
    (folder / 'text-source.json').write_text(json.dumps(texts, indent=2) + '\n')
    print(json.dumps(texts))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['model', 'corpus', 'corpus-text'])
    args = parser.parse_args()
    corpus_text() if args.action == 'corpus-text' else fetch(args.action)
