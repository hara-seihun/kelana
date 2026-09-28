#!/usr/bin/env python3
"""An append-only mixed absolute/difference narrow-value row coordinate."""
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
DATA = Path('/path/to/workspace/data/kelana-subbit/value-absolute-work')


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


absolute = module('absolute_rows', SUBBIT / 'value-absolute-entropy/measure.py')
rows = absolute.parent
coordinate = rows.coord
base = rows.base


def run(layer):
    torch.set_num_threads(8)
    decoder = module('factor_decoder', base.SOURCE)
    image = base.IMAGE / f'layer{layer:02d}-joint-r28.npz'
    parent = base.PARENT / f'layer{layer:02d}-8x4.json'
    selected = json.loads(parent.read_text())['selected']
    with np.load(image) as factor:
        right = [decoder.decode({name: factor[name][g].copy() for name in factor.files}, 'right') for g in range(8)]
    train = base.codes(layer, 'train', right, [s['steps'] for s in selected], [s['lows'] for s in selected], 8)
    held = base.codes(layer, 'validation', right, [s['steps'] for s in selected], [s['lows'] for s in selected], 4)
    abs_ids, abs_tables = absolute.fit(train, 4)
    diff_ids, diff_tables = coordinate.fit(coordinate.differences(train, 256), 2 if layer == 0 else 4)
    abs_maps = absolute.mappings(abs_ids, abs_tables)
    diff_maps = rows.mappings(diff_ids, diff_tables)
    abs_reverse = [{(code, bits): symbol for symbol, (code, bits) in m.items()} for m in abs_maps]
    diff_reverse = [{(code, bits): symbol for symbol, (code, bits) in m.items()} for m in diff_maps]
    abs_static = (8*4*16*4+7)//8 + (8*28*2+7)//8
    diff_static = (8*(2 if layer == 0 else 4)*31*5+7)//8 + (8*28*(1 if layer == 0 else 2)+7)//8
    observer = module('value_observer', SUBBIT / 'value-observer/measure.py')
    fitter = module('value_fit', SUBBIT / 'value-observer/fit.py')
    mass_module = module('integer_value_mass', SUBBIT / 'value-integer-consumer/measure.py')
    with safe_open(fitter.MODEL, framework='pt', device='cpu') as model:
        weights = [model.get_tensor(f'model.layers.{layer}.self_attn.{name}.weight').float()
                   for name in ('q_proj', 'k_proj', 'q_norm', 'k_norm')]
    hidden = fitter.load_capture(layer, 'validation').reshape(-1, 256, 1024)[:4]
    p = observer.probabilities(hidden, *weights)
    counts = mass_module.integer_mass(p, 4095).numpy()
    outcomes = []
    for streams in (1, 2, 4):
        per_window = []
        mode_count = 0
        max_gap = 0
        digest = hashlib.sha256()
        abs_body = diff_body = 0
        absolute_parses = difference_parses = nonzero_counts = 0
        for window in range(4):
            arena = bytearray(256*4 + 32)
            modes = []
            prev = np.zeros(224, dtype=np.int16)
            reconstructed = np.empty((256, 224), dtype=np.int16)
            last_absolute = -1
            for t in range(256):
                current = held[window, t].reshape(224).astype(np.int16)
                symbols = (current+8, current-prev+15)
                maps = (abs_maps, diff_maps)
                reverse = (abs_reverse, diff_reverse)
                chunks = []
                for option in (0, 1):
                    chunks.append([rows.pack_decode(symbols[option][lo:hi], maps[option][lo:hi], reverse[option][lo:hi])
                                   for lo, hi in ((part*224//streams, (part+1)*224//streams) for part in range(streams))])
                size = [sum(map(len, part)) for part in chunks]
                mode = int(t != 0 and size[1] < size[0])
                chosen = chunks[mode]
                assert all(len(chunk) <= 255 for chunk in chosen)
                start = len(arena)
                arena[4*t:4*t+4] = start.to_bytes(4, 'little')
                arena[1024+t//8] |= mode << (t%8)
                arena.extend(bytes(len(chunk) for chunk in chosen[:-1]))
                for chunk in chosen:
                    arena.extend(chunk)
                    digest.update(chunk)
                decoded = symbols[mode] - (15 if mode else 8)
                reconstructed[t] = decoded + (prev if mode else 0)
                assert np.array_equal(reconstructed[t], current)
                prev = current
                modes.append(mode)
                if mode:
                    diff_body += size[1]
                else:
                    abs_body += size[0]
                    max_gap = max(max_gap, t-last_absolute)
                    last_absolute = t
            assert np.array_equal(reconstructed, held[window].reshape(256, 224))
            if streams == 1:
                n = counts[window]
                nonzero_counts += int(np.count_nonzero(n))
                suffix = np.zeros((16, 256), dtype=np.int64)
                for t in range(255, -1, -1):
                    suffix = n[:, :, t] + (suffix if t < 255 and modes[t+1] else 0)
                    if modes[t]:
                        difference_parses += int(np.count_nonzero(suffix))
                    else:
                        absolute_parses += int(np.count_nonzero(suffix))
            mass = (np.arange(256, dtype=np.int64)*17+3) % 16
            suffix = 0
            observed = np.zeros(224, dtype=np.int64)
            for t in range(255, -1, -1):
                suffix += mass[t]
                if modes[t] == 0:
                    observed += suffix*reconstructed[t]
                    suffix = 0
                else:
                    observed += suffix*(reconstructed[t]-reconstructed[t-1])
            assert np.array_equal(observed, mass @ reconstructed.astype(np.int64))
            mode_count += sum(modes)
            per_window.append(len(arena)+4)
        outcomes.append({'streams_per_row': streams, 'bytes_per_token': (sum(per_window)+abs_static+diff_static)/1024,
                         'bytes_per_window': per_window, 'absolute_rows': 1024-mode_count,
                         'difference_rows': mode_count, 'longest_gap_between_absolute_rows': max_gap,
                         'absolute_body_bytes': abs_body, 'difference_body_bytes': diff_body,
                         'nonzero_mass_pairs': nonzero_counts if streams == 1 else None,
                         'absolute_parses': absolute_parses if streams == 1 else None,
                         'difference_parses': difference_parses if streams == 1 else None,
                         'payload_sha256': digest.hexdigest()})
    receipt = {'layer': layer, 'source_sha256': base.sha(HERE), 'model_sha256': base.sha(fitter.MODEL),
               'capture_sha256': base.sha(base.CAPTURES / f'layer{layer:02d}.npz'),
               'factor_sha256': base.sha(image), 'parent_sha256': base.sha(parent),
               'absolute_source_sha256': base.sha(SUBBIT / 'value-absolute-entropy/measure.py'),
               'difference_source_sha256': base.sha(SUBBIT / 'value-row-entropy/measure.py'),
               'mass_source_sha256': base.sha(SUBBIT / 'value-integer-consumer/measure.py'),
               'train_windows': 8, 'held_windows': 4, 'absolute_static_bytes': abs_static,
               'difference_static_bytes': diff_static,
               'contract': 'Append-only independently addressed mixed rows: 32-bit row starts, 32-byte mode bitmap per 256-key block, two paid train-fitted canonical Huffman families; choose the shorter byte-aligned row at append time, first row absolute. Absolute rows reset the suffix-mass direct integer dot, differences telescope between resets. No native timing or FP32 identity.',
               'results': outcomes}
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(dest), 'results': outcomes}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
