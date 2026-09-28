#!/usr/bin/env python3
"""Code search driven by a weight-only sketch, with honest separation of the sketch
it optimizes against and the sketch it is accepted against.

A search that both proposes and accepts on one fixed sketch can drive that sketch's
surrogate error down while the real consumer error rises. Three protocols separate the
two effects:

  fixed            select and accept on one prepared sketch (what sketch.py does)
  holdout          select on sketch A, accept on an independent sketch B; both charged
  refresh          a small prepared pool, a different member each iteration
  refresh-holdout  pool member i selects, member i+1 accepts

The true down projection is computed only to record the score of a finished candidate
and the per-iteration trace. It never gates a proposal or an acceptance, for any
protocol except the explicit `fullw` reference which is the oracle by construction.

Online cost is counted in sketch-row products: every multiply by a sketch, in the
gradient, in each proposed update and in every validation, is charged r/D of one dense
down projection. Sorting, scalar work, launches and traffic are not counted and are not
free.
"""
import argparse
import json
from pathlib import Path
import time
import numpy as np
import common
from common import metric, D, FF


class Cost:
    """Sketch multiplies, in units of one dense (D x FF) projection per token."""

    def __init__(self):
        self.rows = 0
        self.products = 0

    def charge(self, rank, n=1):
        self.rows += rank * n
        self.products += n

    @property
    def fraction(self):
        return self.rows / D


def energy(z, e, d):
    return (z * z).sum(axis=1) + (e * e * d[None, :]).sum(axis=1)


def search(v, w, sel, acc, levels, clip, steps, changes, trace_truth=True):
    """sel/acc are lists of (L, d) pairs; iteration i uses sel[i % len], acc[i % len]."""
    q, scales = common.quantize(v, levels, clip)
    start = q.copy()
    cost = Cost()
    target = v @ w.T                      # scoring only
    def true_rms(codes):
        # (codes*scales - v) @ w.T is already the residual against target = v @ w.T.
        return float(np.linalg.norm((codes * scales - v) @ w.T) /
                     np.linalg.norm(target))
    trace = [dict(iteration=0, true_relative_rms=true_rms(q) if trace_truth else None)]
    backtracks = 0
    accepted_rows = 0
    for iteration in range(steps):
        lsel, dsel = sel[iteration % len(sel)]
        lacc, dacc = acc[iteration % len(acc)]
        shared = lacc is lsel
        e = q * scales - v
        z = e @ lsel.T
        cost.charge(len(lsel))
        grad = (z @ lsel + e * dsel[None, :]) * scales
        cost.charge(len(lsel))
        norm = ((lsel * lsel).sum(axis=0) + dsel)[None, :] * scales ** 2
        up = -2 * grad - norm
        dn = 2 * grad - norm
        up[q >= levels] = -np.inf
        dn[q <= -levels] = -np.inf
        gain = np.maximum(up, dn)
        delta = np.where(up > dn, 1.0, -1.0).astype(np.float32)
        order = np.argsort(gain, axis=1)[:, ::-1]
        if shared:
            za, ea = z, e
        else:
            za = e @ lacc.T
            cost.charge(len(lacc))
            ea = e
        pending = np.ones(len(v), dtype=bool)
        count = changes
        while np.any(pending):
            proposal = np.zeros_like(q)
            for r in np.flatnonzero(pending):
                ids = order[r, :count]
                ids = ids[gain[r, ids] > 0]
                proposal[r, ids] = delta[r, ids]
            if not np.any(proposal):
                break
            change = proposal * scales
            dz = change @ lacc.T
            cost.charge(len(lacc))
            delta_energy = ((2 * za * dz + dz * dz).sum(axis=1) +
                            ((2 * ea * change + change * change) * dacc[None, :]).sum(axis=1))
            accept = pending & (delta_energy < 0)
            q[accept] += proposal[accept]
            accepted_rows += int(accept.sum())
            pending &= ~accept
            if count == 1:
                break
            count = max(1, count // 2)
            backtracks += 1
        if trace_truth:
            trace.append(dict(iteration=iteration + 1, true_relative_rms=true_rms(q),
                              online_MAC_fraction=cost.fraction))
    before = (start * scales - v) @ w.T
    after = (q * scales - v) @ w.T
    surrogate = {}
    for name, (l, d) in (('selection', sel[0]), ('acceptance', acc[0])):
        e0 = start * scales - v
        e1 = q * scales - v
        surrogate[name + '_before'] = float(energy(e0 @ l.T, e0, d).sum())
        surrogate[name + '_after'] = float(energy(e1 @ l.T, e1, d).sum())
        # d >= 0 suffices for a PSD surrogate. Negative entries alone do not prove
        # indefiniteness; more negative entries than rank(L) give a negative direction
        # supported in ker(L). Record the entries without asserting that converse.
        surrogate[name + '_negative_diagonal_fraction'] = float((d < 0).mean())
        surrogate[name + '_diagonal_min'] = float(d.min())
        surrogate[name + '_negative_diagonal_mass'] = float(-d[d < 0].sum() /
                                                            (np.abs(d).sum() + 1e-30))
        surrogate[name + '_min_row_after'] = float(energy(e1 @ l.T, e1, d).min())
    return dict(levels=levels, clip=clip, steps=steps, changes=changes,
                changed_codes=int(np.count_nonzero(q != start)),
                accepted_row_updates=accepted_rows, acceptance_backtracks=backtracks,
                before=metric(before, target), after=metric(after, target),
                surrogate=surrogate,
                online_sketch_products=cost.products,
                online_MAC_fraction=cost.fraction,
                cost_scope='Sketch multiplies only (gradient, every proposal, every '
                           'validation), as a fraction of one dense down projection per '
                           'token. Sorting, scalar work, launches and traffic excluded. '
                           'No speed claim.',
                trace=trace)


def prepare(w, w2, weight_sha, layer, kind, rank, seeds, diag):
    out = []
    for seed in seeds:
        l = common.basis(w, weight_sha, layer, kind, rank, seed)
        out.append((l, common.diagonal(w2, l, diag)))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--layer', default='layer00')
    p.add_argument('--levels', type=int, nargs='+', default=[1, 3, 7])
    p.add_argument('--clip', type=float, default=1.0)
    p.add_argument('--ranks', type=int, nargs='+', default=[32, 128, 256])
    p.add_argument('--kinds', nargs='+', default=['singular', 'gaussian', 'rademacher'])
    p.add_argument('--protocols', nargs='+',
                   default=['fixed', 'holdout', 'refresh', 'refresh-holdout'])
    p.add_argument('--steps', type=int, nargs='+', default=[4])
    p.add_argument('--changes', type=int, default=64)
    p.add_argument('--pool', type=int, default=4)
    p.add_argument('--diag', nargs='+', default=['exact'],
                   choices=['exact', 'clamped', 'none'])
    p.add_argument('--seed', type=int, default=84123)
    p.add_argument('--json', required=True)
    a = p.parse_args()
    t0 = time.monotonic()
    v, w, weight_sha = common.load(a.layer)
    w2 = (w * w).sum(axis=0)
    results = []
    for kind, rank, diag in [(k, r, d) for k in a.kinds for r in a.ranks for d in a.diag]:
        pool = prepare(w, w2, weight_sha, a.layer, kind, rank,
                       [a.seed + i for i in range(a.pool + 1)], diag)
        for protocol in a.protocols:
            if protocol == 'fixed':
                sel, acc = pool[:1], pool[:1]
            elif protocol == 'holdout':
                sel, acc = pool[:1], pool[1:2]
            elif protocol == 'refresh':
                sel = acc = pool[:a.pool]
            elif protocol == 'refresh-holdout':
                sel, acc = pool[:a.pool], pool[1:a.pool + 1]
            else:
                raise SystemExit(protocol)
            for levels in a.levels:
                for steps in a.steps:
                    r = search(v, w, sel, acc, levels, a.clip, steps, a.changes)
                    r.update(kind=kind, rank=rank, protocol=protocol,
                             pool=len(sel), diagonal=diag)
                    results.append(r)
                    print(f"{kind:11s} r{rank:<4d} {protocol:16s} diag={diag:7s} "
                          f"L={levels} steps={steps} "
                          f"true {r['before']['relative_rms']*100:.4f}% -> "
                          f"{r['after']['relative_rms']*100:.4f}%  "
                          f"surr {r['surrogate']['selection_before']:.4g} -> "
                          f"{r['surrogate']['selection_after']:.4g}  "
                          f"cost={r['online_MAC_fraction']:.3f}", flush=True)
    report = dict(format='kelana-random-sketch-search/1', layer=a.layer, tokens=8,
                  clip=a.clip, seed=a.seed, changes=a.changes,
                  weights_sha256=weight_sha, source_sha256=common.sha(__file__),
                  common_sha256=common.sha(Path(__file__).resolve().parent / 'common.py'),
                  scope='Selection and acceptance use only weight-prepared sketches. '
                        'The full down projection is used to score candidates and to '
                        'record the trace, never to choose or accept a change.',
                  elapsed_seconds=time.monotonic() - t0, results=results)
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
