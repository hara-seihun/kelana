#!/usr/bin/env python3
"""Save an independently addressed lossless trit-code image beside the paid scale image."""
import argparse
import hashlib
import json
import zlib
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def page_image(code, width):
    offsets = [0]
    body = bytearray()
    compressed = 0
    for start in range(0, len(code), width):
        plain = code[start:start + width]
        packed = zlib.compress(plain, 1)
        use_packed = len(packed) < len(plain)
        body.append(int(use_packed))
        body.extend(packed if use_packed else plain)
        offsets.append(len(body))
        compressed += use_packed
    assert offsets[-1] < 2**32
    directory = np.asarray(offsets, dtype='<u4').tobytes()
    for index, start in enumerate(range(0, len(code), width)):
        page = body[offsets[index]:offsets[index + 1]]
        decoded = zlib.decompress(page[1:]) if page[0] else page[1:]
        assert decoded == code[start:start + width], (index, start)
    return directory + body, len(offsets) - 1, compressed, len(directory)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--image', default='fresh-duration32')
    ap.add_argument('--scale-image', default='fresh-duration32-page-256')
    ap.add_argument('--output', default='fresh-duration32-code-page-16384')
    ap.add_argument('--page-bytes', type=int, default=16384)
    args = ap.parse_args()
    assert args.page_bytes > 0
    root, scale_root, out = (DATA / name for name in (args.image, args.scale_image, args.output))
    assert len({root.resolve(), scale_root.resolve(), out.resolve()}) == 3
    out.mkdir(parents=True, exist_ok=True)
    source_manifest = json.loads((root / 'manifest.json').read_text())
    scale_receipt = json.loads((scale_root / 'receipt.json').read_text())
    records = []
    total_original = total_paged = total_pages = total_zip = 0
    for path in sorted(root.glob('model*.npz')):
        with np.load(path) as array:
            code = array['codes'].tobytes()
            signs = array['signs'].tobytes()
            shape = array['shape'].astype('<i4').tobytes()
            rotation = array['rotation_block'].astype('<i4').tobytes()
            scales = array['scales'].nbytes
        paid_path = scale_root / (path.stem + '.tern')
        paid = paid_path.read_bytes()
        prefix = shape + rotation
        assert paid.startswith(prefix + code + signs), path
        remainder = paid[len(prefix) + len(code) + len(signs):]
        encoded, pages, zipped, directory = page_image(code, args.page_bytes)
        dest = out / paid_path.name
        dest.write_bytes(prefix + encoded + signs + remainder)
        assert dest.stat().st_size == len(paid) - len(code) + len(encoded)
        saved = dest.read_bytes()
        assert saved[:len(prefix)] == prefix
        assert saved[len(prefix) + len(encoded):] == signs + remainder
        offsets = np.frombuffer(saved, dtype='<u4', count=pages + 1, offset=len(prefix))
        body_start = len(prefix) + 4 * (pages + 1)
        decoded = bytearray()
        for i in range(pages):
            page = saved[body_start + int(offsets[i]):body_start + int(offsets[i + 1])]
            assert page[0] in (0, 1)
            decoded.extend(zlib.decompress(page[1:]) if page[0] else page[1:])
        assert decoded == code, path
        records.append(dict(name=path.name, original_npz_sha256=sha(path), scale_image_sha256=sha(paid_path),
                            output_sha256=sha(dest), original_code_bytes=len(code), paid_code_bytes=len(encoded),
                            code_pages=pages, compressed_pages=zipped, directory_bytes=directory,
                            original_scales_bytes=scales, output_bytes=dest.stat().st_size))
        total_original += len(code)
        total_paged += len(encoded)
        total_pages += pages
        total_zip += zipped
    assert len(records) == len(source_manifest['matrices']) == 197
    norms = (scale_root / 'norms.bin').read_bytes()
    (out / 'norms.bin').write_bytes(norms)
    assert sha(out / 'norms.bin') == sha(scale_root / 'norms.bin')
    paid_total = sum(r['output_bytes'] for r in records) + len(norms)
    assert paid_total == scale_receipt['paid_payload_bytes'] - total_original + total_paged
    receipt = dict(source_manifest_sha256=sha(root / 'manifest.json'), scale_receipt_sha256=sha(scale_root / 'receipt.json'),
                   source_sha256=sha(Path(__file__)), source_image=args.image, scale_image=args.scale_image,
                   page_bytes=args.page_bytes, format='Each matrix: unchanged shape/rotation; little-endian u32 page offsets (including end); pages of one raw/zlib-1 flag byte and payload; unchanged signs and exactly decoded paid scale pages. Read one page then radix-243 decode; page granularity bounds random-access amplification.',
                   original_paid_bytes=scale_receipt['paid_payload_bytes'], paid_payload_bytes=paid_total,
                   unique_parameters=source_manifest['unique_parameters'], original_code_bytes=total_original,
                   paid_code_bytes=total_paged, code_pages=total_pages, compressed_pages=total_zip,
                   norms_sha256=sha(out / 'norms.bin'), matrices=records)
    receipt['paid_bpw'] = 8 * paid_total / receipt['unique_parameters']
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({key: val for key, val in receipt.items() if key != 'matrices'}, indent=2))


if __name__ == '__main__':
    main()
