#!/usr/bin/env python3
"""Price block-local exact V-label dictionaries and their causal grouped dots."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch

SUB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def block_counts(rows, width):
    """First-occurrence order, prefix cardinalities, and exact block-local labels."""
    labels = []
    prefixes = []
    ids = []
    table = {}
    for start in range(0, len(rows), width):
        table.clear()
        for row in rows[start:start + width]:
            key = row.tobytes()
            if key not in table:
                table[key] = len(table)
                labels.append(key)
            ids.append(table[key])
            prefixes.append(len(table))
    blocks = [(start, min(width, len(rows) - start), prefixes[min(start + width, len(rows)) - 1])
              for start in range(0, len(rows), width)]
    return blocks, prefixes, ids, labels


def causal_uses(prefixes, width):
    # Previous completed blocks are read on every later causal query.
    total = 0
    closed = 0
    for p, u in enumerate(prefixes):
        if p and p % width == 0:
            closed += prefixes[p - 1]
        total += closed + u
    return total


def measure_window(rows, widths):
    count = len(rows)
    result = {}
    for width in widths:
        blocks, prefixes, ids, labels = block_counts(rows, width)
        max_u = max(b[2] for b in blocks)
        id_bytes = 1 if max_u <= 256 else 2
        # A block needs its 4-byte arena address and 2-byte label count.
        charged = 224 * len(labels) + id_bytes * count + 6 * len(blocks)
        # Assign a nonuniform, bounded conserved mass, and check the integer map
        # through every block's local dictionary. This is not a learned softmax row.
        n = np.arange(1, count + 1, dtype=np.int64) % 19
        direct = n @ rows.astype(np.int64)
        total = np.zeros(28, dtype=np.int64)
        for start, length, u in blocks:
            local = rows[start:start + length]
            _, first, inverse = np.unique(local, axis=0, return_index=True, return_inverse=True)
            hist = np.bincount(inverse, weights=n[start:start + length], minlength=u).astype(np.int64)
            total += hist @ local[first].astype(np.int64)
        assert np.array_equal(total, direct)
        result[str(width)] = {'bytes': charged, 'bytes_per_key': charged / count,
                              'blocks': len(blocks), 'labels': len(labels),
                              'max_labels_per_block': max_u, 'id_bytes': id_bytes,
                              'causal_label_uses_per_group': causal_uses(prefixes, width),
                              'causal_key_uses_per_group': count * (count + 1) // 2,
                              'ids_sha256': hashlib.sha256(np.asarray(ids, dtype='<u2').tobytes()).hexdigest(),
                              'integer_response_sha256': hashlib.sha256(direct.astype('<i8').tobytes()).hexdigest()}
    return result


def adaptive_256(rows):
    # Close a block only before its 257th distinct label, keeping byte IDs.
    starts = [0]
    seen = set()
    for i, row in enumerate(rows):
        key = row.tobytes()
        if key not in seen and len(seen) == 256:
            starts.append(i)
            seen.clear()
        seen.add(key)
    lengths = [b - a for a, b in zip(starts, starts[1:] + [len(rows)])]
    prefix = []
    unique = 0
    uses = 0
    closed = 0
    for start, length in zip(starts, lengths):
        seen.clear()
        for row in rows[start:start + length]:
            seen.add(row.tobytes())
            prefix.append(len(seen))
            uses += closed + len(seen)
        unique += len(seen)
        closed += len(seen)
    return {'block_lengths': lengths, 'labels': unique,
            'bytes': 224 * unique + len(rows) + 6 * len(lengths),
            'causal_label_uses_per_group': uses}


def run(layer):
    torch.set_num_threads(8)
    parent_path = DATA / 'value-int8-consumer' / f'layer{layer:02d}.json'
    parent = json.loads(parent_path.read_text())
    image_path = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    assert sha(MODEL) == parent['model_sha256']
    assert sha(image_path) == parent['image_sha256']
    assert sha(CAPTURES / f'layer{layer:02d}.npz') == parent['capture_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    scale_parent = json.loads((DATA / 'value-fp8-cache' / f'layer{layer:02d}.json').read_text())
    by_group = []
    codes = []
    with np.load(image_path) as image:
        for g in range(8):
            right = decoder.decode({k: image[k][g].copy() for k in image.files}, 'right')
            z = (x @ right.T).to(torch.bfloat16).float()
            step = torch.tensor(scale_parent['scales'][str(g)]['int8_coordinate'], dtype=torch.float16).float()
            code = (z / step).round().clamp(-127, 127).to(torch.int8).numpy()
            assert hashlib.sha256(code.tobytes()).hexdigest() == parent['code_sha256_by_group'][g]
            codes.append(code)
            by_group.append([measure_window(code[v], [32, 64, 128, 256]) for v in range(4)])
    # A shared ID is valid only if the complete 224-byte row has the same fibers
    # as each group's 28-byte code, on every tested window and every prefix.
    shared = []
    for v in range(4):
        whole = np.concatenate([codes[g][v] for g in range(8)], axis=1)
        _, _, whole_ids, _ = block_counts(whole, 256)
        assert all(whole_ids == block_counts(codes[g][v], 256)[2] for g in range(8))
        shared.append(measure_window(whole[:, :28], [32, 64, 128, 256]))
    # Cross-window concatenation is a storage-only stress test, NOT a causal
    # 1024-token sequence. The windows are separate texts with reset positions.
    joined = np.concatenate([np.concatenate([codes[g][v] for g in range(8)], axis=1)
                             for v in range(4)], axis=0)
    joined_groups = [np.concatenate([codes[g][v] for v in range(4)], axis=0) for g in range(8)]
    joined_rates = {}
    for width in (256, 512, 1024):
        blocks = block_counts(joined, width)[0]
        u = sum(b[2] for b in blocks)
        id_bytes = 1 if max(b[2] for b in blocks) <= 256 else 2
        joined_rates[str(width)] = {'bytes': 224 * u + id_bytes * 1024 + 6 * len(blocks),
                                    'labels': u, 'max_labels_per_block': max(b[2] for b in blocks),
                                    'id_bytes': id_bytes,
                                    'causal_label_uses_per_group': causal_uses(block_counts(joined, width)[1], width)}
    joined_rates['adaptive_256'] = adaptive_256(joined)
    mass = np.arange(1, 1025, dtype=np.int64) % 19
    for width in (256, 512, 1024):
        for g in range(8):
            # Whole-row IDs may split a group-specific equivalence class. They
            # must never merge distinct codes; check the complete integer map.
            blocks, _, ids, _ = block_counts(joined, width)
            grouped = np.zeros(28, dtype=np.int64)
            for start, length, _ in blocks:
                local_ids = np.asarray(ids[start:start + length], dtype=np.intp)
                first = np.unique(local_ids, return_index=True)[1]
                grouped += np.bincount(local_ids, weights=mass[start:start + length],
                                       minlength=len(first)).astype(np.int64) @ joined_groups[g][start + first].astype(np.int64)
            assert np.array_equal(grouped, mass @ joined_groups[g].astype(np.int64))
    joined_group_fibers = {
        str(width): sum(block_counts(joined, width)[2] != block_counts(c, width)[2]
                        for c in joined_groups)
        for width in (256, 512, 1024)
    }
    output = {'layer': layer, 'source_sha256': sha(Path(__file__)), 'parent_sha256': sha(parent_path),
              'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'image_sha256': sha(image_path), 'factor_source_sha256': sha(SOURCE),
              'domain': 'four separate, previously inspected 256-token original-producer validation windows; 1024-key concatenation is storage-only',
              'layout': 'each block: 224 bytes per unique whole V row, one/two-byte ID per key, uint16 count, uint32 arena address',
              'per_group_window': by_group, 'shared_window': shared,
              'joined_storage_only': joined_rates,
              'joined_groups_with_different_fibers': joined_group_fibers,
              'cost': 'two heads x 28 integer label products per group use; causal sums include every completed block; scatter still costs two adds per key/group/query, plus block-local zeroing and directory lookup; native time, append, O and attention normalization not measured'}
    dest = DATA / 'value-dictionary-blocks' / f'layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'shared': shared,
                      'joined_storage_only': joined_rates}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, required=True, choices=(0, 14))
    run(parser.parse_args().layer)
