#!/usr/bin/env python3
"""Price bitplane contraction on the paid binary factors and matched Qwen inputs."""
import hashlib
import json
from pathlib import Path

import numpy as np

IMAGES = Path('/path/to/workspace/data/kelana-subbit/binary-factors/fixtures')
FIXTURES = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext')
OUT = Path('/path/to/workspace/data/kelana-subbit/binary-bitplane-dot/receipt.json')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quantize(a, bits):
    maximum = (1 << (bits - 1)) - 1
    scale = max(float(np.max(np.abs(a))) / maximum, 1e-30)
    return np.clip(np.rint(a / scale), -maximum - 1, maximum).astype(np.int16), scale


def bitplane_dot(packed_signs, integer_input, bits):
    """Each 32-coordinate word consumes the original packed U/V bits directly."""
    rows, packed_bytes = packed_signs.shape
    assert integer_input.size % 32 == 0 and packed_bytes == integer_input.size // 8
    signs = packed_signs.view('<u4').reshape(rows, -1)
    masks = []
    totals = []
    unsigned = integer_input.astype(np.int64) & ((1 << bits) - 1)
    for bit in range(bits):
        plane = np.packbits(((unsigned >> bit) & 1).astype(np.uint8), bitorder='little').view('<u4')
        masks.append(plane)
        totals.append(int(np.bitwise_count(plane).sum()))
    result = np.zeros(rows, dtype=np.int64)
    for bit, (plane, total) in enumerate(zip(masks, totals)):
        counts = np.bitwise_count(signs & plane[None, :]).sum(axis=1, dtype=np.int64)
        coefficient = -(1 << bit) if bit == bits - 1 else 1 << bit
        result += coefficient * (2 * counts - total)
    return result


def grouped_response(signs, inputs, bits):
    groups = inputs.size // 32
    codes = []
    scales = []
    for word in inputs.reshape(groups, 32):
        q, scale = quantize(word, bits)
        codes.append(q)
        scales.append(scale)
    code = np.stack(codes).astype(np.int32)
    scale = np.asarray(scales)
    partial = np.einsum('rgk,gk->rg', signs.reshape(signs.shape[0], groups, 32).astype(np.int32), code, optimize=True)
    return partial.astype(np.float64) @ scale


def relative_rms(a, b):
    return float(np.linalg.norm(a - b) / np.linalg.norm(b))


def main():
    entries = []
    for path in sorted(IMAGES.glob('*_0.55.npz')):
        with np.load(path) as image:
            n, k, rank = map(int, image['dimensions'])
            u = image['U'].copy()
            v = image['V'].copy()
            pre = image['scale_pre'].astype(np.float64)
            post = image['scale_post'].astype(np.float64)
        layer = int(path.name.split('_')[2])
        key = path.stem.split('_weight_')[0].split(f'model_layers_{layer}_')[1]
        fixture = FIXTURES / f'layer{layer:02d}-{key}.npz'
        with np.load(fixture) as f:
            inputs = f['validation'][:4].astype(np.float64)
        vs = 2 * np.unpackbits(v, axis=1, count=k, bitorder='little').astype(np.int16) - 1
        us = 2 * np.unpackbits(u, axis=1, count=rank, bitorder='little').astype(np.int16) - 1
        results = {str(bits): [] for bits in (4, 5, 6, 7, 8)}
        for x in inputs:
            a = x * pre
            h = vs.astype(np.float64) @ a
            reference = (us.astype(np.float64) @ h) * post
            for bits in (4, 5, 6, 7, 8):
                qa, sa = quantize(a, bits)
                qh, sh = quantize(h, bits)
                first = bitplane_dot(v, qa, bits)
                second = bitplane_dot(u, qh, bits)
                assert np.array_equal(first, vs.astype(np.int32) @ qa.astype(np.int32))
                assert np.array_equal(second, us.astype(np.int32) @ qh.astype(np.int32))
                first_only = (us.astype(np.float64) @ (first * sa)) * post
                second_only = (second * sh) * post
                qchain, sc = quantize(first * sa, bits)
                combined = bitplane_dot(u, qchain, bits) * sc * post
                grouped_h = grouped_response(vs, a, bits)
                grouped_y = grouped_response(us, grouped_h, bits) * post
                results[str(bits)].append({
                    'group32_chain_rms': relative_rms(grouped_y, reference),
                    'first_rms': relative_rms(first_only, reference),
                    'second_rms': relative_rms(second_only, reference),
                    'chain_rms': relative_rms(combined, reference),
                    'first_scale': sa, 'second_scale': sh, 'chain_scale': sc,
                })
        entries.append({'image': str(path), 'image_sha256': sha(path), 'fixture_sha256': sha(fixture),
                        'projection': key, 'layer': layer, 'n': n, 'k': k, 'rank': rank,
                        'samples': results, 'work': {'factor_words': rank*k//32+n*rank//32,
                          'weighted_popcounts': {str(b): b*(rank*k//32+n*rank//32) for b in (4, 5, 6, 7, 8)},
                          'weight_bytes': (rank*k+n*rank)//8,
                          'input_plane_words': {str(b): b*(k+rank)//32 for b in (4, 5, 6, 7, 8)}}})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    receipt = {'source_sha256': sha(Path(__file__)), 'contract': 'four previously inspected validation input rows/image; frozen 0.55 packed binary U/V, pre/post scales; per-vector symmetric max dynamic signed A4..A8 rounded-to-even integer activation at both factors, both vector-wide and independent 32-coordinate group scales; exact int64 bitplane responses and independent dense integer checks; original binary-factor FP64 map as denominator; original-producer inputs, no GPU', 'entries': entries}
    OUT.write_text(json.dumps(receipt, indent=2) + '\n')
    for projection in sorted(set(e['projection'] for e in entries)):
        group = [e for e in entries if e['projection'] == projection]
        print(projection, {bits: round(float(np.mean([s['chain_rms'] for e in group for s in e['samples'][bits]])), 6) for bits in ('4', '5', '6', '7', '8')})
    print(OUT)


if __name__ == '__main__':
    main()
