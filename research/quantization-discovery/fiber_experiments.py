#!/usr/bin/env python3
"""Exact fiber coding, full-row custody and prefix/miss-path measurements."""
from collections import Counter
import hashlib
import itertools
import json
from pathlib import Path
import time
import numpy as np
from fiber_codec import FiberBook, Image, encode, ceil_log2
from fiber_fast import FastImage

HERE = Path(__file__).resolve().parent


def checks():
    rows_checked = queries_checked = 0
    for probe in ((0, 1, -2, 3, 0), (0, 0, 0), (1,), (2, -4, 6)):
        book = FiberBook(probe)
        rows = list(itertools.product((-1, 0, 1), repeat=len(probe)))
        codes = [book.rank(row) for row in rows]
        assert len(set(codes)) == len(rows)
        histogram = Counter(sum(w*q for w, q in zip(row, probe)) for row in rows)
        assert {s.response: s.count for s in book.slots} == dict(histogram)
        for code, row in zip(codes, rows):
            assert book.unrank(code) == list(row)
            for length in range(len(probe)+1):
                assert book.unrank(code, length) == list(row[:length])
        for length in range(len(probe)+1):
            partial = FiberBook(probe, retain_depth=length)
            for code, row in zip(codes, rows):
                assert partial.unrank(code, length) == list(row[:length])
        wire = encode(book, rows, [0x3c00]*len(rows))
        image, fast = Image(wire, book), FastImage(wire)
        for query in (probe, tuple(-q for q in probe), (1,)*len(probe)):
            expected = [sum(w*q for w, q in zip(row, query)) for row in rows]
            assert image.evaluate(query)['accumulators'] == expected
            assert fast.evaluate(query)['accumulators'] == expected
            queries_checked += 1
        # A dyadic slot may contain unused ranks; these must not decode.
        unused = next((s for s in book.slots if s.width > s.count), None)
        if unused:
            try:
                book.unrank(unused.offset+unused.count)
            except AssertionError:
                pass
            else:
                raise AssertionError('accepted a padding rank')
        try:
            Image(wire+b'\0', book)
        except AssertionError:
            pass
        else:
            raise AssertionError('accepted appended image bytes')
        rows_checked += len(rows)
    return dict(exhaustive_weight_roundtrips=rows_checked, exhaustive_query_panels=queries_checked,
                suffix_histograms_match=True, unused_ranks_rejected=True, malformed_length_rejected=True)


def digest(values):
    return hashlib.sha256(np.asarray(values, dtype='<i4').tobytes()).hexdigest()


def main():
    started = time.monotonic()
    validation = checks()
    fixture_path = HERE/'instances/bonsai-layer00-down-block0.npz'
    fixture = np.load(fixture_path)
    weights = fixture['trits'].tolist()
    queries = fixture['queries']
    at = time.monotonic()
    book = FiberBook(queries[0])
    book_seconds = time.monotonic()-at
    at = time.monotonic()
    wire = encode(book, weights, fixture['scale_bits'])
    encode_seconds = time.monotonic()-at
    path = HERE/'instances/bonsai-layer00-down-block0.fiber'
    path.write_bytes(wire)
    at = time.monotonic()
    image = Image(wire, book)
    decoded = [image.decode_weights(row) for row in range(len(weights))]
    assert decoded == weights
    assert list(image.scale_bits) == fixture['scale_bits'].tolist()
    full_decode_seconds = time.monotonic()-at
    at = time.monotonic()
    fast = FastImage(wire)
    fast_load_seconds = time.monotonic()-at
    hist = Counter(book.payload_bits-book.locate(image.full_code(row))[0].fiber_bits for row in range(len(weights)))
    cases = []
    for index, query in enumerate(list(queries)+[-queries[0], np.zeros(128, dtype=np.int8)]):
        at = time.monotonic()
        answer = fast.evaluate(query)
        elapsed = time.monotonic()-at
        reference = fixture['trits'].astype(np.int32)@query.astype(np.int32)
        assert answer['accumulators'] == reference.tolist()
        record = {k: v for k, v in answer.items() if k != 'accumulators'}
        record.update(case=index, source='capture' if index < 8 else 'sign/zero control',
                      output_sha256=digest(answer['accumulators']), elapsed_seconds=elapsed)
        cases.append(record)
    # One-coordinate perturbation is outside the fast pattern, not outside the codec.
    changed = queries[0].copy()
    changed[0] += 1 if changed[0] < 127 else -1
    at = time.monotonic()
    answer = fast.evaluate(changed)
    residual_seconds = time.monotonic()-at
    assert answer['accumulators'] == (fixture['trits'].astype(np.int32)@changed.astype(np.int32)).tolist()
    assert answer['path'] == 'fiber-unrank' and answer['decoded_prefix_length'] == 1
    residual_case = {k: v for k, v in answer.items() if k != 'accumulators'}
    residual_case.update(elapsed_seconds=residual_seconds, output_sha256=digest(answer['accumulators']))
    baseline = len(weights)*28
    counts_hist = Counter(int(x) for x in fixture['trits'].flat)
    files = ['fiber_codec.py', 'fiber_fast.py', 'fiber_experiments.py', 'check_fiber.py', 'fiber_fixture.py']
    result = dict(checks=validation, rows=len(weights), columns=128,
                  weight_symbols=len(weights)*128,
                  trit_histogram=counts_hist, alphabet_rows=3**128,
                  fiber_count=len(book.slots), rounded_fiber_mass=book.rounded_mass,
                  minimum_fixed_ternary_bits=ceil_log2(3**128), payload_bits_per_row=book.payload_bits,
                  scale_bits_per_row=16, prefix_length_histogram=dict(sorted(hist.items())),
                  serialized_bytes=len(wire), source_halo_bytes=baseline, saved_bytes=baseline-len(wire),
                  saving_fraction=1-len(wire)/baseline,
                  prefix_index_bytes=fast.packed_prefix_index_bytes,
                  serialized_plus_packed_index_bytes=len(wire)+fast.packed_prefix_index_bytes,
                  workspace=book.workspace(),
                  timing=dict(book_seconds=book_seconds, encode_seconds=encode_seconds,
                              full_decode_seconds=full_decode_seconds, fast_load_seconds=fast_load_seconds),
                  full_roundtrip=dict(trits_equal=True, scale_bits_equal=True,
                                      decoded_sha256=hashlib.sha256(np.asarray(decoded, dtype=np.int8).tobytes()).hexdigest()),
                  cases=cases, one_coordinate_miss_reconstructs=True, residual_query=residual_case,
                  fixture_sha256=hashlib.sha256(fixture_path.read_bytes()).hexdigest(),
                  wire_sha256=hashlib.sha256(wire).hexdigest(),
                  source_sha256={f: hashlib.sha256((HERE/f).read_bytes()).hexdigest() for f in files},
                  elapsed_seconds=time.monotonic()-started,
                  scope='Unconditional lossless storage for this complete 5120-row weight block. Prefix shortcut conditional on query +/-reference. No GPU/TPS claim.')
    (HERE/'fiber-results.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k: result[k] for k in ('checks','rows','payload_bits_per_row','serialized_bytes','source_halo_bytes',
                                            'saved_bytes','saving_fraction','prefix_index_bytes','timing','elapsed_seconds')}, indent=2))
    print(json.dumps(cases, indent=2))


if __name__ == '__main__':
    main()
