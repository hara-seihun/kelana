#!/usr/bin/env python3
"""Preserve the model-image and executable identity with the bounded CPU replay."""
import hashlib
import json
import os
import struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf.halo')
MODEL = Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf')
SOURCE = Path('/path/to/workspace/data/kelana-ffn/ptq1_0/layer10/r8/xq_ff.i8')
HEAD_OFFSET, HEAD_BYTES = 24576, 278118400


def digest(path, offset=0, length=None):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        stream.seek(offset)
        while True:
            n = 1 << 20 if length is None else min(1 << 20, length)
            if n == 0:
                break
            block = stream.read(n)
            if not block:
                break
            h.update(block)
            if length is not None:
                length -= len(block)
    if length is not None:
        assert length == 0
    return h.hexdigest()


def main():
    with CACHE.open('rb') as stream:
        magic, size, mtime, count, _ = struct.unpack('<8sQQQQ', stream.read(40))
    assert magic == b'HALOCAC2' and count == 402
    assert (size, mtime) == (MODEL.stat().st_size, int(MODEL.stat().st_mtime))
    provenance = {
        'gguf_path': str(MODEL), 'gguf_bytes': size, 'gguf_mtime_seconds': mtime,
        'head_cache_path': str(CACHE), 'head_sha256': digest(CACHE, HEAD_OFFSET, HEAD_BYTES),
        'head_offset': HEAD_OFFSET, 'head_bytes': HEAD_BYTES,
        'query_source': str(SOURCE), 'query_source_sha256': digest(SOURCE),
        'query_scope': 'first 5120 coordinates of the first and second 17408-coordinate rows in layer10 FFN input xq_ff.i8; head-input proxies, not final-head captures',
        'probe_source_sha256': digest(HERE / 'probe.cpp'),
        'halo_decoder_source_sha256': digest(Path('/path/to/workspace/projects/bonsai-halo/src/halo_format.h')),
        'probe_binary_sha256': digest(HERE / 'build/probe'),
        'compiler': 'c++ -O3 -std=c++20 -ffp-contract=off -I/path/to/workspace/projects/bonsai-halo/src',
    }
    for idx, tag in enumerate(('q0', 'q1')):
        raw = json.loads((HERE / 'build' / ('results.json' if idx == 0 else 'results1.json')).read_text())
        assert raw['head_offset'] == HEAD_OFFSET and raw['head_bytes'] == HEAD_BYTES
        raw['provenance'] = provenance | {'query_sha256': digest(HERE / 'build' / ('query.i8' if idx == 0 else 'query1.i8'))}
        (HERE / f'results-{tag}.json').write_text(json.dumps(raw, indent=2) + '\n')
    anchor = json.loads((HERE / 'anchor-result.json').read_text())
    anchor['provenance'] = provenance
    (HERE / 'anchor-result.json').write_text(json.dumps(anchor, indent=2) + '\n')
    print(provenance)


if __name__ == '__main__':
    main()
