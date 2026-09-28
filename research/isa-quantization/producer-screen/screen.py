"""Screen a shared binary-carrier / free-readout family on a real Qwen projection block.

The candidate's executable stage forms r shared signed 128-way sums of the input;
its readout is permitted ANY real r-by-128 matrix in the lower bound. Thus every
candidate output matrix has rank <=r. This deliberately relaxes signs, FP16,
and code fitting, but retains the complete 128-output linear consumer.
"""
import hashlib
import json
from pathlib import Path

import numpy as np

FIXTURE = Path('/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz')
OUT = Path(__file__).with_name('results.json')
IMAGE = Path(__file__).with_name('affine-q4.bin')
ROWS = slice(0, 128)
COLS = slice(0, 128)


def relerr(actual, target):
    return float(np.sum((actual - target) ** 2) / np.sum(target ** 2))


def affine_grid(w, h):
    """Four-bit affine row grids; optimize step/origin against train response Hessian.

    The least-squares coefficients are refitted after assigning each grid, then
    rounded to FP16. This is a control, not a claim of globally optimal Q4.
    """
    quantized = []
    records = []
    for row in w:
        best = None
        for qlo, qhi in [(0, 100), (1, 99), (2, 98), (3, 97), (4, 96), (5, 95), (8, 92)]:
            lo, hi = np.percentile(row, [qlo, qhi])
            step = (hi - lo) / 15
            origin = lo
            for _ in range(5):
                codes = np.clip(np.rint((row - origin) / step), 0, 15)
                design = np.column_stack((np.ones(len(row)), codes))
                lhs = design.T @ h @ design
                rhs = design.T @ h @ row
                origin, step = np.linalg.solve(lhs, rhs)
                step = max(float(step), 1e-8)
            origin, step = np.float16(origin).astype('float64'), np.float16(step).astype('float64')
            codes = np.clip(np.rint((row - origin) / step), 0, 15)
            v = origin + codes * step
            score = float((v - row) @ h @ (v - row))
            if best is None or score < best[0]:
                best = (score, v, codes.astype('uint8'), origin, step)
        quantized.append(best[1])
        records.append(best[2:])
    return np.stack(quantized), records


def export_q4(records):
    # Row-major, 64 bytes per row (low nibble first) then two little-endian FP16s.
    image = bytearray()
    for codes, origin, step in records:
        image.extend((codes[0::2] | (codes[1::2] << 4)).tobytes())
        image.extend(np.asarray([origin, step], dtype='<f2').tobytes())
    IMAGE.write_bytes(image)
    assert len(image) == 128 * (64 + 4)
    return bytes(image)


def decode_q4(image):
    rows = []
    for offset in range(0, len(image), 68):
        packed = np.frombuffer(image, dtype='u1', count=64, offset=offset)
        codes = np.empty(128, dtype='float64')
        codes[0::2], codes[1::2] = packed & 15, packed >> 4
        origin, step = np.frombuffer(image, dtype='<f2', count=2, offset=offset + 64).astype('float64')
        rows.append(origin + step * codes)
    return np.stack(rows)


def modular_rank(a, denominator_power=28, prime=65521):
    """Exact dyadic rank witness: reduction of 2^28 times BF16/FP32 values."""
    scaled = a * (2 ** denominator_power)
    assert np.array_equal(scaled, np.rint(scaled))
    b = np.rint(scaled).astype(np.int64) % prime
    pivot = 0
    for col in range(b.shape[1]):
        choices = np.flatnonzero(b[pivot:, col])
        if not len(choices):
            continue
        row = pivot + int(choices[0])
        b[[pivot, row]] = b[[row, pivot]]
        inv = pow(int(b[pivot, col]), -1, prime)
        factors = b[pivot + 1:, col] * inv % prime
        b[pivot + 1:] = (b[pivot + 1:] - factors[:, None] * b[pivot]) % prime
        pivot += 1
        if pivot == min(b.shape):
            break
    return pivot


def q4_readout_grid(basis):
    """Quantize each output row to a signed 4-bit grid with one FP16 scale."""
    quantized = []
    records = []
    for row in basis:
        best = None
        for percentile in (95, 98, 100):
            scale = np.percentile(np.abs(row), percentile) / 7
            for _ in range(4):
                codes = np.clip(np.rint(row / scale), -7, 7)
                scale = float((row @ codes) / (codes @ codes))
            scale = float(np.float16(scale))
            codes = np.clip(np.rint(row / scale), -7, 7)
            score = np.linalg.norm(row - codes * scale) ** 2
            if best is None or score < best[0]:
                best = (score, codes * scale, codes.astype('int8'), scale)
        quantized.append(best[1])
        records.append(best[2:])
    return np.stack(quantized), records


def q4_readout_relaxation(target, basis):
    """Fix one signed Q4 readout, then grant arbitrary real input-side factors."""
    readout, _ = q4_readout_grid(basis)
    q, _ = np.linalg.qr(readout, mode='reduced')
    return float(np.sum((target - (target @ q) @ q.T) ** 2) / np.sum(target ** 2))


def main():
    with np.load(FIXTURE) as f:
        w = f['weight'][ROWS, COLS].astype('float64')
        train = f['train'][:, COLS].astype('float64')
        held = f['validation'][:, COLS].astype('float64')
    target = train @ w.T
    held_target = held @ w.T
    u, s, vt = np.linalg.svd(target, full_matrices=False)
    h = train.T @ train
    fitted, records = affine_grid(w, h)
    packed = export_q4(records)
    q4 = decode_q4(packed)
    assert np.array_equal(q4, fitted)
    q4_train = relerr(train @ q4.T, target)
    q4_held = relerr(held @ q4.T, held_target)
    # No unspecified affine intercept: both candidate and source map zero to zero.
    all_floors = np.cumsum(s[::-1] ** 2)[::-1] / np.sum(s ** 2)
    first_rank_below_q4 = next(r for r in range(1, 129)
                               if (float(all_floors[r]) if r < 128 else 0.) <= q4_train)
    ranks = []
    for rank in (4, 8, 12, 13, 16, 24, 30, 31, 32, 48, 64, first_rank_below_q4, 106):
        train_floor = float(np.sum(s[rank:] ** 2) / np.sum(s ** 2))
        response = (u[:, :rank] * s[:rank]) @ vt[:rank]
        lifted = np.linalg.lstsq(train, response, rcond=None)[0].T
        held_error = relerr(held @ lifted.T, held_target)
        # Sign-carrier payload: r*128 signs + FP16 matrix 128*r + FP16 per-carrier
        # input gain. It omits fixed instruction code and shared framing.
        bytes_ = rank * 128 // 8 + rank * 128 * 2 + rank * 2
        ranks.append(dict(rank=rank, optimistic_bytes=bytes_, train_floor=train_floor,
                          held_relerr_of_rank_projection=held_error,
                          rejected_by_q4_train=train_floor > q4_train))
    singular = np.linalg.svd(train, compute_uv=False)
    lowbit = []
    for rank in (67, 80, 96, 103):
        lowbit.append(dict(rank=rank, bytes=82*rank + 256,
                           train_error_with_q4_readout_and_free_input=q4_readout_relaxation(target, vt[:rank].T)))
    result = dict(source=str(FIXTURE), sha256=hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
                  rows=[ROWS.start, ROWS.stop], columns=[COLS.start, COLS.stop],
                  train_rows=len(train), held_rows=len(held),
                  train_rank=int(np.linalg.matrix_rank(train)),
                  modular_rank_certificate=dict(prime=65521, denominator_power=28,
                                                weight=modular_rank(w), train=modular_rank(train)),
                  train_singular_ratio=float(singular[-1] / singular[0]),
                  q4=dict(bytes=len(packed), image=str(IMAGE.relative_to(Path(__file__).parents[2])),
                          sha256=hashlib.sha256(packed).hexdigest(), train_relerr=q4_train,
                          held_relerr=q4_held), rank_families=ranks,
                  lowbit_readout=lowbit,
                  description_contrast=dict(
                      first_rank_whose_real_response_floor_does_not_exceed_q4=first_rank_below_q4,
                      fp16_readout_bytes_at_that_rank=274*first_rank_below_q4,
                      four_bit_readout_bytes_at_that_rank=82*first_rank_below_q4+256,
                      max_four_bit_readout_rank_at_q4_bytes=(len(packed)-256)//82,
                      four_bit_readout_explanation='signed input plane 16r bytes, packed signed 4-bit output plane 64r bytes, FP16 input gain 2r bytes, FP16 scale for each of 128 output rows 256 bytes'),
                  zero_coefficient_count=int(np.count_nonzero(w == 0)),
                  producer_sign_distinct_train=int(len(np.unique(np.sign(train).astype('i1'), axis=0))),
                  producer_sign_distinct_held=int(len(np.unique(np.sign(held).astype('i1'), axis=0))),
                  producer_exact_binary_train=bool(np.all(np.abs(train) == 1)),
                  producer_exact_binary_held=bool(np.all(np.abs(held) == 1)),
                  train_and_held_extrema=[float(train.min()), float(train.max()), float(held.min()), float(held.max())])
    OUT.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
