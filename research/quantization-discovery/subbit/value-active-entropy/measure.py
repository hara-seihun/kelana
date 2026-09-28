#!/usr/bin/env python3
"""Fit cache Huffman lengths to stored rows and actually visited integer-mass rows."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
DATA = Path('/path/to/workspace/data/kelana-subbit/value-active-entropy')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


absolute = module('absolute_value_parent', SUBBIT / 'value-absolute-entropy/measure.py')
base = absolute.base
mass = module('value_mass_parent', SUBBIT / 'value-mass-residual/measure.py')
observer = module('value_observer_parent', SUBBIT / 'value-observer/measure.py')


def prepare(layer, split):
    torch.set_num_threads(8)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    selection = base.PARENT / f'layer{layer:02d}-8x4.json'
    decoder = module('paid_factor_decoder', base.SOURCE)
    selected = json.loads(selection.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][g].copy() for name in factor.files}, 'right') for g in range(8)]
    windows = 8 if split == 'train' else 4
    codes = base.codes(layer, split, right, [s['steps'] for s in selected], [s['lows'] for s in selected], windows)
    with safe_open(mass.MODEL, framework='pt', device='cpu') as model:
        w = {name: model.get_tensor(f'model.layers.{layer}.self_attn.{name}.weight').float()
             for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    x = mass.load_capture(layer, split).reshape(-1, 256, 1024)[:windows]
    counts = mass.counts(observer.probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm']))
    active = counts.reshape(windows, 8, 2, 256, 256) > 0
    exposure = active.sum((2, 3)).numpy().astype(np.int16)
    group_active = active.any(2)
    group_mask = (group_active.to(torch.int16) *
                  (1 << torch.arange(8, dtype=torch.int16))[None, :, None, None]).sum(1).numpy().astype(np.uint8)
    histograms = {}
    for streams in (1, 2, 4, 8):
        per_stream = 8 // streams
        furthest = (active.any(2).reshape(windows, streams, per_stream, 256, 256).to(torch.int16) *
                    torch.arange(1, per_stream+1, dtype=torch.int16)[None, None, :, None, None]).amax(2)
        hist = torch.stack([(furthest == g).sum(2) for g in range(1, per_stream+1)], -1)
        histograms[f'hist_{streams}'] = hist.permute(0, 2, 1, 3).numpy().astype(np.int16)
    assert codes.shape == (windows, 256, 8, 28)
    assert exposure.shape == (windows, 8, 256)
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}-{split}.npz'
    np.savez_compressed(dest, codes=codes, exposure=exposure, group_mask=group_mask, **histograms,
                        capture_sha256=base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
                        factor_sha256=base.sha(image), selection_sha256=base.sha(selection),
                        source_sha256=base.sha(HERE))
    print(dest, 'active pairs', int(exposure.sum()), flush=True)


def lengths(hist):
    # The parent's canonical Huffman fitter gives a complete 16-symbol tree.
    result = base.canonical(hist)[0][:16]
    assert len(result) == 16 and max(result) <= 15
    return result


def fit(train, banks, ntable, lam):
    codes = train['codes'].astype(np.int16) + 8
    exposure = train['exposure']
    tables = np.zeros((banks, 8, ntable, 16), dtype=np.int16)
    ids = np.zeros((banks, 8, 28), dtype=np.uint8)
    for bank in range(banks):
        lo, hi = bank * 256 // banks, (bank + 1) * 256 // banks
        for group in range(8):
            store = np.array([np.bincount(codes[:, lo:hi, group, j].ravel(), minlength=16)
                              for j in range(28)], dtype=np.int64)
            visits = np.array([np.bincount(codes[:, lo:hi, group, j].ravel(),
                              weights=np.broadcast_to(exposure[:, group, lo:hi, None],
                                                       codes[:, lo:hi, group, j:j+1].shape).ravel(),
                              minlength=16) for j in range(28)])
            p = store / store.sum(axis=1, keepdims=True)
            entropy = -(np.where(p > 0, p * np.log2(np.maximum(p, 1e-30)), 0)).sum(axis=1)
            order = sorted(range(28), key=lambda j: (entropy[j], j))
            for rank, j in enumerate(order):
                ids[bank, group, j] = min(ntable-1, rank * ntable // 28)
            for bucket in range(ntable):
                selected = ids[bank, group] == bucket
                stored_hist = store[selected].sum(axis=0)
                active_hist = visits[selected].sum(axis=0)
                # lambda=1 prices an active symbol bit as much as a stored bit
                # after normalizing the number of visits to the number of stored labels.
                objective = stored_hist + lam * active_hist * (stored_hist.sum() / active_hist.sum())
                tables[bank, group, bucket] = lengths(np.rint(objective).astype(np.int64))
    return tables, ids


def score(data, tables, ids, streams):
    codes = data['codes'].astype(np.int16) + 8
    exposure = data['exposure'].astype(np.int64)
    windows, keys, groups, coords = codes.shape
    nbank, _, ntable, _ = tables.shape
    lookup = np.empty_like(codes, dtype=np.int16)
    for bank in range(nbank):
        lo, hi = bank * keys // nbank, (bank + 1) * keys // nbank
        for g in range(groups):
            for j in range(coords):
                lookup[:, lo:hi, g, j] = tables[bank, g, ids[bank, g, j], codes[:, lo:hi, g, j]]
    stream_bits = lookup.reshape(windows, keys, streams, groups // streams, coords).sum(axis=(3, 4))
    # Independently addressed, byte-aligned streams per row; 4-byte directory
    # entry/key, stream lengths except the final one, 4-byte block start/window.
    payload = int(((stream_bits + 7) // 8).sum()) + windows * keys * (streams - 1)
    static = nbank * groups * ntable * 16 * 4 // 8
    assignment = 0 if ntable == 1 else nbank * groups * coords * (ntable.bit_length()-1) // 8
    directory = windows * (keys * 4 + 4)
    parsed = int((lookup * exposure.transpose(0, 2, 1)[:, :, :, None]).sum())
    visits = int(exposure.sum())
    prefix_bits = lookup.reshape(windows, keys, streams, groups // streams, coords).sum(axis=4).cumsum(axis=3)
    histogram = data[f'hist_{streams}'].astype(np.int64)
    prefix_work = int((prefix_bits * histogram).sum())
    prefix_bytes = int((((prefix_bits + 7) // 8) * histogram).sum())
    fetches = int(histogram.sum())
    active_rows = int(data['hist_1'].sum())
    return {'charged_bytes_per_key': (payload + static + assignment + directory) / (windows * keys),
            'payload_bytes': payload, 'static_bytes': static, 'assignment_bytes': assignment,
            'directory_bytes': directory,
            'active_parser_bits_per_query_head': parsed / (windows * keys * groups * 2),
            'active_keys_per_query_head': visits / (windows * keys * groups * 2),
            'mean_bits_per_active_coordinate': parsed / (visits * coords),
            'required_prefix_bits_per_query': prefix_work / (windows * keys),
            'required_prefix_bytes_per_query': prefix_bytes / (windows * keys),
            'active_stream_fetches_per_query': fetches / (windows * keys),
            'active_row_fetches_per_query': active_rows / (windows * keys),
            'max_code_length': int(tables.max()),
            'max_stream_bytes': int(((stream_bits + 7) // 8).max()),
            'table_lengths': tables.tolist(), 'bucket_ids': ids.tolist()}


def line_traffic(data, tables, ids, streams):
    codes = data['codes'].astype(np.int16) + 8
    masks = data['group_mask']
    windows, keys, groups, coords = codes.shape
    per_stream = groups // streams
    total_lines = 0
    total_row_lines = 0
    for window in range(windows):
        row_start = 4 + 4 * keys
        starts = []
        prefix_bytes = []
        for key in range(keys):
            bank = key * len(tables) // keys
            bits = np.array([[int(tables[bank, g, ids[bank, g, j], codes[window, key, g, j]])
                              for j in range(coords)] for g in range(groups)])
            prefix = bits.sum(1).reshape(streams, per_stream).cumsum(1)
            lengths = (prefix[:, -1] + 7) // 8
            starts.append(row_start + streams - 1 + np.concatenate(([0], lengths.cumsum()[:-1])))
            prefix_bytes.append((prefix + 7) // 8)
            row_start += streams - 1 + int(lengths.sum())
        for query in range(keys):
            lines = {0}
            row_lines = set()
            for key in range(query + 1):
                mask = int(masks[window, query, key])
                if not mask:
                    continue
                lines.add((4 + 4 * key) // 64)
                if streams > 1:
                    begin = int(starts[key][0]) - streams + 1
                    row_lines.update(range(begin // 64, (begin + streams - 2) // 64 + 1))
                for stream in range(streams):
                    segment = (mask >> (stream * per_stream)) & ((1 << per_stream) - 1)
                    if not segment:
                        continue
                    begin = int(starts[key][stream])
                    end = begin + int(prefix_bytes[key][stream, segment.bit_length() - 1])
                    row_lines.update(range(begin // 64, (end - 1) // 64 + 1))
            lines |= row_lines
            total_lines += len(lines)
            total_row_lines += len(row_lines)
    return {'cold_union_64B_per_query': 64 * total_lines / (windows * keys),
            'row_and_stream_header_64B_per_query': 64 * total_row_lines / (windows * keys),
            'contract': 'Unique 64-byte lines per query from block start, directory entries of rows selected by any head, stream-length header and accessed Huffman prefixes through the last active group of each stream. Fixed full-block row offsets; no reuse between queries, within-query overlap counted once. No output, probability or append traffic.'}


def run(layer):
    paths = {split: DATA / f'layer{layer:02d}-{split}.npz' for split in ('train', 'validation')}
    with np.load(paths['train']) as train, np.load(paths['validation']) as held:
        assert str(train['factor_sha256']) == str(held['factor_sha256'])
        assert str(train['selection_sha256']) == str(held['selection_sha256'])
        results = []
        for banks in (1, 2):
            for ntable in (1, 2, 4):
                for lam in (0, .25, 1, 4):
                    table, ids = fit(train, banks, ntable, lam)
                    for streams in (1, 2, 4, 8):
                        result = {'banks': banks, 'tables_per_group': ntable,
                                  'streams_per_row': streams, 'lambda': lam,
                                  'train': score(train, table, ids, streams),
                                  'held': score(held, table, ids, streams)}
                        if banks == 1 and ntable == 4 and lam == 0:
                            result['held_lines'] = line_traffic(held, table, ids, streams)
                        results.append(result)
        receipt = {'layer': layer, 'source_sha256': base.sha(HERE),
                   'capture_sha256': str(train['capture_sha256']),
                   'model_sha256': base.sha(mass.MODEL),
                   'factor_sha256': str(train['factor_sha256']),
                   'selection_sha256': str(train['selection_sha256']),
                   'input_sha256': {split: base.sha(path) for split, path in paths.items()},
                   'train_windows': 8, 'inspected_held_windows': 4,
                   'contract': 'Frozen paid rank-28 signed-nibble V labels; original-producer Q/K, causal prefix-rounded 4095-mass; complete-alphabet one-parser canonical Huffman per independently addressed byte-aligned row; 32-bit row directory and block starts; 4-bit lengths per group and optional half-key-position bank; one to eight independent row streams each decode through the farthest group with positive count in either head; each visited stream prefix rounds to a whole byte. The single-stream case shares one parser across all groups. For matched four-table storage-optimal arms, a cold 64-byte union model charges directory and stream headers while grouping overlapping lines within a query. Cache reuse between queries, code-table lookup, output dots, softmax, O and append time remain unpaid. The coordinate-local active bit tally is an optimistic independent-group bound, not the actual one-parser work. lambda fits storage histogram plus normalized active-parse histogram on train only.',
                   'results': results}
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2) + '\n')
    for result in results:
        held = result['held']
        print(layer, result['banks'], result['tables_per_group'], result['streams_per_row'], result['lambda'], round(held['charged_bytes_per_key'], 3),
              round(held['mean_bits_per_active_coordinate'], 4), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    parser.add_argument('--prepare', choices=('train', 'validation'))
    args = parser.parse_args()
    prepare(args.layer, args.prepare) if args.prepare else run(args.layer)
