#!/usr/bin/env python3
"""Solve the coupled paid group-gain quadratic on quantized layer-14 producers."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
import torch
from safetensors import safe_open
from scipy.optimize import nnls

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from causal_refit import load_image
from fit import MODEL
from fit_direct import SOURCE, sha
from measure import probabilities, dense_attention
from right_transfer import OUT


def group_responses(x, p, images, quantizer):
    groups = []
    for g, image in enumerate(images):
        value = (x @ quantizer.decode(image, 'right').T).to(torch.bfloat16).float()
        left = quantizer.decode(image, 'left')
        contribution = sum((p[:, 2*g+h] @ value) @ left[h*1024:(h+1)*1024].T
                           for h in range(2))
        groups.append(contribution.reshape(-1, 1024))
    return torch.stack(groups, dim=0).double()


def score(groups, target, gains):
    residual = torch.einsum('g,gnd->nd', gains, groups) - target
    return (residual.square().sum() / target.square().sum()).item()


def fit(groups, target):
    n = groups.shape[0]
    flat = groups.reshape(n, -1)
    gram = flat @ flat.T
    rhs = flat @ target.flatten()
    common = (rhs.sum() / gram.sum()).clamp_min(0).item()
    # Strictly convex on the observed span. NNLS handles a zero or redundant group.
    chol = torch.linalg.cholesky(gram)
    matrix = chol.T.numpy()
    vector = torch.linalg.solve_triangular(chol, rhs[:, None], upper=False).flatten().numpy()
    positive, _ = nnls(matrix, vector)
    return common, torch.from_numpy(positive).double(), gram, rhs


def main(arm):
    torch.set_num_threads(8)
    spec = importlib.util.spec_from_file_location('pinned_spectral_quant', SOURCE)
    q = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(q)
    source = OUT / f'layer14-quantized-upstream-right-{arm}.npz'
    images = load_image(source)
    with safe_open(MODEL, framework='pt', device='cpu') as model:
        w = {name: model.get_tensor(f'model.layers.14.self_attn.{name}.weight').float()
             for name in ('q_proj', 'k_proj', 'v_proj', 'o_proj', 'q_norm', 'k_norm')}
    with np.load(OUT / 'layer14-quantized-upstream.npz') as data:
        inputs = {split: torch.from_numpy(data[split].copy().view(np.int16)).view(torch.bfloat16).float()
                  for split in ('train', 'validation')}
    responses, targets = {}, {}
    for split, x in inputs.items():
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        targets[split] = dense_attention(p, x, w['v_proj'], w['o_proj']).reshape(-1, 1024).double()
        responses[split] = group_responses(x, p, images, q)
    train, teacher = responses['train'], targets['train']
    common, optimum, gram, rhs = fit(train, teacher)
    held_common, held_optimum, _, _ = fit(responses['validation'], targets['validation'])
    one = torch.ones(8, dtype=torch.double)
    results = {'base': one, 'common': one * common, 'group': optimum,
               'held_common_oracle': one * held_common, 'held_oracle': held_optimum}
    scores = {name: {split: score(responses[split], targets[split], gain)
                     for split in inputs} for name, gain in results.items()}
    scores['group']['held_windows'] = [score(responses['validation'][:, a:a+256],
                                             targets['validation'][a:a+256], optimum)
                                       for a in range(0, len(targets['validation']), 256)]
    # Fold the eight gains into the existing FP16 left-row scales. Codes, cache and factor work stay fixed.
    packed = {}
    for g, image in enumerate(images):
        image['left_scales'] = (image['left_scales'].astype(np.float32) * optimum[g].item()).astype(np.float16)
        packed.update({f'group{g}_{key}': value for key, value in image.items()})
    output = OUT / f'layer14-quantized-upstream-causal-gain-{arm}.npz'
    np.savez(output, **packed)
    assert sum(v.nbytes for v in packed.values()) == 183552
    restored = load_image(output)
    paid = {}
    for split, x in inputs.items():
        p = probabilities(x, w['q_proj'], w['k_proj'], w['q_norm'], w['k_norm'])
        paid[split] = score(group_responses(x, p, restored, q), targets[split], one)
    receipt = {'arm': arm, 'train_windows': 4, 'held_validation_windows': 4,
               'objective': 'nonnegative exact global optimum for eight group gains under FP64 causal post-O squared error; original layer-14 Q/K and V/O teacher on quantized upstream; BF16 narrow cache; existing FP16 left scales rounded after fitting',
               'gains': optimum.tolist(), 'common_gain': common,
               'held_oracle_gains': held_optimum.tolist(), 'held_oracle_common_gain': held_common,
               'scores': scores,
               'paid_scores': paid, 'gram_eigenvalues': torch.linalg.eigvalsh(gram).tolist(),
               'stationarity_residual': (gram @ optimum - rhs).tolist(),
               'paid_bytes': sum(v.nbytes for v in packed.values()), 'factor_terms_per_token': 589824,
               'input_sha256': sha(OUT / 'layer14-quantized-upstream.npz'),
               'model_sha256': sha(MODEL), 'source_image_sha256': sha(source),
               'quantizer_sha256': sha(SOURCE), 'script_sha256': sha(Path(__file__)),
               'image_sha256': sha(output)}
    path = OUT / f'layer14-quantized-upstream-causal-gain-{arm}.json'
    path.write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'receipt': str(path), 'scores': scores, 'paid': paid, 'gains': optimum.tolist()}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('arm', choices=('selected192', 'uniform192'))
    main(parser.parse_args().arm)
