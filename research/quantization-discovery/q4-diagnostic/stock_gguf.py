#!/usr/bin/env python3
"""Acquire pinned stock Qwen3-0.6B GGUFs and inspect actual physical rates."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import requests

ROOT = Path('/path/to/workspace/data/kelana-subbit/q4-diagnostic/stock-gguf')
REPO = 'bartowski/Qwen_Qwen3-0.6B-GGUF'
REVISION = '60b85c0e3d8fe0f6474f406922a26d12aca4550d'
# Repository metadata is pinned to REVISION and includes each LFS content hash.
# New comparison formats come from this same immutable inventory, not an
# unpinned live listing or a guessed quantization label.
INVENTORY = json.loads((ROOT / 'repository.json').read_text())
if INVENTORY['sha'] != REVISION:
    raise ValueError('stock repository inventory changed revision')
FILES = {
    sibling['rfilename'].removeprefix('Qwen_Qwen3-0.6B-').removesuffix('.gguf'):
        (sibling['rfilename'], sibling['size'], sibling['lfs']['sha256'])
    for sibling in INVENTORY['siblings'] if sibling['rfilename'].endswith('.gguf')
    and sibling.get('lfs')
}
FILES['imatrix'] = next((s['rfilename'], s['size'], s['lfs']['sha256'])
                        for s in INVENTORY['siblings'] if s['rfilename'].endswith('.imatrix'))
GGUF_SOURCE = Path('/path/to/workspace/work/clones/bonsai-hip/gguf-py')


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def acquire(name):
    filename, size, digest = FILES[name]
    ROOT.mkdir(parents=True, exist_ok=True)
    path = ROOT / filename
    url = f'https://huggingface.co/{REPO}/resolve/{REVISION}/{filename}'
    if not path.exists():
        partial = path.with_suffix(path.suffix + '.partial')
        offset = partial.stat().st_size if partial.exists() else 0
        with requests.get(url, headers={'Range': f'bytes={offset}-'} if offset else {},
                          stream=True, timeout=(20, 30)) as response:
            response.raise_for_status()
            if offset and (response.status_code != 206 or not response.headers.get('Content-Range', '').startswith(f'bytes {offset}-')):
                raise ValueError('download did not honor the saved prefix')
            with partial.open('ab' if offset else 'wb') as output:
                for chunk in response.iter_content(1 << 20):
                    output.write(chunk)
        if partial.stat().st_size != size or sha(partial) != digest:
            raise ValueError('download size or upstream SHA mismatch')
        partial.rename(path)
    if path.stat().st_size != size or sha(path) != digest:
        raise ValueError('pinned file changed')
    receipt = dict(repository=REPO, revision=REVISION, url=url, file=str(path), file_bytes=size,
                   sha256=digest, verified=True, script_sha256=sha(Path(__file__)))
    p = path.with_suffix('.acquisition.json')
    if not p.exists():
        p.write_text(json.dumps(receipt, indent=2) + '\n')
    return path


def inspect(path, gguf_source):
    sys.path.insert(0, str(gguf_source))
    import gguf
    reader = gguf.GGUFReader(path)
    tensors = [dict(name=t.name, shape=t.shape.tolist(), elements=t.n_elements,
                    bytes=t.n_bytes, type=t.tensor_type.name) for t in reader.tensors]
    payload = sum(t['bytes'] for t in tensors)
    stored_elements = sum(t['elements'] for t in tensors)
    receipt = dict(file=str(path), sha256=sha(path), file_bytes=path.stat().st_size,
                   tensor_payload_bytes=payload, container_metadata_alignment_bytes=path.stat().st_size - payload,
                   source_unique_parameters=596049920, stored_elements=stored_elements,
                   payload_bpw_per_source_unique=payload * 8 / 596049920,
                   file_bpw_per_source_unique=path.stat().st_size * 8 / 596049920,
                   payload_bpw_per_stored_element=payload * 8 / stored_elements,
                   tensors=tensors, gguf_source=str(gguf_source),
                   decoder_sha256=sha(gguf_source / 'gguf/quants.py'))
    p = path.with_suffix('.tensors.json')
    if p.exists():
        if json.loads(p.read_text()) != receipt:
            raise ValueError('tensor census changed')
    else:
        p.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k:v for k,v in receipt.items() if k != 'tensors'}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--name', choices=FILES, required=True)
    parser.add_argument('--gguf-source', type=Path, default=GGUF_SOURCE)
    args = parser.parse_args()
    path = acquire(args.name)
    if args.name == 'imatrix':
        print(json.dumps(dict(path=str(path), sha256=sha(path), bytes=path.stat().st_size)))
    else:
        inspect(path, args.gguf_source)
