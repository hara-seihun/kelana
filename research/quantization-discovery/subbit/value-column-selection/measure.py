#!/usr/bin/env python3
"""Search one-group exchanges in the paid V/O output subspace, then price held transfer."""
import argparse
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import scipy.linalg
import torch
from safetensors import safe_open

HERE = Path(__file__).resolve().parent
SUB = HERE.parent
sys.path.insert(0, str(SUB / 'value-observer'))
from fit import MODEL, CAPTURES, load_capture
from fit_direct import SOURCE
from measure import probabilities, dense_attention
from refine import features

DATA = Path('/path/to/workspace/data/kelana-subbit/value-column-selection')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')
PARENT = Path('/path/to/workspace/data/kelana-subbit/value-column-skeleton')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def error(pred, reference):
    return float((pred-reference).square().sum() / reference.square().sum())


def columns(groups):
    return [28*g+j for g in sorted(groups) for j in range(28)]


def main(layer):
    torch.set_num_threads(8)
    path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(path) as packed:
        images = [{k: packed[k][g].copy() for k in packed.files} for g in range(8)]
    a = torch.cat([torch.cat([decoder.decode(image, 'left')[h*1024:(h+1)*1024]
                              for h in range(2)], dim=1) for image in images], dim=1).contiguous()
    parent = json.loads((PARENT / f'layer{layer:02d}.json').read_text())
    initial = tuple(parent['results']['10']['retained_head_groups'])
    assert a.shape == (1024, 448) and len(initial) == 10
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {k: model.get_tensor(f'model.layers.{layer}.self_attn.{k}.weight').float()
             for k in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    data = {}
    for split, count in (('train', 8), ('validation', 4)):
        x = load_capture(layer, split).reshape(count, 256, 1024)
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        z = features(x, p, images, decoder, 28)
        teacher = dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024)
        data[split] = (z, teacher)
    paid = data['train'][0] @ a.T
    gram = (a.T @ a).double().numpy()
    ya = (paid @ a).double().numpy()
    response_gram = ya.T @ ya
    def score(groups):
        idx = columns(groups)
        return float(np.trace(scipy.linalg.solve(
            gram[np.ix_(idx, idx)], response_gram[np.ix_(idx, idx)],
            assume_a='pos', check_finite=False)))
    trajectory = [{'groups': initial, 'score': score(initial)}]
    selected = initial
    while True:
        options = []
        for removed in selected:
            for added in range(16):
                if added not in selected:
                    alternative = tuple(sorted((set(selected)-{removed}) | {added}))
                    options.append((score(alternative), alternative, removed, added))
        best = max(options)
        if best[0] <= trajectory[-1]['score'] + 1e-5:
            break
        selected = best[1]
        trajectory.append({'groups': selected, 'score': best[0],
                           'removed': best[2], 'added': best[3]})
    quadratic = {}
    for split, (z, y) in data.items():
        quadratic[split] = ((z.T @ z).double(), (z.T @ y).double(),
                            float(y.double().square().sum()))
    candidates = []
    for removed in initial:
        for added in range(16):
            if added not in initial:
                candidates.append(tuple(sorted((set(initial)-{removed}) | {added})))
    candidates.append(initial)
    neighbor_scores = []
    for groups in candidates:
        kidx = columns(groups)
        midx = columns(set(range(16))-set(groups))
        c = a[:, kidx].double()
        transfer = torch.linalg.lstsq(c, a[:, midx].double()).solution.T.float().contiguous()
        image = decoder.quantize(transfer, 2, 28, 't')
        t = decoder.decode(image, 't').double()
        # Quadratic response loss. B maps all 448 narrow coordinates to the
        # retained 280: the retained rows are identity and missing rows are T.
        b = torch.zeros(448, 280, dtype=torch.double)
        b[kidx, torch.arange(280)] = 1
        b[midx] = t
        g = c.T @ c
        scores = {}
        for split, (zgram, cross, teacher_norm) in quadratic.items():
            mb = zgram @ b
            sse = teacher_norm - 2*torch.sum(b * (cross @ c)) + torch.sum((b.T @ mb) * g)
            scores[split] = float(sse)/teacher_norm
        neighbor_scores.append((scores, groups))
    neighbor_scores.sort(key=lambda pair: pair[0]['train'])
    selected_quantized = neighbor_scores[0][1]
    results = {}
    for name, groups in (('greedy', initial), ('exchange', selected), ('quantized_train', selected_quantized)):
        kidx = columns(groups)
        midx = columns(set(range(16))-set(groups))
        c, dropped = a[:, kidx].double(), a[:, midx].double()
        transfer = torch.linalg.lstsq(c, dropped).solution.T.float().contiguous()
        image = decoder.quantize(transfer, 2, 28, 't')
        rounded = decoder.decode(image, 't')
        splits = {}
        for split, (z, teacher) in data.items():
            base = z @ a.T
            pred_real = (z[:, kidx].double() + z[:, midx].double() @ transfer.double()) @ c.T
            pred_paid = (z[:, kidx] + z[:, midx] @ rounded) @ c.float().T
            splits[split] = {'real_teacher_error': error(pred_real.float(), teacher),
                             'two_bit_teacher_error': error(pred_paid, teacher),
                             'two_bit_paid_error': error(pred_paid, base),
                             'two_bit_window_teacher_error': [error(pred_paid[i*256:(i+1)*256], teacher[i*256:(i+1)*256]) for i in range(len(z)//256)]}
        results[name] = {'groups': groups, 'score': score(groups), 'transfer_hashes': {
            k: hashlib.sha256(v.tobytes()).hexdigest() for k, v in image.items()}, 'split': splits}
    assert abs(results['greedy']['split']['validation']['two_bit_teacher_error'] -
               parent['results']['10']['split']['validation']['arms']['paid_2']['teacher_error']) < 2e-6
    record = {'layer': layer, 'source_sha256': sha(Path(__file__)),
              'parent_sha256': sha(PARENT / f'layer{layer:02d}.json'), 'decoder_sha256': sha(SOURCE),
              'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
              'paid_image_sha256': sha(path), 'train_rows': len(data['train'][0]),
              'held_rows': len(data['validation'][0]),
              'selection': 'strict improving single-group swaps of exact train paid-response output-subspace trace, plus all 60 one-swap neighbors of initial scored by complete quantized train teacher loss; validation never selected',
              'trajectory': trajectory, 'quantized_neighbors': [
                  {'groups': groups, 'teacher_error': scores} for scores, groups in neighbor_scores],
              'results': results,
              'output_bytes': 107426, 'vo_bpw': 0.428472,
              'logical_output_terms': 333760}
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'trajectory': trajectory, 'held': {
        name: value['split']['validation']['two_bit_teacher_error'] for name, value in results.items()}}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(parser.parse_args().layer)
