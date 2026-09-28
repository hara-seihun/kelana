#!/usr/bin/env python3
"""Price the seven-exponential router on captured Qwen layer-0 producers."""
import hashlib
import json
from pathlib import Path

import numpy as np

BASE = Path('/path/to/workspace/data/qwen-moe')
CAP = BASE / 'route-capture'
DEST = BASE / 'router-observer' / 'real-routes.json'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def summary(values):
    return {'max': float(np.max(values)), 'mean': float(np.mean(values)),
            'p95': float(np.percentile(values, 95))}


def main():
    inventory = BASE / 'traffic.json'
    info = json.loads(inventory.read_text())
    router = next(t for t in info['tensors'] if t['name'] == 'blk.0.ffn_gate_inp.weight')
    model = BASE / 'Qwen3.6-35B-A3B-UD-Q4_K_M.gguf'
    offset = (info['header_bytes'] + 31) // 32 * 32 + router['offset']
    weights = np.memmap(model, '<f4', 'r', offset=offset, shape=(256, 2048)).astype(np.float64)
    result = {'contract': 'layer-0 captured normalized producer and routed output; double-precision router logits cast to FP32 for seven-exp arithmetic versus installed native FP32 selected IDs/scores. Not native dot order, a GPU kernel or whole-model quality.',
              'model_sha256': json.loads((BASE / 'acquisition.json').read_text())['sha256'],
              'inventory_sha256': sha(inventory), 'source_sha256': sha(Path(__file__)),
              'captures': {}, 'splits': {}}
    for split in ('train', 'held'):
        paths = {name: CAP / f'{split}.0.{node}-0.bin' for name, node in
                 (('input', 'attn_post_norm'), ('ids', 'ffn_moe_topk'),
                  ('scores', 'ffn_moe_weights_norm'), ('down', 'ffn_moe_down'))}
        result['captures'][split] = {name: sha(path) for name, path in paths.items()}
        ids = np.memmap(paths['ids'], '<i4').reshape(-1, 8)
        n = len(ids)
        x = np.memmap(paths['input'], '<f4').reshape(n, 2048).astype(np.float64)
        scores = np.memmap(paths['scores'], '<f4').reshape(n, 8).astype(np.float64)
        down = np.memmap(paths['down'], '<f4').reshape(n, 8, 2048).astype(np.float64)
        logits = x @ weights.T
        # Index tie-break only matters when logits coincide. Sort the full bank
        # so the eighth-to-ninth margin uses the same ordering as the route.
        order = np.argsort(-logits, axis=1, kind='stable')
        raw = order[:, :8]
        route_matches = np.array([set(row) == set(native) for row, native in zip(raw, ids)])
        margin = logits[np.arange(n), order[:, 7]] - logits[np.arange(n), order[:, 8]]
        selected = np.take_along_axis(logits, ids, axis=1)
        selected_f32 = selected.astype(np.float32)
        z = np.exp(selected_f32 - np.max(selected_f32, axis=1, keepdims=True))
        alt = (z / np.sum(z, axis=1, keepdims=True)).astype(np.float64)
        score_error = np.max(np.abs(scores - alt), axis=1)
        reference = np.einsum('ne,ned->nd', scores, down)
        trial = np.einsum('ne,ned->nd', alt, down)
        output_error = np.linalg.norm(trial - reference, axis=1) / np.linalg.norm(reference, axis=1)
        # Standard sequential FP32 dot error, with no assumption about the
        # actual HIP reduction. This suffices for real-logit route stability
        # against any implementation obeying the stated dot envelope.
        u = 2**-24
        gamma = 2048*u/(1-2048*u)
        double_gamma = 2048*np.finfo(np.float64).eps/(1-2048*np.finfo(np.float64).eps)
        err = (gamma + 2*double_gamma) * (np.abs(x) @ np.abs(weights).T)
        certificate = np.min(logits[np.arange(n)[:, None], raw] - err[np.arange(n)[:, None], raw], axis=1) > np.max(
            np.take_along_axis(logits + err, order[:, 8:], axis=1), axis=1)
        result['splits'][split] = {
            'rows': n, 'raw_route_matches_native': int(route_matches.sum()),
            'certified_dot_envelope_routes': int(certificate.sum()),
            'route_margin': {'min': float(np.min(margin)), **summary(margin)},
            'max_selected_score_difference': summary(score_error),
            'routed_sum_relative_l2_difference': summary(output_error),
            'mismatch_rows': np.flatnonzero(~route_matches).tolist(),
            'uncertified_rows': np.flatnonzero(~certificate).tolist(),
            'max_dot_envelope': float(err.max()),
        }
    DEST.parent.mkdir(parents=True, exist_ok=True)
    DEST.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result['splits'], indent=2))


if __name__ == '__main__':
    main()
