#!/usr/bin/env python3
"""Verify forty modular rank witnesses and exact-zero upper bounds."""
import argparse
import hashlib
import json
import re
from pathlib import Path

import numpy as np


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(4 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('data', type=Path)
    a = p.parse_args()
    layers = []
    for layer in range(40):
        stem = a.data / f'held-{layer}'
        extraction = json.loads(stem.with_suffix('.json').read_text())
        assert extraction['layer'] == layer and extraction['token'] == 1
        assert extraction['matrix_sha256'] == sha(stem.with_suffix('.f32'))
        assert extraction['shape'] == [2048, 2048]
        text = (a.data / f'held-{layer}.witness').read_text().strip()
        m = re.fullmatch(r'prime=251 distinct_columns=2048 output_width=2048 rank_mod_251=(\d+) pivot_product_mod_251=(\d+)', text)
        assert m, (layer, text)
        rank, product = map(int, m.groups())
        assert 0 < product < 251
        matrix = np.memmap(stem.with_suffix('.f32'), dtype='<f4', mode='r', shape=(2048, 2048))
        zero = np.all(matrix == 0, axis=1)
        zero_rows = int(zero.sum())
        assert rank == 2048 - zero_rows, (layer, rank, zero_rows)
        layers.append({'layer': layer, 'route': extraction['route'], 'selected_experts': extraction['selected_experts'],
                       'rank': rank, 'zero_rows': zero_rows, 'first_expert_zero_rows': int(zero[:1024].sum()),
                       'second_expert_zero_rows': int(zero[1024:].sum()),
                       'pivot_product_mod_251': product, 'matrix_sha256': extraction['matrix_sha256'],
                       'extraction_sha256': sha(stem.with_suffix('.json')),
                       'witness_stdout_sha256': sha(a.data / f'held-{layer}.witness')})
    source = Path(__file__).parent
    receipt = {'domain': 'all forty installed Qwen3.6 held-token-1 routes, first two selected expert gate/up preactivation rows; exact decoded FP32 reals',
               'proof': 'nonzero GF(251) minor after scaling each finite binary32 coefficient by 2^149 gives real rank lower bound; count of exact-zero rows gives matching upper bound',
               'layers': layers, 'full_rank_layers': sum(x['rank'] == 2048 for x in layers),
               'total_zero_rows': sum(x['zero_rows'] for x in layers),
               'nonfull_layers': {str(x['layer']): x['rank'] for x in layers if x['rank'] != 2048},
               'source_sha256': {name: sha(source / name) for name in ('extract.py', 'summarize.py')},
               'witness_source_sha256': sha(source.parent / 'installed-down-rank/witness.cpp'),
               'witness_executable_sha256': sha(a.data / 'witness'),
               'model_acquisition_sha256': sha('/path/to/workspace/data/qwen-moe/acquisition.json')}
    (a.data / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'full_rank_layers': receipt['full_rank_layers'], 'nonfull_layers': receipt['nonfull_layers'],
                      'total_zero_rows': receipt['total_zero_rows']}))


if __name__ == '__main__':
    main()
