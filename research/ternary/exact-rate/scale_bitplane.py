#!/usr/bin/env python3
"""Price a complete, independently addressed exact FP16 scale bitplane image."""
import hashlib
import json
import zlib
from collections import Counter
from pathlib import Path

import numpy as np

from measure import decode_one

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')
SOURCE = DATA / 'fresh-duration32'
SCALE = DATA / 'fresh-duration32-page-256'
CODES = DATA / 'fresh-duration32-code-page-16384'
OUT = DATA / 'fresh-duration32-scale-bitplanes'
ROWS = 256
BITS = np.arange(16, dtype=np.uint16)


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def planes(words):
    bits = ((words[:, None] >> BITS) & 1).astype(np.uint8)
    return np.packbits(bits.T, axis=1, bitorder='little').tobytes()


def unplanes(packed, count):
    a = np.frombuffer(packed, dtype=np.uint8).reshape(16, (count + 7) // 8)
    bits = np.unpackbits(a, axis=1, count=count, bitorder='little').T.astype(np.uint16)
    return (bits << BITS).sum(axis=1, dtype=np.uint16)


def bytesplit(words):
    return np.ascontiguousarray(words.astype('<u2', copy=False)).view(np.uint8).reshape(-1, 2).T.tobytes()


def unbytesplit(packed, count):
    a = np.frombuffer(packed, dtype=np.uint8).reshape(2, count).T.copy()
    return a.view('<u2').reshape(-1)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    scale_receipt = json.loads((SCALE / 'receipt.json').read_text())
    code_receipt = json.loads((CODES / 'receipt.json').read_text())
    assert scale_receipt['source_image'] == code_receipt['source_image'] == SOURCE.name
    old_by_name = {r['image']: r for r in scale_receipt['matrices']}
    code_by_name = {r['name']: r for r in code_receipt['matrices']}
    records = []
    mode_counts = Counter()
    saved = 0
    for source in sorted(SOURCE.glob('model*.npz')):
        name = source.name
        with np.load(source) as image:
            values = image['scales'].view(np.uint16)
            prefix = image['shape'].astype('<i4').tobytes() + image['rotation_block'].astype('<i4').tobytes()
            signs = image['signs'].tobytes()
        rows, groups = values.shape
        original = (SCALE / (source.stem + '.tern')).read_bytes()
        index_start = len(original) - old_by_name[name]['paid_scale_bytes']
        old_offsets = np.frombuffer(original, dtype='<u4', count=old_by_name[name]['pages'] + 1, offset=index_start)
        old_stream = original[index_start + old_by_name[name]['index_bytes']:]
        assert len(old_stream) == int(old_offsets[-1])
        current = (CODES / (source.stem + '.tern')).read_bytes()
        old_scale_start = len(current) - old_by_name[name]['paid_scale_bytes']
        assert current.startswith(prefix) and current[old_scale_start - len(signs):old_scale_start] == signs
        # Pages carry one tag: 0 = original min/delta page, 1 = bitplane/zlib-1.
        # The directory is rebuilt because either arm may win on a given page.
        stream = bytearray()
        offsets = [0]
        choices = Counter()
        index = 0
        for group in range(groups):
            for row in range(0, rows, ROWS):
                block = values[row:row + ROWS, group]
                old_page = old_stream[int(old_offsets[index]):int(old_offsets[index + 1])]
                assert all(decode_one(old_stream, old_offsets, index, j) == int(v) for j, v in enumerate(block))
                options = [(b'\x00' + old_page, 'delta'),
                           (b'\x01' + zlib.compress(planes(block), 1), 'bitplane'),
                           (b'\x02' + zlib.compress(bytesplit(block), 1), 'byteplane')]
                page, mode = min(options, key=lambda item: len(item[0]))
                if mode == 'bitplane':
                    decoded = unplanes(zlib.decompress(page[1:]), len(block))
                    assert np.array_equal(decoded, block)
                if mode == 'byteplane':
                    decoded = unbytesplit(zlib.decompress(page[1:]), len(block))
                    assert np.array_equal(decoded, block)
                choices[mode] += 1
                stream.extend(page)
                offsets.append(len(stream))
                index += 1
        assert index == old_by_name[name]['pages']
        directory = np.asarray(offsets, dtype='<u4').tobytes()
        encoded = directory + stream
        assert len(encoded) < 2**32
        path = OUT / (source.stem + '.tern')
        path.write_bytes(current[:old_scale_start] + encoded)
        assert path.stat().st_size == len(current) - old_by_name[name]['paid_scale_bytes'] + len(encoded)
        # Re-open the published file, not only the in-memory candidates.
        published = path.read_bytes()
        at = old_scale_start
        address = np.frombuffer(published, dtype='<u4', count=index + 1, offset=at)
        body = published[at + len(directory):]
        assert len(body) == int(address[-1])
        ix = 0
        for group in range(groups):
            for row in range(0, rows, ROWS):
                count = min(ROWS, rows - row)
                page = body[int(address[ix]):int(address[ix + 1])]
                if page[0] == 1:
                    decoded = unplanes(zlib.decompress(page[1:]), count)
                elif page[0] == 2:
                    decoded = unbytesplit(zlib.decompress(page[1:]), count)
                else:
                    decoded = np.array([decode_one(page[1:], [0], 0, j) for j in range(count)], dtype=np.uint16)
                assert np.array_equal(decoded, values[row:row + count, group]), (name, ix)
                ix += 1
        mode_counts.update(choices)
        saved += old_by_name[name]['paid_scale_bytes'] - len(encoded)
        records.append(dict(name=name, source_sha256=sha(source), source_code_image_sha256=sha(CODES / path.name),
                            output_sha256=sha(path), pages=index, modes=dict(choices),
                            previous_scale_bytes=old_by_name[name]['paid_scale_bytes'], paid_scale_bytes=len(encoded),
                            output_bytes=path.stat().st_size))
    norms = CODES / 'norms.bin'
    (OUT / 'norms.bin').write_bytes(norms.read_bytes())
    total = sum(r['output_bytes'] for r in records) + norms.stat().st_size
    assert total == code_receipt['paid_payload_bytes'] - saved
    receipt = dict(source_manifest_sha256=sha(SOURCE / 'manifest.json'), source_code_receipt_sha256=sha(CODES / 'receipt.json'),
                   source_scale_receipt_sha256=sha(SCALE / 'receipt.json'), source_sha256=sha(Path(__file__)),
                   source_image=SOURCE.name, matrices=records, modes=dict(mode_counts), pages=sum(mode_counts.values()),
                   page_rows=ROWS, page_offsets='little-endian u32 including end; per-page tag 0 = original min/delta page, 1 = zlib-1 of sixteen bitplanes LSB-first, each plane padded to a byte; 2 = zlib-1 of low-byte then high-byte planes',
                   previous_scale_bytes=scale_receipt['paid_scale_bytes'], paid_scale_bytes=scale_receipt['paid_scale_bytes'] - saved,
                   previous_complete_bytes=code_receipt['paid_payload_bytes'], paid_complete_bytes=total,
                   unique_parameters=code_receipt['unique_parameters'], paid_bpw=8 * total / code_receipt['unique_parameters'],
                   norms_sha256=sha(OUT / 'norms.bin'))
    (OUT / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: v for k, v in receipt.items() if k != 'matrices'}, indent=2))


if __name__ == '__main__':
    main()
