#!/usr/bin/env python3
"""Resumable bounded-range download of the pinned official Qwen3-1.7B image."""
import argparse
import hashlib
import json
import time
from pathlib import Path

import requests
from huggingface_hub import snapshot_download

ROOT = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-1.7b')
REPO = 'Qwen/Qwen3-1.7B'
REVISION = '70d244cc86ccca08cf5af4e1e306ecf908b1ad5e'
WEIGHTS = {
    'model-00001-of-00002.safetensors': (3441185608, '169ad53ec313c3a34b06c0809216e4fc072cce444a5d4ff2b59690d064130ed5'),
    'model-00002-of-00002.safetensors': (622329984, '912becff8d60672aa8628ef08c05898d9adf17c2ad4ae3caf99b065622fdeff9'),
}
CHUNK = 16 << 20


def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 22), b''):
            digest.update(block)
    return digest.hexdigest()


def bounded_weights(seconds):
    deadline = time.monotonic() + seconds
    with requests.Session() as session:
        for name, (size, expected) in WEIGHTS.items():
            target = ROOT / name
            if target.exists():
                if target.stat().st_size != size or sha(target) != expected:
                    raise ValueError(f'completed model shard has wrong bytes: {target}')
                continue
            partial = ROOT / (name + '.part')
            position = partial.stat().st_size if partial.exists() else 0
            if position > size:
                raise ValueError(f'partial model shard is too large: {partial}')
            url = f'https://huggingface.co/{REPO}/resolve/{REVISION}/{name}'
            while position < size and time.monotonic() < deadline - 5:
                end = min(size, position + CHUNK) - 1
                with session.get(url, headers={'Range': f'bytes={position}-{end}'},
                                 timeout=25, stream=True) as response:
                    response.raise_for_status()
                    expected_range = f'bytes {position}-{end}/{size}'
                    if response.status_code != 206 or response.headers.get('Content-Range') != expected_range:
                        raise ValueError(f'wrong response range for {name}: {response.status_code} {response.headers.get("Content-Range")}')
                    chunk = b''.join(response.iter_content(chunk_size=1 << 20))
                if len(chunk) != end - position + 1:
                    raise ValueError(f'incomplete response chunk for {name} at {position}')
                with partial.open('ab') as destination:
                    destination.write(chunk)
                position = end + 1
            print(json.dumps({'shard': name, 'received_bytes': position, 'total_bytes': size}), flush=True)
            if position < size:
                return False
            if sha(partial) != expected:
                raise ValueError(f'upstream SHA256 mismatch for {name}')
            partial.rename(target)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', type=int, default=38)
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    # This small-file snapshot supplies the exact official config and tokenizer.
    snapshot_download(REPO, revision=REVISION, local_dir=ROOT, max_workers=4,
                      allow_patterns=['*.json', '*.txt', 'LICENSE', 'README.md'])
    if not bounded_weights(args.seconds):
        return
    for partial in (ROOT / '.cache/huggingface/download').glob('*.incomplete'):
        if any(digest in partial.name for _, digest in WEIGHTS.values()):
            partial.unlink()
    files = {str(p.relative_to(ROOT)): {'bytes': p.stat().st_size, 'sha256': sha(p)}
             for p in sorted(ROOT.iterdir()) if p.is_file() and p.name != 'source.json'}
    record = {'repository': REPO, 'revision': REVISION, 'files': files}
    (ROOT / 'source.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'repository': REPO, 'revision': REVISION,
                      'bytes': sum(f['bytes'] for f in files.values()), 'files': len(files)}))


if __name__ == '__main__':
    main()
