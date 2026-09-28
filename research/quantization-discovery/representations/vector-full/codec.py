"""Paid joint gate/up pair images. All stored tables contain their final FP16 values."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.cluster.vq import kmeans2

SHAPE = (3072, 1024)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def pack_codes(codes: np.ndarray, width: int) -> np.ndarray:
    """Row-major indices, low bit first, including codes crossing byte boundaries."""
    indices = np.asarray(codes, dtype=np.uint8).ravel(order='C')
    if width == 8:
        return indices.copy()
    if width not in (3, 4, 6) or np.any(indices >= 1 << width):
        raise ValueError('unsupported width or out-of-range code')
    bits = ((indices[:, None] >> np.arange(width, dtype=np.uint8)) & 1).reshape(-1)
    return np.packbits(bits, bitorder='little')


def unpack_codes(packed: np.ndarray, width: int, shape=SHAPE) -> np.ndarray:
    if width == 8:
        return np.asarray(packed, dtype=np.uint8).reshape(shape).copy()
    bits = np.unpackbits(np.asarray(packed, dtype=np.uint8), bitorder='little')[:np.prod(shape) * width]
    return np.sum(bits.reshape(-1, width) * (1 << np.arange(width, dtype=np.uint8)), axis=1).astype(np.uint8).reshape(shape)


def polar_table(weights: np.ndarray, width: int) -> tuple[np.ndarray, np.float16]:
    sizes = {3: (4, 2), 4: (8, 2), 6: (16, 4), 8: (32, 8)}
    angles, radii = sizes[width]
    gain = np.float16(np.sqrt(np.mean(np.asarray(weights, dtype=np.float64) ** 2)))
    radial = np.interp(np.linspace(0, 7, radii), np.arange(8), [.22, .46, .72, 1.04, 1.46, 2.02, 2.8, 4.0])
    theta = 2 * np.pi * np.arange(angles) / angles
    table = (float(gain) * np.stack([np.outer(radial, np.cos(theta)), np.outer(radial, np.sin(theta))], axis=-1)).reshape(-1, 2)
    return table.astype('<f2'), gain, None


def scalar_scale_table(weights: np.ndarray, width: int) -> tuple[np.ndarray, np.float16]:
    """FP16 scales fitted by alternating scalar-pattern assignment and least squares."""
    levels, scales = {3: (2, 2), 4: (2, 4), 6: (4, 4), 8: (4, 16)}[width]
    gain = np.float16(np.sqrt(np.mean(np.asarray(weights, dtype=np.float64) ** 2)))
    label = np.arange(-levels + 1, levels, 2, dtype=np.float64)
    patterns = np.stack(np.meshgrid(label, label, indexing='ij'), axis=-1).reshape(-1, 2)
    values = float(gain) * np.geomspace(.035, 1.8, scales)
    rng = np.random.default_rng(20260923)
    flat = weights.reshape(-1, 2)
    sample = np.asarray(flat[rng.choice(len(flat), 32768, replace=False)], dtype=np.float64)
    for _ in range(16):
        table = (values[:, None, None] * patterns[None]).reshape(-1, 2).astype('<f2')
        assigned = assign(sample, table).reshape(-1)
        group, pattern = np.divmod(assigned, len(patterns))
        choice = patterns[pattern]
        numerator = np.bincount(group, weights=np.sum(sample * choice, axis=1), minlength=scales)
        denominator = np.bincount(group, weights=np.sum(choice * choice, axis=1), minlength=scales)
        values = np.maximum(0., np.divide(numerator, denominator, out=values.copy(), where=denominator > 0)).astype('<f2').astype(np.float64)
    return (values[:, None, None] * patterns[None]).reshape(-1, 2).astype('<f2'), gain, values.astype('<f2')


def learned_pair_table(weights: np.ndarray, width: int, seed=20260923) -> tuple[np.ndarray, np.float16]:
    """Joint learned-vector control; pays the same full FP16 table as polar."""
    rng = np.random.default_rng(seed)
    flat = weights.reshape(-1, 2)
    sample = np.asarray(flat[rng.choice(len(flat), 32768, replace=False)], dtype=np.float32)
    center, _ = kmeans2(sample, 1 << width, iter=8, minit='++', seed=seed, missing='warn')
    return np.asarray(center, dtype='<f2'), np.float16(1.), None


def assign(weights: np.ndarray, table: np.ndarray, chunk=65536) -> np.ndarray:
    """Exact minimum FP16-table Euclidean error; equality uses the lowest index."""
    flat = np.asarray(weights, dtype=np.float32).reshape(-1, 2)
    centers = table.astype(np.float32)
    norms = np.sum(centers * centers, axis=1)
    result = np.empty(len(flat), dtype=np.uint8)
    for start in range(0, len(flat), chunk):
        batch = flat[start:start + chunk]
        dist = batch @ centers.T
        dist *= -2
        dist += norms
        result[start:start + chunk] = np.argmin(dist, axis=1).astype(np.uint8)
    return result.reshape(weights.shape[:-1])


def build_image(weights: np.ndarray, width: int, method: str, path: Path, *, layer: int, source_sha256: str) -> dict:
    if weights.shape != (*SHAPE, 2):
        raise ValueError(f'expected {(*SHAPE, 2)}, got {weights.shape}')
    methods = {'polar': polar_table, 'scalar_scale': scalar_scale_table, 'learned_pair': learned_pair_table}
    table, gain, scales = methods[method](weights, width)
    indices = assign(weights, table)
    packed = pack_codes(indices, width)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = {'packed': packed, 'gain': np.asarray(gain, dtype='<f2'),
              'width': np.asarray(width, dtype='<i4'), 'shape': np.asarray(SHAPE, dtype='<i4')}
    if scales is None:
        fields['table'] = table
    else:
        fields['scales'] = scales
    if width == 8:
        fields['codes'] = indices
        # `codes` is a convenience alias, never a second charged copy in the wire image.
        del fields['packed']
    np.savez(path, **fields)
    code_bytes = indices.size * width // 8
    stored_table_bytes = fields['scales'].nbytes if scales is not None else table.nbytes
    receipt = {'format': 'vector-full-pairs/1', 'layer': layer, 'method': method, 'width': width,
               'shape': list(SHAPE), 'source_sha256': source_sha256, 'file': str(path),
               'image_sha256': sha256(path), 'index_bytes': code_bytes,
               'table_bytes': stored_table_bytes, 'prepared_table_bytes': table.nbytes,
               'gain_bytes': 2, 'descriptor_bytes': 12,
               'physical_bytes': code_bytes + stored_table_bytes + 2 + 12,
               'npz_container_bytes': path.stat().st_size,
               'effective_pair_bits': 8 * (code_bytes + stored_table_bytes + 2 + 12) / indices.size,
               'mean_pair_weight_sse': float(np.mean(np.sum((weights - table[indices].astype(np.float32)) ** 2, axis=-1)))}
    path.with_suffix('.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt


def load_image(path: Path) -> tuple[np.ndarray, np.ndarray]:
    with np.load(path) as image:
        width = int(image['width'])
        shape = tuple(image['shape'])
        codes = unpack_codes(image['codes'] if width == 8 else image['packed'], width, shape)
        if 'scales' in image.files:
            levels = {3: 2, 4: 2, 6: 4, 8: 4}[width]
            labels = np.arange(-levels + 1, levels, 2, dtype=np.float32)
            patterns = np.stack(np.meshgrid(labels, labels, indexing='ij'), axis=-1).reshape(-1, 2)
            scales = np.asarray(image['scales'], dtype='<f2')
            table = (scales.astype(np.float32)[:, None, None] * patterns[None]).reshape(-1, 2).astype('<f2')
        else:
            table = np.asarray(image['table'], dtype='<f2')
        if table.shape != (1 << width, 2) or shape != SHAPE:
            raise ValueError('invalid pair-image geometry')
    return codes, table


def decode_image(path: Path) -> tuple[np.ndarray, np.ndarray]:
    with np.load(path) as image:
        if 'row_mask' in image.files:
            mask = np.unpackbits(image['row_mask'], bitorder='little')[:SHAPE[0]].astype(bool)
            weights = np.empty((*SHAPE, 2), dtype=np.float32)
            for width, selected in ((3, ~mask), (4, mask)):
                codes = unpack_codes(image[f'packed{width}'], width, (int(selected.sum()), SHAPE[1]))
                weights[selected] = image[f'table{width}'][codes].astype(np.float32)
            return weights[:, :, 0], weights[:, :, 1]
    codes, table = load_image(path)
    return table[codes, 0].astype(np.float32), table[codes, 1].astype(np.float32)
