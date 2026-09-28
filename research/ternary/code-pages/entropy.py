#!/usr/bin/env python3
"""Measure finite-symbol entropy and paid page size on the complete frozen ternary image."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

DATA = Path('/path/to/workspace/data/kelana-subbit/ternary')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def entropy(counts):
    nonzero = counts[counts != 0].astype(np.float64)
    total = nonzero.sum()
    return float(np.log2(total) * total - np.dot(nonzero, np.log2(nonzero))) if total else 0.0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', default='fresh-duration32')
    ap.add_argument('--page-image', default='fresh-duration32-code-page-16384')
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    source = DATA / args.source
    image = DATA / args.page_image
    receipt_path = image / 'receipt.json'
    receipt = json.loads(receipt_path.read_text())
    assert receipt['source_image'] == args.source
    width = receipt['page_bytes']
    records = []
    total_code = total_h0 = total_page_h0 = total_h1 = total_transitions = 0
    global_counts = np.zeros(256, dtype=np.int64)
    for record in receipt['matrices']:
        path = source / record['name']
        assert digest(path) == record['original_npz_sha256']
        with np.load(path) as array:
            code = array['codes'].ravel().astype(np.uint8, copy=False)
        assert code.size == record['original_code_bytes']
        assert int(code.max()) <= 242
        counts = np.bincount(code, minlength=256)
        global_counts += counts
        h0 = entropy(counts)
        page_h0 = transitions = 0
        pair_counts = np.zeros((256, 256), dtype=np.int64)
        for start in range(0, code.size, width):
            page = code[start:start + width]
            page_h0 += entropy(np.bincount(page, minlength=256))
            if page.size > 1:
                pairs = np.bincount(page[:-1].astype(np.int32) * 256 + page[1:].astype(np.int32), minlength=65536).reshape(256, 256)
                pair_counts += pairs
                transitions += page.size - 1
        first = entropy(pair_counts.ravel()) - entropy(pair_counts.sum(axis=1))
        total_code += code.size
        total_h0 += h0
        total_page_h0 += page_h0
        total_h1 += first
        total_transitions += transitions
        records.append(dict(name=record['name'], code_bytes=code.size, paid_code_bytes=record['paid_code_bytes'],
                            distinct_symbols=int(np.count_nonzero(counts)), h0_ideal_bytes=h0 / 8,
                            page_h0_ideal_bytes=page_h0 / 8, matrix_h1_ideal_bytes=first / 8))
    assert total_code == receipt['original_code_bytes']
    assert len(records) == 197
    base = receipt['paid_payload_bytes'] - receipt['paid_code_bytes']
    result = dict(source_sha256=digest(Path(__file__)), source_manifest_sha256=digest(source / 'manifest.json'),
                  page_receipt_sha256=digest(receipt_path), source_image=args.source, page_image=args.page_image,
                  unique_parameters=receipt['unique_parameters'], code_bytes=total_code, paid_code_bytes=receipt['paid_code_bytes'],
                  paid_complete_bytes=receipt['paid_payload_bytes'], paid_complete_bpw=receipt['paid_bpw'],
                  noncode_bytes=base, pages=receipt['code_pages'], matrix_h0_ideal_bytes=total_h0/8,
                  page_h0_ideal_bytes=total_page_h0/8, matrix_h1_transition_ideal_bytes=total_h1/8,
                  matrix_h1_transition_count=total_transitions, global_h0_ideal_bytes=entropy(global_counts)/8,
                  matrix_h0_bits_per_code=total_h0/total_code,
                  page_h0_bits_per_code=total_page_h0/total_code,
                  matrix_h1_transition_bits_per_code=total_h1/total_transitions,
                  matrix_h0_free_model_gap_bytes=receipt['paid_code_bytes']-total_h0/8,
                  page_h0_free_model_gap_bytes=receipt['paid_code_bytes']-total_page_h0/8,
                  matrices=records)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'matrices'}, indent=2))


if __name__ == '__main__':
    main()
