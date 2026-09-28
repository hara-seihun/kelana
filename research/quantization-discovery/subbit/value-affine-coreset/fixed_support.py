#!/usr/bin/env python3
"""Minimum query-independent positive support for all attention distributions."""
import argparse
import hashlib
import importlib.util
import json
import sys
import time
from pathlib import Path

import numpy as np
from scipy.optimize import linprog
import torch

HERE = Path(__file__).resolve()
SUBBIT = HERE.parents[1]
sys.path.insert(0, str(SUBBIT / 'value-observer'))
from fit import CAPTURES, load_capture
from fit_direct import SOURCE

DATA = Path('/path/to/workspace/data/kelana-subbit')


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b''):
            digest.update(chunk)
    return digest.hexdigest()


def run(layer):
    torch.set_num_threads(4)
    x = load_capture(layer, 'validation').reshape(-1, 256, 1024)[0]
    image = DATA / 'value-observer' / f'layer{layer:02d}-joint-r28.npz'
    metadata_path = DATA / 'value-centered-int4' / f'layer{layer:02d}-8x4.json'
    metadata = json.loads(metadata_path.read_text())
    assert sha(image) == metadata['image_sha256']
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    groups = []
    started = time.perf_counter()
    with np.load(image) as factors:
        for group in range(8):
            arrays = {key: factors[key][group].copy() for key in factors.files}
            right = decoder.decode(arrays, 'right')
            value = (x @ right.T).to(torch.bfloat16).float().numpy()
            step = np.asarray(metadata['metadata'][group]['int4_coordinate']['step'])
            code = np.rint(value / step).clip(-7, 7).astype(np.int8)
            assert code.shape == (256, 28)
            unique, representative, inverse = np.unique(code, axis=0, return_index=True, return_inverse=True)
            matrix = np.vstack((np.ones(len(unique)), unique.T.astype(np.float64)))
            vertices = []
            redundant = []
            certificates = []
            for index in range(len(unique)):
                other = np.arange(len(unique)) != index
                difference = unique[index].astype(np.int64) - unique[other].astype(np.int64)
                inequality = np.column_stack((-difference, np.ones(len(difference))))
                separation = linprog(np.r_[np.zeros(28), -1.], A_ub=inequality,
                                     b_ub=np.zeros(len(difference)),
                                     bounds=[(-1, 1)]*28 + [(0, None)], method='highs')
                if separation.success and separation.x[-1] > 1e-5:
                    witness = np.rint(separation.x[:28] * 1_000_000).astype(np.int64)
                    margin = int((difference @ witness).min())
                    if margin > 0:
                        vertices.append(index)
                        certificates.append({'key': int(representative[index]), 'normal': witness.tolist(),
                                             'integer_margin': margin})
                        continue
                result = linprog(np.zeros(len(unique)-1), A_eq=matrix[:, other], b_eq=matrix[:, index],
                                 bounds=(0, None), method='highs')
                if result.success and np.max(np.abs(matrix[:, other] @ result.x - matrix[:, index])) < 1e-7:
                    redundant.append(index)
                else:
                    raise RuntimeError(f'no separating integer certificate at group={group}, code={index}: {separation.message}; {result.message}')
            groups.append({'group': group, 'vertex_representative_keys': representative[vertices].tolist(),
                           'nonvertex_representative_keys': representative[redundant].tolist(),
                           'integer_separation_certificates': certificates,
                           'distinct_codes': len(unique), 'duplicate_key_rows': 256-len(unique),
                           'code_sha256': hashlib.sha256(code.tobytes()).hexdigest()})
            print(f'layer {layer} group {group}: {len(vertices)} required distinct codes / {len(unique)}', flush=True)
    receipt = {'layer': layer, 'groups': groups,
               'minimum_fixed_keys': sum(len(g['vertex_representative_keys']) for g in groups),
               'elapsed_cpu_seconds': time.perf_counter()-started, 'source_sha256': sha(HERE),
               'model_capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
               'image_sha256': sha(image), 'metadata_sha256': sha(metadata_path),
               'domain': 'First previously inspected original-producer validation window; paid rank-28 V codes; all simplex attention weights on first 256 positions, nonnegative query-independent selected keys, exact real code moment. HiGHS feasibility in floating arithmetic.'}
    dest = DATA / 'value-affine-coreset' / f'fixed-layer{layer:02d}.json'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(receipt, indent=2)+'\n')
    print(json.dumps({'receipt': str(dest), 'required_of_2048': receipt['minimum_fixed_keys'],
                      'elapsed_cpu_seconds': receipt['elapsed_cpu_seconds']}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    run(parser.parse_args().layer)
