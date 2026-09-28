#!/usr/bin/env python3
"""Keep paid narrow-V output code groups and fit only missing-group transfers."""
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

DATA = Path('/path/to/workspace/data/kelana-subbit/value-column-skeleton')
IMAGE = Path('/path/to/workspace/data/kelana-subbit/value-observer')


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def error(pred, reference):
    return float((pred-reference).square().sum() / reference.square().sum())


def main(layer):
    torch.set_num_threads(8)
    path = IMAGE / f'layer{layer:02d}-joint-r28.npz'
    spec = importlib.util.spec_from_file_location('factor_decoder', SOURCE)
    decoder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(decoder)
    with np.load(path) as packed:
        images = [{k: packed[k][g].copy() for k in packed.files} for g in range(8)]
    a = torch.cat([torch.cat([decoder.decode(image, 'left')[h*1024:(h+1)*1024]
                                for h in range(2)], dim=1)
                   for image in images], dim=1).contiguous()
    # Sixteen intact 28-coordinate heads. Their paid two-bit code and FP16
    # row scale are copied, not decoded/requantized in the proposed image.
    assert a.shape == (1024, 448)
    _, _, pivot = scipy.linalg.qr(a.numpy(), pivoting=True, mode='economic', check_finite=False)
    pivot_order = list(dict.fromkeys(int(column // 28) for column in pivot))
    assert len(pivot_order) == 16
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
    # Exact greedy group choice for the train paid-response *output subspace*.
    # For C=A[:,S], the least-squares output projection saves
    # tr((C^T C)^-1 C^T Y^T Y C). Both 448x448 Grams are computed once.
    paid_train = data['train'][0] @ a.T
    gram = (a.T @ a).double().numpy()
    ya = (paid_train @ a).double().numpy()
    response_gram = ya.T @ ya
    order = []
    candidates = list(range(16))
    for _ in range(16):
        best = None
        for group in candidates:
            indices = [g*28+j for g in order+[group] for j in range(28)]
            gs = gram[np.ix_(indices, indices)]
            hs = response_gram[np.ix_(indices, indices)]
            score = float(np.trace(scipy.linalg.solve(gs, hs, assume_a='pos', check_finite=False)))
            if best is None or score > best[0]:
                best = (score, group)
        order.append(best[1])
        candidates.remove(best[1])
    results = {}
    for keep in (8, 10, 12, 14):
        retained = sorted(order[:keep])
        missing = [g for g in range(16) if g not in retained]
        kidx = [g*28+j for g in retained for j in range(28)]
        midx = [g*28+j for g in missing for j in range(28)]
        c, dropped = a[:, kidx].double(), a[:, midx].double()
        # Exact output-space least squares. The retained transfer is identity;
        # every missing group is a linear combination of intact paid columns.
        transfer = torch.linalg.lstsq(c, dropped).solution.T.float().contiguous()
        ztrain, ytrain = data['train']
        x = ztrain[:, midx].double()
        residual = ytrain.double() - ztrain[:, kidx].double() @ c.T
        projected = residual @ c
        # Minimize the complete train teacher response while leaving the
        # retained paid columns intact. The two independent least squares
        # are over input features and the output subspace, respectively.
        teacher_transfer = torch.linalg.solve(
            c.T @ c, torch.linalg.lstsq(x, projected).solution.T).T.float().contiguous()
        transfers = {'paid': transfer, 'teacher': teacher_transfer}
        decoded = {}
        hashes = {}
        for target, matrix in transfers.items():
            for bits in (2, 4, 8):
                image = decoder.quantize(matrix, bits, 28, 't')
                decoded[(target, bits)] = decoder.decode(image, 't')
                hashes[f'{target}_{bits}'] = {name: hashlib.sha256(value.tobytes()).hexdigest()
                                               for name, value in image.items()}
        entries = {}
        for split, (z, teacher) in data.items():
            base = z @ a.T
            zkeep = z[:, kidx]
            zmiss = z[:, midx]
            predictions = {f'{target}_real':
                           (zkeep.double() + zmiss.double() @ matrix.double()) @ c.T
                           for target, matrix in transfers.items()}
            for (target, bits), matrix in decoded.items():
                predictions[f'{target}_{bits}'] = (zkeep + zmiss @ matrix) @ c.float().T
            entries[split] = {
                'paid_teacher_error': error(base, teacher),
                'arms': {name: {
                    'teacher_error': error(pred.float(), teacher),
                    'paid_response_error': error(pred.float(), base),
                    'window_teacher_error': [error(pred.reshape(-1, 256, 1024)[i].float(),
                                                   teacher.reshape(-1, 256, 1024)[i])
                                             for i in range(len(z)//256)],
                } for name, pred in predictions.items()},
            }
        # Parent left image has 16 * (1024*7 packed code bytes + 1024*2 scale bytes)
        # plus eight 16-byte descriptors; each paid group is stored separately.
        paid_output_bytes = 147584
        retained_bytes = keep * 1024 * (7 + 2)
        transfer_shape = ((16-keep)*28, keep*28)
        transfer_bytes = {str(bits): transfer_shape[0] * (
            ((transfer_shape[1]*bits+7)//8) + 2*((transfer_shape[1]+27)//28))
                          for bits in (2, 4, 8)}
        results[str(keep)] = {
            'retained_head_groups': retained, 'missing_head_groups': missing,
            'transfer_shape': transfer_shape, 'transfer_hashes': hashes,
            'retained_paid_output_bytes': retained_bytes,
            'transfer_bytes': transfer_bytes,
            'output_bytes_with_descriptors_and_group_mask': {
                bits: retained_bytes + size + 128 + 16 + 2 for bits, size in transfer_bytes.items()},
            'paid_output_bytes': paid_output_bytes,
            'logical_output_terms': 1024*keep*28 + keep*(16-keep)*28*28,
            'split': entries,
        }
    record = {
        'layer': layer, 'source_sha256': sha(Path(__file__)), 'decoder_sha256': sha(SOURCE),
        'model_sha256': sha(MODEL), 'capture_sha256': sha(CAPTURES / f'layer{layer:02d}.npz'),
        'paid_image_sha256': sha(path), 'train_rows': len(data['train'][0]),
        'held_rows': len(data['validation'][0]),
        'selection': 'train-paid-response exact greedy selection of intact 28-coordinate head groups, using the output-subspace projection trace; no held data used',
        'pivoted_qr_group_order': pivot_order, 'response_greedy_group_order': order,
        'map': 'output-space paid response or joint input/output train-teacher least squares for dropped paid columns, followed by odd-grid per-28 FP16-scale transfer quantization; original BF16 Q/K attention and narrow V retained',
        'results': results,
    }
    DATA.mkdir(parents=True, exist_ok=True)
    dest = DATA / f'layer{layer:02d}.json'
    dest.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'receipt': str(dest), 'held': {
        rank: {name: scores['teacher_error'] for name, scores in entry['split']['validation']['arms'].items()}
        for rank, entry in results.items()}}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--layer', type=int, choices=(0, 14), required=True)
    main(parser.parse_args().layer)
