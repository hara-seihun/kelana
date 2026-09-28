#!/usr/bin/env python3
"""Price the cold page boundary of the complete exact Qwen3-0.6B ternary image."""
import argparse
import hashlib
import json
import os
import random
import statistics
import time
import zlib
from pathlib import Path

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def images(root, raw_root, receipt):
    pages = []
    identity = {}
    width = receipt['page_bytes']
    for item in receipt['matrices']:
        name = item['name'].replace('.npz', '.tern')
        raw_file, page_file = raw_root / name, root / name
        raw, paged = raw_file.read_bytes(), page_file.read_bytes()
        identity[name] = [digest(raw_file), digest(page_file)]
        code_bytes = item['original_code_bytes']
        prefix = 12  # two little-endian int32 dimensions and one rotation-block int32
        count = item['code_pages']
        offsets = [int.from_bytes(paged[prefix + 4*i:prefix + 4*i + 4], 'little') for i in range(count + 1)]
        body = prefix + 4 * (count + 1)
        assert offsets[0] == 0 and offsets[-1] == item['paid_code_bytes'] - 4 * (count + 1)
        for i in range(count):
            plain = raw[prefix + i*width:prefix + min((i+1)*width, code_bytes)]
            stored = paged[body + offsets[i]:body + offsets[i+1]]
            assert stored[0] in (0, 1)
            decoded = zlib.decompress(stored[1:]) if stored[0] else stored[1:]
            assert decoded == plain
            pages.append((plain, stored))
    assert len(pages) == receipt['code_pages']
    return pages, identity


def run(pages, order, compressed, random_access):
    checksum = 0
    start = time.perf_counter_ns()
    for i in order:
        raw, stored = pages[i]
        if compressed:
            value = zlib.decompress(stored[1:]) if stored[0] else stored[1:]
        else:
            value = raw
        checksum = zlib.crc32(value[:1] if random_access else value, checksum)
    return (time.perf_counter_ns() - start) / 1e6, checksum


def panel(pages, random_access, repeats):
    order = list(range(len(pages)))
    if random_access:
        random.Random(20260924).shuffle(order)
    runs = []
    # Alternate the order of arms, checking the same observation on every repetition.
    for r in range(repeats):
        arms = (False, True) if r % 2 == 0 else (True, False)
        timed = {arm: run(pages, order, arm, random_access) for arm in arms}
        assert timed[False][1] == timed[True][1]
        runs.append({'raw_ms': timed[False][0], 'paged_ms': timed[True][0],
                     'crc32': timed[False][1], 'order': ['paged' if a else 'raw' for a in arms]})
    return {'runs': runs, 'median_raw_ms': statistics.median(x['raw_ms'] for x in runs),
            'median_paged_ms': statistics.median(x['paged_ms'] for x in runs),
            'median_paired_extra_ms': statistics.median(x['paged_ms'] - x['raw_ms'] for x in runs)}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--paged-image', default='fresh-duration32-code-page-16384')
    ap.add_argument('--raw-image', default='fresh-duration32-page-256')
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--repeats', type=int, default=6)
    args = ap.parse_args()
    receipt_path = DATA / args.paged_image / 'receipt.json'
    receipt = json.loads(receipt_path.read_text())
    assert receipt['scale_image'] == args.raw_image
    pages, identity = images(DATA / args.paged_image, DATA / args.raw_image, receipt)
    sequential = panel(pages, False, args.repeats)
    random_panel = panel(pages, True, args.repeats)
    result = {'contract': 'CPU Python/zlib exact page boundary, both complete images preloaded into RAM; sequential full-code CRC32 and shuffled one-code-per-page CRC32. Identical decoded observations, no scale/trit arithmetic, disk read, native GPU inference, model quality or whole-model speed claim.',
              'source_sha256': digest(Path(__file__)), 'image_receipt_sha256': digest(receipt_path),
              'model_source_manifest_sha256': receipt['source_manifest_sha256'],
              'image_hashes': identity, 'raw_image_bytes': receipt['original_paid_bytes'],
              'paged_image_bytes': receipt['paid_payload_bytes'],
              'raw_code_bytes': receipt['original_code_bytes'], 'paged_code_bytes': receipt['paid_code_bytes'],
              'pages': receipt['code_pages'], 'compressed_pages': receipt['compressed_pages'],
              'python': os.sys.version, 'zlib': zlib.ZLIB_VERSION,
              'sequential_full_code': sequential, 'random_one_code_per_page': random_panel}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('raw_image_bytes', 'paged_image_bytes', 'pages', 'compressed_pages',
                                            'sequential_full_code', 'random_one_code_per_page')}, indent=2))


if __name__ == '__main__':
    main()
