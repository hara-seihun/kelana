"""Fit a row-selected 3/4-bit paired image to the selected ternary MLP byte budget."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from codec import SHAPE, decode_image, load_image, pack_codes, sha256
from quality import DATA, OUT, inputs, packed_projection, physical_ternary_bytes, response, source_weights

ROWS_FOUR = 1380


def run(layer):
    three = OUT / f'layer{layer:02}-learned_pair-3bit.npz'
    four = OUT / f'layer{layer:02}-learned_pair-4bit.npz'
    down, down_path = packed_projection(layer, 'down')
    x, capture, positions = inputs(layer, 'train')
    weights, original_down = source_weights(layer)
    g3, u3 = decode_image(three)
    g4, u4 = decode_image(four)
    hidden3 = (x @ g3.T) / (1 + np.exp(-np.clip(x @ g3.T, -80, 80))) * (x @ u3.T)
    hidden4 = (x @ g4.T) / (1 + np.exp(-np.clip(x @ g4.T, -80, 80))) * (x @ u4.T)
    target = response(x, weights[:, :, 0], weights[:, :, 1], original_down)
    residual = hidden3 @ down.T - target
    delta = hidden4 - hidden3
    projected = residual @ down
    benefit = -2 * np.sum(projected * delta, axis=0) - np.sum(down ** 2, axis=0) * np.sum(delta ** 2, axis=0)
    selected = np.zeros(SHAPE[0], dtype=bool)
    selected[np.argsort(-benefit, kind='stable')[:ROWS_FOUR]] = True
    code3, table3 = load_image(three)
    code4, table4 = load_image(four)
    with np.load(three) as low, np.load(four) as high:
        fields = {'packed3': pack_codes(code3[~selected], 3), 'packed4': pack_codes(code4[selected], 4),
                  'table3': table3, 'table4': table4,
                  'gain3': low['gain'], 'gain4': high['gain'],
                  'row_mask': np.packbits(selected, bitorder='little'),
                  'width3': np.asarray(3, dtype='<i4'), 'width4': np.asarray(4, dtype='<i4'),
                  'shape': np.asarray(SHAPE, dtype='<i4')}
    path = OUT / f'layer{layer:02}-learned_pair-mixed.npz'
    np.savez(path, **fields)
    payload = sum(a.nbytes for a in fields.values())
    selected_total = 0
    for projection in ('gate', 'up', 'down'):
        _, p = packed_projection(layer, projection)
        selected_total += physical_ternary_bytes(p)
    result = {'format': 'vector-full-pairs-mixed/1', 'file': str(path), 'image_sha256': sha256(path),
              'layer': layer, 'method': 'learned_pair_mixed', 'width': '3+4', 'shape': list(SHAPE),
              'three_bit_rows': int((~selected).sum()), 'four_bit_rows': int(selected.sum()),
              'physical_bytes': payload, 'npz_container_bytes': path.stat().st_size,
              'index_bytes': fields['packed3'].nbytes + fields['packed4'].nbytes,
              'table_bytes': table3.nbytes + table4.nbytes,
              'mask_bytes': fields['row_mask'].nbytes, 'gain_bytes': 4, 'descriptor_bytes': 16,
              'selected_total_mlp_bytes': selected_total,
              'total_paid_mlp_bytes': payload + physical_ternary_bytes(down_path),
              'train_capture_sha256': sha256(capture), 'train_positions': positions.tolist(),
              'parents': {str(three): sha256(three), str(four): sha256(four)},
              'selected_mask_sha256': __import__('hashlib').sha256(fields['row_mask'].tobytes()).hexdigest(),
              'train_positive_benefit_count': int(np.count_nonzero(benefit > 0))}
    path.with_suffix('.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('layer', 'physical_bytes', 'total_paid_mlp_bytes', 'selected_total_mlp_bytes', 'train_positive_benefit_count')}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14, 27), required=True)
    run(parser.parse_args().layer)
