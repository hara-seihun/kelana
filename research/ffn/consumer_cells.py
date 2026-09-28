#!/usr/bin/env python3
"""Explore quantizer equivalence cells; CPU semantic experiment, not a GPU speedup."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

import numpy as np

DTYPES = {0: '<u1', 1: '<i1', 2: '<u2', 3: '<i2', 4: '<u4', 5: '<i4',
          6: '<f4', 7: '?', 10: '<u8', 11: '<i8', 12: '<f8'}


def metadata(path, wanted):
    def read(fmt):
        return struct.unpack(fmt, f.read(struct.calcsize(fmt)))[0]

    def string():
        return f.read(read('<Q')).decode()

    def value(kind, retain):
        if kind == 8:
            n = read('<Q')
            if retain:
                return f.read(n).decode()
            f.seek(n, 1)
        elif kind == 9:
            element, n = read('<I'), read('<Q')
            if element in DTYPES:
                dtype = np.dtype(DTYPES[element])
                if retain:
                    return np.frombuffer(f.read(n*dtype.itemsize), dtype=dtype).copy()
                f.seek(n*dtype.itemsize, 1)
            else:
                values = [value(element, retain) for _ in range(n)]
                if retain:
                    return values
        else:
            dtype = np.dtype(DTYPES[kind])
            raw = f.read(dtype.itemsize)
            if retain:
                return np.frombuffer(raw, dtype=dtype)[0].item()

    found = {}
    with path.open('rb') as f:
        assert f.read(4) == b'GGUF'
        assert read('<I') in (2, 3)
        read('<Q')
        count = read('<Q')
        for _ in range(count):
            key, kind = string(), read('<I')
            v = value(kind, key in wanted)
            if key in wanted:
                found[key] = v
            if len(found) == len(wanted):
                break
    assert set(found) == set(wanted)
    return found


def hadamard(x):
    y = np.array(x, copy=True)
    n = y.shape[-1]
    assert n > 0 and n & (n-1) == 0
    for bit in range(n.bit_length()-1):
        size = 1 << bit
        pairs = y.reshape(*y.shape[:-1], -1, 2, size)
        left, right = pairs[..., 0, :].copy(), pairs[..., 1, :].copy()
        pairs[..., 0, :] = left + right
        pairs[..., 1, :] = left - right
    return y


def quant_integer(z):
    blocks = z.reshape(-1, 128)
    maxima = np.max(np.abs(blocks), axis=-1, keepdims=True)
    assert np.all(maxima > 0)
    num = 127 * blocks
    q, remainder = np.divmod(num, maxima)
    q += ((2*remainder > maxima) | ((2*remainder == maxima) & (q % 2 != 0)))
    return q.reshape(z.shape), maxima.ravel()


def quant_float(z):
    blocks = z.reshape(-1, 128)
    maxima = np.max(np.abs(blocks), axis=-1, keepdims=True)
    inverse = np.divide(np.float32(127), maxima, out=np.zeros_like(maxima), where=maxima > 0)
    return np.rint(blocks * inverse).astype(np.int16), maxima.ravel() / np.float32(127)


def exact_example():
    rng = np.random.default_rng(20260919)
    n = 1024
    v = rng.integers(-16, 17, size=n, dtype=np.int64)
    z = hadamard(v)
    q, m = quant_integer(z)
    peaks = np.arange(8)*128 + np.argmax(np.abs(z.reshape(8,128)), axis=1)
    assert all(np.count_nonzero(np.abs(z[b*128:(b+1)*128]) == m[b]) == 1 for b in range(8))
    candidates = []
    for j in range(n):
        changed = z.copy()
        changed[j] += 1
        q1, m1 = quant_integer(changed)
        if np.array_equal(q, q1) and np.array_equal(m, m1):
            candidates.append(j)
    j = next(k for k in candidates if k not in peaks)
    row = np.array([1 if (j & i).bit_count() % 2 == 0 else -1 for i in range(n)], dtype=np.int64)
    original, alternative = n*v, n*v+row
    za, zb = hadamard(original), hadamard(alternative)
    delta = np.zeros(n, dtype=np.int64); delta[j] = n
    assert np.array_equal(zb-za, delta)
    qa, ma = quant_integer(za); qb, mb = quant_integer(zb)
    assert np.array_equal(qa, qb) and np.array_equal(ma, mb)
    # These particular integer butterflies are also exactly representable in FP32.
    assert np.array_equal(hadamard(original.astype(np.float32)), za)
    assert np.array_equal(hadamard(alternative.astype(np.float32)), zb)
    qaf, saf = quant_float(za.astype(np.float32)/np.float32(32))
    qbf, sbf = quant_float(zb.astype(np.float32)/np.float32(32))
    assert np.array_equal(qaf, qbf) and np.array_equal(saf.view(np.uint32), sbf.view(np.uint32))
    return {'input_dimension': n, 'scale_groups': 8,
            'coordinates_changed': int(np.count_nonzero(original != alternative)),
            'changed_hadamard_coordinate': j, 'selected_maximum_coordinates': peaks.tolist(),
            'one_unit_hadamard_perturbations_preserving_encoding': len(candidates),
            'nonmaximum_directions': n-8,
            'exact_integer_codes_and_maxima_equal': True,
            'numpy_fp32_codes_and_scale_bits_equal': True,
            'original_v': original.tolist(), 'alternative_v': alternative.tolist()}


def capture_probe(root, signs, layers):
    reports, hashes = [], {}
    for layer in layers:
        tensors = []
        for name in ['ffn_gate', 'ffn_up']:
            p = root/f'{name}-{layer}.bin'
            raw = p.read_bytes(); hashes[p.name] = hashlib.sha256(raw).hexdigest()
            tensors.append(np.frombuffer(raw, dtype='<f4').copy())
        g, u = tensors
        assert len(g) == len(signs) == len(u)
        assert np.isfinite(g).all() and np.isfinite(u).all()

        def activation(gate, up):
            return ((gate / (np.float32(1) + np.exp(-gate))) * up) * signs

        v = activation(g, u)
        gh, uh = g.astype(np.float16), u.astype(np.float16)
        approx = activation(gh.astype(np.float32), uh.astype(np.float32))
        z = hadamard(v.reshape(-1,1024)) * np.float32(1/32)
        za = hadamard(approx.reshape(-1,1024)) * np.float32(1/32)
        q, scale = quant_float(z)
        qa, scalea = quant_float(za)
        block = z.reshape(-1,128)
        blocka = za.reshape(-1,128)
        maxima = np.max(np.abs(block), axis=1, keepdims=True)
        qa_fixed = np.rint(blocka * (np.float32(127)/maxima)).astype(np.int16)
        # This is the exact L1 error bound for the REAL Hadamard map on these FP32 inputs.
        # NumPy butterfly rounding is reported separately, not covered by this certificate.
        error = np.abs(approx.astype(np.float64)-v.astype(np.float64)).reshape(-1,1024)
        real_z = hadamard(v.astype(np.float64).reshape(-1,1024))/32
        real_a = hadamard(approx.astype(np.float64).reshape(-1,1024))/32
        bound = np.repeat(np.sum(error, axis=1)/32, 8)[:,None]
        real_blocks = real_z.reshape(-1,128)
        real_approx = real_a.reshape(-1,128)
        real_max = np.max(np.abs(real_blocks), axis=1, keepdims=True)
        reference_q = np.rint(127*real_blocks/real_max)
        center = 127*real_approx/real_max
        radius = 127*bound/real_max
        predicted_q = np.rint(center)
        certified = (center-radius > predicted_q-.5) & (center+radius < predicted_q+.5)
        assert np.all(predicted_q[certified] == reference_q[certified])
        # A producer could instead supply these rounding-cell bounds without the original g/u.
        def half_radius(x):
            value = x.astype(np.float64)
            below = np.nextafter(x, np.float16(-np.inf)).astype(np.float64)
            above = np.nextafter(x, np.float16(np.inf)).astype(np.float64)
            return np.maximum(value-below, above-value)/2
        dg, du = half_radius(gh), half_radius(uh)
        gc, uc = gh.astype(np.float64), uh.astype(np.float64)
        # |SiLU'| <= 2 and |SiLU(g)| <= |g| give this real-arithmetic product bound.
        product_bound = 2*(np.abs(uc)+du)*dg + np.abs(gc)*du
        input_cell_radius = np.repeat(np.sum(product_bound.reshape(-1,1024),axis=1)/32,8)[:,None]
        ideal_center = hadamard(((gc/(1+np.exp(-gc)))*uc*signs).reshape(-1,1024))/32
        ideal_true = hadamard(((g.astype(np.float64)/(1+np.exp(-g.astype(np.float64))))*u.astype(np.float64)*signs).reshape(-1,1024))/32
        ideal_m = np.max(np.abs(ideal_true.reshape(-1,128)),axis=1,keepdims=True)
        ratio_center = 127*ideal_center.reshape(-1,128)/ideal_m
        predicted = np.rint(ratio_center)
        radius_input = 127*input_cell_radius/ideal_m
        input_certified = (ratio_center-radius_input > predicted-.5) & (ratio_center+radius_input < predicted+.5)
        ideal_q = np.rint(127*ideal_true.reshape(-1,128)/ideal_m)
        assert np.all(predicted[input_certified] == ideal_q[input_certified])
        changed_code = q != qa
        reports.append({'layer': layer, 'values': int(g.size), 'groups': int(len(scale)),
                        'changed_integer_codes': int(np.count_nonzero(changed_code)),
                        'changed_scale_bit_patterns': int(np.count_nonzero(scale.view(np.uint32) != scalea.view(np.uint32))),
                        'unchanged_complete_group_encodings': int(np.count_nonzero(
                            np.all(~changed_code, axis=1) & (scale.view(np.uint32) == scalea.view(np.uint32)))),
                        'changed_codes_with_original_scale_pinned': int(np.count_nonzero(q != qa_fixed)),
                        'changed_maximum_indices': int(np.count_nonzero(np.argmax(np.abs(block),axis=1) != np.argmax(np.abs(blocka),axis=1))),
                        'real_model_fixed_maximum_L1_certified_codes': int(np.count_nonzero(certified)),
                        'real_model_fixed_maximum_actual_equal_codes': int(np.count_nonzero(predicted_q == reference_q)),
                        'real_model_input_rounding_cell_certified_codes': int(np.count_nonzero(input_certified)),
                        'relative_hidden_L2_error': float(np.linalg.norm(v.astype(np.float64)-approx)/np.linalg.norm(v.astype(np.float64))),
                        'scope': 'FP16 is a perturbation probe, not a proposed optimization. Float32 NumPy exp is not HIP __expf.'})
    return reports, hashes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, default=Path('/path/to/workspace/data/bonsai2/PTQ1_0.gguf'))
    parser.add_argument('--captures', type=Path, default=Path('/tmp/halo/r1'))
    parser.add_argument('--output', type=Path, default=Path(__file__).with_suffix('.json'))
    args = parser.parse_args()
    meta = metadata(args.model, {'prism.hadamard.sign_widths', 'prism.hadamard.sign_values'})
    widths = meta['prism.hadamard.sign_widths'].tolist()
    start = sum(widths[:widths.index(17408)])
    signs = meta['prism.hadamard.sign_values'][start:start+17408].astype(np.float32)
    assert np.isin(signs, [-1,1]).all()
    reports, hashes = capture_probe(args.captures, signs, [0,12,25,38,51,63])
    result = {'source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'reference': 'Existing last-token reference captures; CPU FP32 semantic probe and separate exact-integer construction.',
              'capture_root': str(args.captures), 'capture_sha256': hashes,
              'signs_sha256': hashlib.sha256(signs.tobytes()).hexdigest(),
              'exact_example': exact_example(), 'perturbation_probe': reports}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({'exact_example': {k:v for k,v in result['exact_example'].items() if k not in ['original_v','alternative_v']},
                      'perturbation_probe': reports}, indent=2))


if __name__ == '__main__':
    main()
