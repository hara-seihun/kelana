#!/usr/bin/env python3
"""How well does a weight-only sketch predict what a code change does to the consumer?

The optimizer in sketch.py only ever sees a surrogate gradient. Before running any
search we measure the surrogate itself: for nearest-rounded codes we compute the exact
consumer gradient (scoring only, never used to choose anything here) and compare it to
what each prepared sketch predicts. Selection quality, not gradient cosine, is the
quantity that decides whether a search can work.

The per-coordinate gain of flipping code j by delta is exactly

    gain = -2 delta s_j (W e)·W_j - s_j^2 ||W_j||^2

so the diagonal part s_j^2 ||W_j||^2 e_j is known for free and every bit of available
gain lives in the off-diagonal term. That is the term a sketch has to estimate.
"""
import argparse
import json
from pathlib import Path
import time
import numpy as np
import common
from common import D, FF


def predicted(e, l, d):
    return (e @ l.T) @ l + e * d[None, :]


def selection_report(g_true, g_hat, scales, norms, q, levels, energy, w, e, ks):
    """True consequences of the moves this estimator would pick. Uses W for scoring only."""
    def moves(g):
        grad = g * scales
        up = -2 * grad - norms
        dn = 2 * grad - norms
        up[q >= levels] = -np.inf
        dn[q <= -levels] = -np.inf
        return np.where(up > dn, 1.0, -1.0).astype(np.float32), np.maximum(up, dn)
    delta_hat, gain_hat = moves(g_hat)
    delta_true, gain_true = moves(g_true)
    # True gain of the moves the estimator proposes, in the estimator's own direction.
    realized = -2 * delta_hat * g_true * scales - norms
    rows = np.arange(len(q))[:, None]
    order_hat_all = np.argsort(gain_hat, axis=1)[:, ::-1]
    order_true_all = np.argsort(gain_true, axis=1)[:, ::-1]
    selections = []
    for k in ks:
        order_hat = order_hat_all[:, :k]
        picked = realized[rows, order_hat]
        best = gain_true[rows, order_true_all[:, :k]]
        # Coupled truth: apply the whole proposed step and measure the real energy change.
        proposal = np.zeros_like(q)
        proposal[rows, order_hat] = delta_hat[rows, order_hat]
        change = (proposal * scales) @ w.T
        coupled = float(((e @ w.T + change) ** 2).sum() - energy)
        selections.append(dict(
            top_k=k,
            selected_true_gain=float(picked.sum()),
            selected_positive_fraction=float((picked > 0).mean()),
            oracle_top_k_gain=float(best.sum()),
            gain_capture=float(picked.sum() / (best.sum() + 1e-30)),
            coupled_true_energy_change=coupled,
            coupled_relative=coupled / energy))
    return dict(
        sign_agreement=float(np.mean(delta_hat == delta_true)),
        gradient_cosine=float((g_true * g_hat).sum() /
                              (np.linalg.norm(g_true) * np.linalg.norm(g_hat) + 1e-30)),
        offdiag_cosine=None,
        selections=selections)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--layer', default='layer00')
    p.add_argument('--levels', type=int, nargs='+', default=[1, 3, 7])
    p.add_argument('--clip', type=float, default=1.0)
    p.add_argument('--ranks', type=int, nargs='+', default=[32, 128, 256])
    p.add_argument('--kinds', nargs='+', default=['singular', 'gaussian', 'rademacher'])
    p.add_argument('--seed', type=int, default=84123)
    p.add_argument('--topk', type=int, nargs='+', default=[1, 8, 64])
    p.add_argument('--json', required=True)
    a = p.parse_args()
    t0 = time.monotonic()
    v, w, weight_sha = common.load(a.layer)
    w2 = (w * w).sum(axis=0)
    frob = float((w * w).sum())
    results = []
    for levels in a.levels:
        q, scales = common.quantize(v, levels, a.clip)
        e = q * scales - v
        norms = w2[None, :] * scales ** 2
        # Exact consumer gradient and energy. Reporting only: nothing below selects on it
        # except the explicitly labelled oracle row.
        we = e @ w.T
        g_true = we @ w
        energy = float((we * we).sum())
        offdiag_true = g_true - e * w2[None, :]
        for kind in a.kinds:
            for rank in a.ranks:
                l = common.basis(w, weight_sha, a.layer, kind, rank, a.seed)
                for mode in ('exact', 'none'):
                    d = common.diagonal(w2, l, mode)
                    g_hat = predicted(e, l, d)
                    offdiag_hat = g_hat - e * (w2 if mode == 'exact' else (l * l).sum(axis=0))[None, :]
                    r = selection_report(g_true, g_hat, scales, norms, q, levels,
                                         energy, w, e, a.topk)
                    r['offdiag_cosine'] = float((offdiag_true * offdiag_hat).sum() /
                                                (np.linalg.norm(offdiag_true) *
                                                 np.linalg.norm(offdiag_hat) + 1e-30))
                    r.update(kind=kind, rank=rank, diagonal=mode, levels=levels,
                             captured_frobenius=float((l * l).sum() / frob),
                             sketch_MAC_fraction_per_product=rank / D)
                    results.append(r)
                    print(f"{kind:12s} r{rank:<4d} diag={mode:5s} L={levels} "
                          f"offdiag_cos={r['offdiag_cosine']:+.4f} "
                          f"sign={r['sign_agreement']:.3f} " +
                          ' '.join(f"k{s['top_k']}:cap={s['gain_capture']:+.3f},"
                                   f"dE={s['coupled_relative']:+.5f}"
                                   for s in r['selections']), flush=True)
        # Oracle selection, for the ceiling of one coupled step.
        r = selection_report(g_true, g_true, scales, norms, q, levels, energy, w, e, a.topk)
        r.update(kind='oracle-full-W', rank=D, diagonal='exact', levels=levels,
                 captured_frobenius=1.0, sketch_MAC_fraction_per_product=1.0,
                 offdiag_cosine=1.0)
        results.append(r)
        print(f"{'oracle':12s} r{D:<4d} diag=exact  L={levels} " +
              ' '.join(f"k{s['top_k']}:cap={s['gain_capture']:+.3f},"
                       f"dE={s['coupled_relative']:+.5f}" for s in r['selections']),
              flush=True)
    report = dict(format='kelana-random-sketch-probe/1', layer=a.layer, tokens=8,
                  clip=a.clip, seed=a.seed, top_k=a.topk,
                  weights_sha256=weight_sha, source_sha256=common.sha(__file__),
                  scope='Diagnostic only. The exact gradient is computed for scoring the '
                        'sketches; no code is kept and no acceptance uses it outside the '
                        'labelled oracle row.',
                  elapsed_seconds=time.monotonic() - t0, results=results)
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
