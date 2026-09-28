#!/usr/bin/env python3
"""Lossless page-addressable FP16-scale coordinate for the complete frozen ternary image."""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def pack_page(values):
    low = int(values.min())
    diffs = values.astype(np.int32) - low
    width = int(int(diffs.max()).bit_length())
    # One fixed 3-byte header; the bit stream starts at the next byte.
    data = bytearray([low & 255, low >> 8, width])
    acc = bits = 0
    for v in diffs:
        acc |= int(v) << bits
        bits += width
        while bits >= 8:
            data.append(acc & 255)
            acc >>= 8
            bits -= 8
    if bits:
        data.append(acc & 255)
    return data, width


def decode_one(data, offsets, page_index, position):
    at = int(offsets[page_index])
    width = data[at + 2]
    start_bit = position * width
    start = at + 3 + start_bit // 8
    shift = start_bit % 8
    nbytes = (shift + width + 7) // 8
    word = int.from_bytes(data[start:start+nbytes], 'little')
    return (data[at] | data[at+1] << 8) + ((word >> shift) & ((1 << width) - 1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', default='expanded-scale384')
    parser.add_argument('--output', default='exact-rate')
    parser.add_argument('--page-rows', type=int, default=64)
    args = parser.parse_args()
    if args.page_rows < 1:
        parser.error('page rows must be positive')
    page_rows = args.page_rows
    root = DATA / args.image
    out = DATA / args.output
    if root.resolve() == out.resolve():
        parser.error('output cannot overwrite source image')
    out.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((root/'manifest.json').read_text())
    records = []
    widths = Counter()
    total_old = total_new = total_pages = 0
    for path in sorted(root.glob('model*.npz')):
        with np.load(path) as source:
            scale = source['scales'].view(np.uint16).copy()
            codes = source['codes'].tobytes()
            signs = source['signs'].tobytes()
            shape = source['shape'].astype('<i4').tobytes()
            rotation = source['rotation_block'].astype('<i4').tobytes()
        rows, groups = scale.shape
        stream = bytearray()
        offsets = [0]
        page_widths = Counter()
        for group in range(groups):
            for row in range(0, rows, page_rows):
                values = scale[row:row+page_rows, group]
                page, width = pack_page(values)
                stream.extend(page)
                offsets.append(len(stream))
                page_widths[width] += 1
                # Check every codeword against a separately addressed decoder, including tail pages.
                index = len(offsets) - 2
                for j, original in enumerate(values):
                    assert decode_one(stream, offsets, index, j) == int(original), (path, group, row, j)
        index_bytes = np.asarray(offsets, dtype='<u4').tobytes()
        assert len(stream) < 2**32
        encoded = index_bytes + stream
        dest = out / (path.stem + '.tern')
        dest.write_bytes(shape + rotation + codes + signs + encoded)
        old = scale.nbytes
        new = len(encoded)
        original_image_bytes = old + len(shape) + len(rotation) + len(codes) + len(signs)
        assert dest.stat().st_size == original_image_bytes - old + new
        total_old += old
        total_new += new
        total_pages += len(offsets) - 1
        widths.update(page_widths)
        records.append(dict(image=path.name, image_sha256=digest(path), rows=rows, groups=groups,
                            original_scale_bytes=old, paid_scale_bytes=new, index_bytes=len(index_bytes),
                            pages=len(offsets)-1, width_counts=dict(sorted(page_widths.items())),
                            image_bytes=dest.stat().st_size, image_sha256_new=digest(dest)))
    with np.load(root/'norms.npz') as norms:
        norm_bytes = b''.join(norms[key].tobytes() for key in sorted(norms.files))
    (out/'norms.bin').write_bytes(norm_bytes)
    assert sum(r['image_bytes'] for r in records) + len(norm_bytes) == manifest['payload_bytes'] - total_old + total_new
    receipt = dict(source_manifest_sha256=digest(root/'manifest.json'), source_image=args.image,
                   norms_sha256=digest(out/'norms.bin'), norms_bytes=len(norm_bytes),
                   source_sha256=digest(Path(__file__)), page_rows=page_rows,
                   layout='group-major row pages; little-endian u32 offsets including end, then page streams of uint16 minimum, uint8 width, LSB-first bit-packed unsigned deltas; original codes, rotation signs, shape, norms unchanged',
                   original_payload_bytes=manifest['payload_bytes'], original_scale_bytes=total_old,
                   paid_scale_bytes=total_new, paid_payload_bytes=manifest['payload_bytes']-total_old+total_new,
                   unique_parameters=manifest['unique_parameters'], pages=total_pages,
                   width_counts=dict(sorted(widths.items())), matrices=records)
    receipt['paid_bpw'] = 8*receipt['paid_payload_bytes']/receipt['unique_parameters']
    (out/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({k:v for k,v in receipt.items() if k != 'matrices'}, indent=2))


if __name__ == '__main__':
    main()
