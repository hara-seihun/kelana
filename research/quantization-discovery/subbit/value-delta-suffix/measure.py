#!/usr/bin/env python3
"""Price block-restarted temporal differences of the frozen paid narrow-V codes."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve()
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'value-observer'))
from fit import CAPTURES, load_capture
from fit_direct import SOURCE

DATA = Path('/path/to/workspace/data/kelana-subbit/value-delta-suffix')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
PARENT = Path('/path/to/workspace/data/kelana-subbit/value-nibble-joint-fit')


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for part in iter(lambda: stream.read(1 << 20), b''):
            h.update(part)
    return h.hexdigest()


def best_alphabet(diff, bits):
    hist = np.bincount((diff + 15).ravel(), minlength=31)
    labels = sorted(range(-15, 16), key=lambda x: (-int(hist[x + 15]), abs(x), x))[:(1 << bits)-1]
    return labels, int(hist.sum() - sum(hist[x + 15] for x in labels))


def suffix_certificate():
    # Integer mass makes both summation orders exact; separate head masses share the codes.
    rng = np.random.default_rng(20260923)
    for length in (2, 16, 32, 256):
        code = rng.integers(-8, 8, (length, 224), dtype=np.int64)
        mass = rng.multinomial(4095, np.ones(length)/length, size=2)
        delta = code[1:] - code[:-1]
        direct = mass @ code
        suffix = np.cumsum(mass[:, ::-1], axis=1)[:, ::-1]
        translated = mass.sum(axis=1)[:, None]*code[0] + suffix[:, 1:] @ delta
        assert np.array_equal(direct, translated)
    return {'heads': 2, 'dimensions': 224, 'lengths': [2, 16, 32, 256], 'integer_mass': 4095}


def run(layer):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('paid_factor_decode', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    image_path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent_path = PARENT / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(parent_path.read_text())['selected']
    with np.load(image_path) as image:
        right = [decoder.decode({name: image[name][g].copy() for name in image.files}, 'right') for g in range(8)]
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    codes = []
    for g in range(8):
        z = (x @ right[g].T).to(torch.bfloat16).float()
        step = torch.tensor(metadata[g]['steps'])
        low = torch.tensor(metadata[g]['lows'])
        codes.append(torch.maximum((z / step).round().clamp(max=7), low).to(torch.int8).numpy())
    cache = np.stack(codes, axis=2)  # window, key, group, coordinate
    assert cache.shape == (4, 256, 8, 28)
    for start in range(0, 256, 32):
        chunk = cache[:, start:start+32].astype(np.int16)
        diff = chunk[:, 1:] - chunk[:, :-1]
        assert np.array_equal(chunk[:, 0, None] + np.cumsum(diff, axis=1), chunk[:, 1:])
    assert cache.min() >= -8 and cache.max() <= 7
    # Per-group alphabet learned on eight train windows; held report must not select labels.
    train_x = load_capture(layer, 'train').reshape(-1, 256, 1024)[:8]
    train_codes = []
    for g in range(8):
        z = (train_x @ right[g].T).to(torch.bfloat16).float()
        train_codes.append(torch.maximum((z / torch.tensor(metadata[g]['steps'])).round().clamp(max=7),
                                         torch.tensor(metadata[g]['lows'])).to(torch.int8).numpy())
    tc = np.stack(train_codes, axis=2)
    groups = []
    for block in (16, 32, 64, 128, 256):
        diff = np.concatenate([cache[:, b+1:b+block].astype(np.int16) - cache[:, b:b+block-1].astype(np.int16)
                               for b in range(0, 256, block)], axis=1)
        td = np.concatenate([tc[:, b+1:b+block].astype(np.int16) - tc[:, b:b+block-1].astype(np.int16)
                             for b in range(0, 256, block)], axis=1)
        assert diff.min() >= -15 and diff.max() <= 15
        for bits in (2, 3, 4):
            for scope in ('group', 'coordinate'):
                if scope == 'group':
                    choices = [best_alphabet(td[:, :, g], bits)[0] for g in range(8)]
                    mask = np.stack([~np.isin(diff[:, :, g], choices[g]) for g in range(8)], axis=2)
                    metadata = 8*((1 << bits)-1)*5
                else:
                    choices = [[best_alphabet(td[:, :, g, c], bits)[0] for c in range(28)] for g in range(8)]
                    mask = np.stack([np.stack([~np.isin(diff[:, :, g, c], choices[g][c])
                                                for c in range(28)], axis=-1) for g in range(8)], axis=2)
                    metadata = 224*((1 << bits)-1)*5
                block_bytes = []
                for window in range(4):
                    total = 0
                    for b in range(256//block):
                        escapes = int(mask[window, b*(block-1):(b+1)*(block-1)].sum())
                        total += 112 + ((block-1)*224*bits + 5*escapes + 7)//8 + 4
                    block_bytes.append(total)
                groups.append({'symbol_bits': bits, 'restart_keys': block, 'alphabet_scope': scope,
                               'alphabet_metadata_bits_per_layer': metadata, 'train_alphabets': choices,
                               'held_escapes': int(mask.sum()), 'held_differences': int(mask.size),
                               'held_bytes_per_window': block_bytes,
                               'held_bytes_per_token_layer': sum(block_bytes)/1024,
                               'held_escape_fraction': float(mask.mean())})
    receipt = {'layer': layer, 'source_sha256': sha(HERE), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': sha(image_path), 'parent_sha256': sha(parent_path),
               'domain': 'frozen rank-28 paid V/O image, 8 original-producer train and 4 repeatedly inspected validation windows; BF16-rounded value producer and train-selected FP16 steps/endpoints',
               'shape': list(cache.shape), 'static_nibble_bytes_per_token_layer': 112,
               'suffix_certificate': suffix_certificate(), 'blocks': groups}
    DATA.mkdir(parents=True, exist_ok=True)
    output = DATA / f'layer{layer:02d}.json'
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(output), 'rates': [(r['restart_keys'], r['symbol_bits'], r['alphabet_scope'], round(r['held_bytes_per_token_layer'], 3)) for r in groups]}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
