#!/usr/bin/env python3
"""Charge physical V row reads after changing the conserved attention mass."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


active = module('value_active', SUBBIT / 'value-active-entropy/measure.py')
short = module('value_short', SUBBIT / 'value-nibble-255/measure.py')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def mask_data(parent, counts):
    # Counts are (window, query head, query, key). A parser visits the union
    # of the two observing heads in each GQA group.
    windows, heads, queries, keys = counts.shape
    occupied = counts.reshape(windows, 8, 2, queries, keys).ne(0).any(dim=2)
    bits = np.zeros((windows, queries, keys), dtype=np.uint8)
    for g in range(8):
        bits |= occupied[:, g].numpy().astype(np.uint8) << g
    data = dict(parent)
    data['group_mask'] = bits
    for streams in (1, 2, 4, 8):
        width = 8 // streams
        histogram = np.zeros((windows, keys, streams, width), dtype=np.int16)
        for w in range(windows):
            for q in range(keys):
                for s in range(streams):
                    for k in range(q + 1):
                        segment = (int(bits[w, q, k]) >> (s * width)) & ((1 << width) - 1)
                        if segment:
                            histogram[w, k, s, segment.bit_length() - 1] += 1
        data[f'hist_{streams}'] = histogram
    data['exposure'] = occupied.sum(dim=2).numpy().astype(np.int16)
    return data


def one_layer(layer):
    torch.set_num_threads(8)
    previous = json.loads((DATA / 'value-active-entropy' / f'layer{layer:02d}.json').read_text())
    parent = DATA / 'value-active-entropy' / f'layer{layer:02d}-validation.npz'
    selection = json.loads((DATA / 'value-nibble-255' / f'layer{layer:02d}.json').read_text())
    mask = int(selection['train_selected']['mask'], 16)
    with np.load(parent) as source:
        assert str(source['factor_sha256']) == previous['factor_sha256']
        frozen = {name: source[name] for name in source.files if name in ('codes', 'exposure', 'group_mask')}
    with safe_open(short.MODEL, framework='pt', device='cpu') as model:
        weights = {name: model.get_tensor(f'model.layers.{layer}.self_attn.{name}.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')}
    x = short.load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = short.probabilities(x, weights['q_proj'], weights['k_proj'], weights['q_norm'], weights['k_norm'])
    long = short.counts(p, 4095)
    short_count = short.counts(p, 255)
    assert long.shape == (4, 16, 256, 256)
    masks = torch.tensor([(mask >> h) & 1 for h in range(16)], dtype=torch.bool)
    mixed = torch.where(masks[None, :, None, None], short_count, long)
    arms = {'all_4095': long, 'selected_255': mixed, 'all_255': short_count}
    results = {}
    with np.load(DATA / 'value-active-entropy' / f'layer{layer:02d}-train.npz') as train:
        tables, ids = active.fit(train, 1, 4, 0)
    for name, counts in arms.items():
        data = mask_data(frozen, counts)
        active_rows = int((data['group_mask'] != 0).sum())
        logical_head_pairs = int((counts != 0).sum())
        numbers = {'active_rows': active_rows,
                   'active_rows_per_query': active_rows / 1024,
                   'active_head_key_pairs': logical_head_pairs,
                   'shared_row_skips': 4 * 256 * 257 // 2 - active_rows}
        for streams in (1, 8):
            scored = active.score(data, tables, ids, streams)
            traffic = active.line_traffic(data, tables, ids, streams)
            numbers[f'{streams}_streams'] = {k: scored[k] for k in ('charged_bytes_per_key', 'required_prefix_bytes_per_query', 'active_stream_fetches_per_query')}
            numbers[f'{streams}_streams'].update(traffic)
        results[name] = numbers
        print(layer, name, numbers['active_rows_per_query'], numbers['1_streams']['cold_union_64B_per_query'], flush=True)
    assert results['all_4095']['active_rows'] == int((frozen['group_mask'] != 0).sum())
    receipt = {'layer': layer, 'results': results, 'selected_heads': selection['train_selected'],
               'source_sha256': sha(HERE), 'active_parent_sha256': sha(parent),
               'active_parent_receipt_sha256': sha(DATA / 'value-active-entropy' / f'layer{layer:02d}.json'),
               'short_mass_receipt_sha256': sha(DATA / 'value-nibble-255' / f'layer{layer:02d}.json'),
               'model_sha256': previous['model_sha256'], 'capture_sha256': previous['capture_sha256'],
               'factor_sha256': previous['factor_sha256'],
               'contract': 'Four previously inspected original-producer Qwen3-0.6B validation windows. Prefix-round probabilities to 255 or 4095 per head; selected head mask comes only from eight train windows and holds the frozen rank-28 nibble image, Huffman table and 4-byte row directory fixed. Count one shared physical parser whenever either head of any group needs a row. Cold 64-byte lines are unique per query, including directory and row prefixes, without reuse across queries. No native time, model loss or paid producer time.'}
    destination = DATA / 'value-short-mass-physical' / f'layer{layer:02d}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(receipt, indent=2) + '\n')
    print(destination, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    one_layer(parser.parse_args().layer)
