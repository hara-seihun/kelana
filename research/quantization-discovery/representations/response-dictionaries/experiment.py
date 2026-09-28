#!/usr/bin/env python3
"""Paid, held-row response dictionaries on the real Bonsai integer block."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import time

import numpy as np
from sklearn.cluster import KMeans

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'instances/bonsai-layer00-down-block0.npz'
OUT = Path(__file__).with_name('results.json')
ROWS_TRAIN = 4096
SEED = 230923


def response_error(original, approximated, scales, queries, rows):
    target = original[rows].astype(np.float32) @ queries.T
    predicted = approximated[rows].astype(np.float32) @ queries.T
    scale = scales[rows, None].astype(np.float32)
    return float(np.sqrt(np.mean(np.square((predicted - target) * scale))) /
                 np.sqrt(np.mean(np.square(target * scale))))


def native_timing(indices, centers, scales, queries):
    n, chunks = indices.shape
    bits = int(np.log2(centers.shape[1]))
    sequence = indices.reshape(-1).astype(np.uint16)
    bitplanes = ((sequence[:, None] >> np.arange(bits)) & 1).astype(np.uint8).reshape(-1)
    packed = np.packbits(bitplanes, bitorder='little')
    with tempfile.TemporaryDirectory(prefix='kelana-dictionary-') as temporary:
        directory = Path(temporary)
        (directory/'ids.bin').write_bytes(packed.tobytes())
        (directory/'dictionary.bin').write_bytes(centers.tobytes())
        (directory/'scales.bin').write_bytes(scales.tobytes())
        (directory/'queries.bin').write_bytes(queries.astype(np.int8).tobytes())
        decoded = centers[np.arange(chunks)[None, :], indices]
        reference = np.einsum('nck,qck->qn', decoded.astype(np.float32).reshape(n, chunks, 8),
                              queries.reshape(-1, chunks, 8), optimize=True)
        reference *= scales.astype(np.float32)[None, :]
        (directory/'expected.bin').write_bytes(reference.astype(np.float32).tobytes())
        binary = directory/'native'
        subprocess.run(['g++', '-O3', '-march=native', '-std=c++20', str(Path(__file__).with_name('native.cpp')),
                        '-o', str(binary)], check=True, timeout=30)
        output = subprocess.run([str(binary), str(directory), str(n), str(centers.shape[1]), '31'],
                                check=True, text=True, capture_output=True, timeout=30)
        result = json.loads(output.stdout)
        assert result['max_absolute_output_error'] < 0.001, result
        return result


def evaluate(weights, scales, queries, sizes, benchmark=False):
    n, width = weights.shape
    chunks = width // 8
    held = slice(ROWS_TRAIN, n)
    allrows = slice(None)
    timings = {}
    results = []
    t = time.perf_counter()
    sign = np.where(weights < 0, -1, 1).astype(np.float32)
    gain = np.sum(weights * sign, axis=1) / width
    sign_approx = (sign * gain[:, None].astype(np.float16)).astype(np.float32)
    folded_gain = (scales.astype(np.float32)*gain).astype(np.float16)
    folded_output = sign * folded_gain[:, None].astype(np.float32)
    exact_scaled_output = weights.astype(np.float32)*scales[:, None].astype(np.float32)
    sparse = np.zeros_like(weights)
    # Four bits per eight values: one signed unit at a selected coordinate.
    # Nonzeros are tied under this source's ternary magnitudes; fixed first tie.
    for j in range(chunks):
        part = weights[:, j*8:(j+1)*8]
        position = np.argmax(np.abs(part), axis=1)
        sparse[np.arange(n), j*8+position] = part[np.arange(n), position]
    timings['scalar_controls_seconds'] = time.perf_counter() - t
    results.append(dict(name='one_bit_sign_folded_fp16_scale', physical_bytes=n*16+n*2,
                        online='128 sign-controlled input terms and one combined FP16 row scale',
                        held_row_relative_rms=response_error(exact_scaled_output, folded_output,
                                                             np.ones(n), queries, held),
                        all_row_relative_rms=response_error(exact_scaled_output, folded_output,
                                                            np.ones(n), queries, allrows),
                        fp16_zero_scale_rows=int(np.count_nonzero(folded_gain == 0)),
                        fp16_infinite_scale_rows=int(np.count_nonzero(~np.isfinite(folded_gain)))))
    for label, reconstruction, bytes_, operations in [
        ('one_bit_sign_row_gain', sign_approx, n*16 + n*2 + n*2,
         '128 sign-controlled products plus one FP16 gain and source scale per row'),
        ('one_spike_per_8', sparse, n*chunks//2+n*2,
         '16 input gathers and signed additions per row; table-free'),
        ('exact_base3_halo', weights, n*26+n*2,
         '128 ternary input terms per row, or the separately measured sign-orbit SIMD consumer'),
    ]:
        results.append(dict(name=label, physical_bytes=bytes_, online=operations,
                            held_row_relative_rms=response_error(weights, reconstruction, scales, queries, held),
                            all_row_relative_rms=response_error(weights, reconstruction, scales, queries, allrows)))
    for k in sizes:
        t = time.perf_counter()
        centers = np.empty((chunks, k, 8), dtype=np.float16)
        indices = np.empty((n, chunks), dtype=np.uint8)
        reconstruct = np.empty(weights.shape, dtype=np.float16)
        for j in range(chunks):
            block = weights[:, j*8:(j+1)*8].astype(np.float32)
            fit = KMeans(n_clusters=k, n_init=1, max_iter=25, random_state=SEED+j,
                         algorithm='lloyd').fit(block[:ROWS_TRAIN])
            centers[j] = fit.cluster_centers_.astype(np.float16)
            # Quantized centroids are the actual stored operand; assign against them.
            delta = block[:, None, :] - centers[j][None, :, :].astype(np.float32)
            indices[:, j] = np.argmin(np.sum(delta*delta, axis=2), axis=1)
            reconstruct[:, j*8:(j+1)*8] = centers[j, indices[:, j]]
        timings[f'learned_k{k}_seconds'] = time.perf_counter() - t
        bits = int(np.log2(k))
        assert 2**bits == k
        packed_id_bytes = (n*chunks*bits+7)//8
        dictionary_bytes = centers.nbytes
        measured = native_timing(indices, centers, scales, queries) if benchmark and k in (16, 64) else None
        results.append(dict(name=f'learned_k{k}', physical_bytes=packed_id_bytes+dictionary_bytes+n*2,
                            native_single_core=measured,
                            ids_bytes=packed_id_bytes, dictionary_bytes=dictionary_bytes,
                            source_scale_bytes=n*2, id_bits=bits,
                            online=f'{chunks*k*8} float16 coefficient-input products for fresh table preparation, '
                                   f'{n*chunks} packed-ID lookups and FP32 response additions, {n} row scales; '
                                   'no reconstructed weights at inference',
                            held_row_relative_rms=response_error(weights, reconstruct, scales, queries, held),
                            all_row_relative_rms=response_error(weights, reconstruct, scales, queries, allrows),
                            held_row_weight_mse=float(np.mean((weights[held]-reconstruct[held])**2)),
                            occupied_codes=[int(len(np.unique(indices[:, j]))) for j in range(chunks)]))
    return results, timings


def motif_counts(weights):
    observations = {}
    for width in (4, 8, 16):
        unique = []
        top16 = []
        for start in range(0, weights.shape[1], width):
            _, counts = np.unique(weights[:, start:start+width], axis=0, return_counts=True)
            unique.append(len(counts))
            top16.append(sum(sorted(counts, reverse=True)[:16])/weights.shape[0])
        observations[str(width)] = dict(mean_unique=float(np.mean(unique)),
                                        mean_top16_fraction=float(np.mean(top16)),
                                        min_unique=min(unique), max_unique=max(unique))
    return observations


def main():
    data = np.load(FIXTURE)
    weights, scales, queries = data['trits'], data['scales_fp16'], data['queries'].astype(np.float32)
    real, timing_real = evaluate(weights, scales, queries, [4, 16, 64], benchmark=True)
    rng = np.random.default_rng(SEED)
    # Independent coordinates, matched empirical marginal trit probabilities.
    values, counts = np.unique(weights, return_counts=True)
    shuffled = rng.choice(values, weights.shape, p=counts/counts.sum()).astype(np.int8)
    independent, timing_independent = evaluate(shuffled, scales, queries, [16])
    result = dict(seed=SEED, source=str(FIXTURE.relative_to(ROOT)),
                  source_sha256=hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
                  dimensions=list(weights.shape), train_rows=ROWS_TRAIN,
                  held_rows=weights.shape[0]-ROWS_TRAIN, captured_held_queries=queries.shape[0],
                  physical_byte_contract='IDs bit-packed across all rows; FP16 dictionary per column position; unchanged FP16 source scale per row. No file header or padding.',
                  real=real, independent_trits=independent,
                  exact_motifs=dict(real=motif_counts(weights), independent=motif_counts(shuffled)),
                  fitting_seconds=dict(real=timing_real, independent=timing_independent))
    OUT.write_text(json.dumps(result, indent=2)+'\n')
    for family in ('real', 'independent_trits'):
        print(family)
        for item in result[family]:
            print(item['name'], item['physical_bytes'], round(item['held_row_relative_rms'], 5))


if __name__ == '__main__':
    main()
