"""Paid template-plus-residual integer program against per-row scalar quantization."""
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from safetensors import safe_open

MODEL = Path('/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/model.safetensors')
KEY = 'model.layers.0.self_attn.q_proj.weight'
N, K, GROUP = 128, 128, 8
HERE = Path(__file__).resolve().parent


def bits(values, width):
    # Least-significant-bit first; no row padding for these dimensions.
    flat = np.asarray(values, np.int64).ravel()
    assert np.all((flat >= 0) & (flat < 1 << width))
    v = ((flat[:, None] >> np.arange(width)) & 1).astype(np.uint8).ravel()
    return np.packbits(v, bitorder='little').tobytes()


def unbits(payload, width, shape):
    v = np.unpackbits(np.frombuffer(payload, dtype=np.uint8), bitorder='little')
    v = v[:int(np.prod(shape)) * width].reshape(-1, width)
    return (v.astype(np.int32) @ (1 << np.arange(width, dtype=np.int32))).reshape(shape)


def scalar(w, width):
    lo, hi = -(1 << (width - 1)), (1 << (width - 1)) - 1
    q = np.empty(w.shape, np.int32)
    scales = np.empty(w.shape[0], np.float16)
    for row, data in enumerate(w):
        a = float(np.max(np.abs(data)))
        candidates = np.geomspace(max(a / (hi * 2.5), 1e-8), max(a / (hi * .65), 2e-8), 128)
        best = float('inf')
        for s in np.unique(candidates.astype(np.float16)):
            if s == 0:
                continue
            c = np.clip(np.rint(data / float(s)), lo, hi).astype(np.int32)
            err = np.sum((data - float(s) * c) ** 2)
            if err < best:
                best, q[row], scales[row] = err, c, s
    payload = bits(q - lo, width)
    decoded = unbits(payload, width, w.shape) + lo
    assert np.array_equal(decoded, q)
    return decoded, scales, len(payload) + scales.nbytes


def additive(w):
    groups = len(w) // GROUP
    base = np.empty((groups, K), np.int32)
    residual = np.empty(w.shape, np.int32)
    scales = np.empty(groups, np.float16)
    for g in range(groups):
        rows = w[g * GROUP:(g + 1) * GROUP]
        mean = np.mean(rows, axis=0)
        spread = np.max(np.abs(rows - mean))
        maximum = np.max(np.abs(rows))
        minimum = max(maximum / 256, spread / 14, np.max(np.abs(mean)) / 127, 1e-8)
        candidates = np.geomspace(minimum * .7, max(minimum * 2, maximum / 3), 160)
        best = float('inf')
        for s in np.unique(candidates.astype(np.float16)):
            if s == 0:
                continue
            x = rows / float(s)
            center = np.clip(np.rint(mean / float(s)), -128, 127).astype(np.int32)
            choices = np.clip(center[:, None] + np.arange(-5, 6), -128, 127)
            r = np.clip(np.rint(x[:, :, None] - choices[None, :, :]), -8, 7).astype(np.int32)
            errs = np.sum((rows[:, :, None] - float(s) * (choices[None, :, :] + r)) ** 2, axis=0)
            indices = np.argmin(errs, axis=1)
            b = choices[np.arange(K), indices]
            rr = r[:, np.arange(K), indices]
            err = float(np.sum((rows - float(s) * (b[None, :] + rr)) ** 2))
            if err < best:
                best, scales[g], base[g], residual[g * GROUP:(g + 1) * GROUP] = err, s, b, rr
    base_payload = bits(base + 128, 8)
    residual_payload = bits(residual + 8, 4)
    b = unbits(base_payload, 8, base.shape) - 128
    r = unbits(residual_payload, 4, residual.shape) - 8
    assert np.array_equal(b, base) and np.array_equal(r, residual)
    return b, r, scales, len(base_payload) + len(residual_payload) + scales.nbytes


def report(w, seed, executable):
    rng = np.random.default_rng(seed)
    x = rng.integers(-127, 128, (256, K), dtype=np.int16).astype(np.int32)
    reference = x.astype(np.float64) @ w.T
    result = {}
    native_images = {}
    for width in (4, 5, 6):
        q, scale, storage = scalar(w, width)
        if width == 5:
            native_images['scalar5.bin'] = bits(q + 16, 5)
            native_images['scalar5-scale.bin'] = scale.astype(np.float32).tobytes()
        sums = x @ q.T  # int32; integer dot is the online contraction.
        output = sums * scale.astype(np.float64)
        if width == 5:
            scalar_checksum = float(np.sum(output[:64]) * 256)
        reconstructed = q * scale[:, None].astype(np.float64)
        result[f'scalar{width}'] = statistics(w, reconstructed, reference, output, storage, sums, width)
    b, r, scale, storage = additive(w)
    native_images.update({'base.bin': bits(b + 128, 8), 'residual.bin': bits(r + 8, 4),
                          'additive-scale.bin': scale.astype(np.float32).tobytes(),
                          'queries.bin': x[:64].astype(np.int8).tobytes()})
    with tempfile.TemporaryDirectory() as temporary:
        for name, image in native_images.items():
            (Path(temporary) / name).write_bytes(image)
        native = json.loads(subprocess.check_output([str(executable), temporary], timeout=40))
    shared = x @ b.T
    corrections = x @ r.T
    sums = shared[:, np.arange(N) // GROUP] + corrections
    output = sums * scale[np.arange(N) // GROUP].astype(np.float64)
    assert abs(native['scalar5_checksum'] - scalar_checksum) < .001
    assert abs(native['additive_checksum'] - float(np.sum(output[:64]) * 256)) < .001
    reconstructed = (b[np.arange(N) // GROUP] + r) * scale[np.arange(N) // GROUP, None].astype(np.float64)
    result['template8_residual4'] = statistics(w, reconstructed, reference, output, storage, sums, 4, 136)
    result['template8_residual4']['online'] = 'Per 8 rows: one signed int8 template dot, eight signed int4 residual dots, eight int32 adds, eight FP scale multiplies; packed int4 extraction and one shared int8 load. Integer labels can stay live only if the next consumer accepts the common group scale.'
    result['template8_residual4']['max_abs_template'] = int(np.max(np.abs(b)))
    result['template8_residual4']['max_abs_residual'] = int(np.max(np.abs(r)))
    result['native'] = native
    return result


def statistics(w, reconstructed, reference, output, storage, sums, width, max_coefficient=None):
    error = output - reference
    return {
        'bytes': int(storage),
        'bits_per_weight': round(storage * 8 / w.size, 6),
        'weight_relative_rms': float(np.linalg.norm(w - reconstructed) / np.linalg.norm(w)),
        'probe_relative_rms': float(np.linalg.norm(error) / np.linalg.norm(reference)),
        'max_row_box_error_at_abs_x_le_127': float(127 * np.max(np.sum(np.abs(w - reconstructed), axis=1))),
        'max_abs_int32_accumulator_observed': int(np.max(np.abs(sums))),
        'full_box_int32_bound': int(127 * K * (max_coefficient if max_coefficient is not None else (1 << (width - 1)))),
        'online': f'Per row: one signed int{width} dot, one FP scale multiply; unpack {width}-bit codes. No scale-free FP boundary.'
    }


def main():
    with tempfile.TemporaryDirectory() as build:
        executable = Path(build) / 'native'
        subprocess.run(['g++', '-O3', '-std=c++17', '-o', str(executable), str(HERE / 'native.cpp')],
                       check=True, timeout=30)
        receipt = run(executable)
    (HERE / 'results.json').write_text(json.dumps(receipt, indent=2) + '\n')
    for label in ('real', 'planted'):
        print(label, [(k, v['bytes'], round(v['probe_relative_rms'], 6))
                      for k, v in receipt[label].items() if k != 'native'])
        print('native', receipt[label]['native'])


def run(executable):
    with safe_open(MODEL, framework='pt', device='cpu') as handle:
        w = handle.get_slice(KEY)[:N, :K].float().numpy().astype(np.float64)
    real = report(w, 240923, executable)
    rng = np.random.default_rng(334)
    template = rng.normal(0, .020, (N // GROUP, K))
    paired = np.repeat(template, GROUP, axis=0) + rng.normal(0, .0008, (N, K))
    planted = report(paired, 240924, executable)
    receipt = {
        'model': str(MODEL), 'model_sha256': hashlib.file_digest(MODEL.open('rb'), 'sha256').hexdigest(),
        'tensor': KEY, 'slice': '[0:128,0:128]', 'source_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'native_sha256': hashlib.sha256((HERE / 'native.cpp').read_bytes()).hexdigest(),
        'fixture': 'original BF16 tensor converted exactly to FP64; planted common Gaussian template and independent Gaussian perturbations, NumPy seed 334',
        'probes': '256 independent signed int8 vectors per fixture, uniform [-127,127], seeds 240923 and 240924',
        'real': real, 'planted': planted,
    }
    return receipt


if __name__ == '__main__':
    main()
