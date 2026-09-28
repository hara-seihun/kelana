"""Exact cell enumeration for a fixed-step, two-coordinate RoPE phase gauge.

The certificate is algebraic over real inputs. Floating roots and rounding in this
executable are a numerical witness, not a formal exact-arithmetic certificate.
"""
import hashlib
import json
import math
from pathlib import Path

import numpy as np

TAU = 2 * math.pi
PERIOD = math.pi / 2


def rotate(v, phi):
    c, s = math.cos(phi), math.sin(phi)
    return np.stack((c * v[..., 0] - s * v[..., 1], s * v[..., 0] + c * v[..., 1]), axis=-1)


def codes(keys, phi, step):
    return np.clip(np.floor(rotate(keys, phi) / step + .5), -7, 7).astype(np.int64)


def boundaries(keys, step):
    out = [0., PERIOD]
    for x, y in keys:
        r = math.hypot(x, y)
        if r == 0:
            continue
        angle = math.atan2(y, x)
        for m in range(-7, 7):
            z = step * (m + .5) / r
            if abs(z) < 1:
                a = math.acos(z)
                out.extend(((-angle + a) % TAU, (-angle - a) % TAU,
                            (math.pi/2 - angle + a) % TAU,
                            (math.pi/2 - angle - a) % TAU))
    return sorted(set(p for p in out if 0 <= p <= PERIOD))


def objective(keys, queries, step, phi):
    teacher = queries @ keys.T
    encoded = codes(keys, phi, step)
    prediction = rotate(queries, phi) @ (step * encoded).T
    # Each head's score offset is invisible to softmax. Both heads share codes.
    delta = prediction - teacher
    delta -= delta.mean(axis=-1, keepdims=True)
    return float(np.sum(delta * delta))


def cell_coefficients(keys, queries, step, encoded):
    x, y = queries[:, 0, None], queries[:, 1, None]
    u, v = step * encoded[:, 0][None, :], step * encoded[:, 1][None, :]
    a = x * u + y * v
    b = x * v - y * u
    target = queries @ keys.T
    a -= a.mean(axis=1, keepdims=True)
    b -= b.mean(axis=1, keepdims=True)
    target -= target.mean(axis=1, keepdims=True)
    return (float(np.sum(a*a)), float(np.sum(b*b)), float(np.sum(a*b)),
            float(np.sum(a*target)), float(np.sum(b*target)), float(np.sum(target*target)))


def cell_value(coeff, phi):
    a, b, c, d, e, f = coeff
    x, y = math.cos(phi), math.sin(phi)
    return a*x*x+b*y*y+2*c*x*y-2*d*x-2*e*y+f


def stationary_angles(coeff):
    a, b, c, d, e, _ = coeff
    poly = np.array([2*c+2*e, -4*(b-a)+4*d, -12*c,
                     4*(b-a)+4*d, 2*c-2*e], dtype=float)
    nz = np.flatnonzero(abs(poly) > 1e-12 * max(1., np.max(abs(poly))))
    if len(nz) == 0:
        return [math.pi]
    roots = np.roots(poly[nz[0]:])
    return [math.pi] + [(2*math.atan(float(z.real))) % TAU
                        for z in roots if abs(z.imag) < 1e-8 * max(1., abs(z.real))]


def fit(keys, queries, step):
    cuts = boundaries(keys, step)
    best = (float('inf'), None, None)
    cells = 0
    for lo, hi in zip(cuts, cuts[1:]):
        if hi - lo < 1e-13:
            continue
        encoded = codes(keys, (lo+hi)/2, step)
        coeff = cell_coefficients(keys, queries, step, encoded)
        candidates = [lo, hi] + [p for p in stationary_angles(coeff) if lo < p < hi]
        for p in candidates:
            val = cell_value(coeff, p)
            if val < best[0]:
                best = (val, p, (lo, hi))
        cells += 1
    return best, cells, len(cuts)-2


def main():
    rng = np.random.default_rng(7421)
    keys = rng.normal(size=(12, 2)) * np.array([.60, .42]) + [.43, .30]
    queries = np.array([[1., 1.], [1.22, .77]])
    step = .75
    optimum, cells, crossings = fit(keys, queries, step)
    grid = [(objective(keys, queries, step, float(p)), float(p))
            for p in np.linspace(0, PERIOD, 100_000, endpoint=False)]
    grid_min = min(grid)
    # The analytic optimum can be a one-sided infimum at a code transition.
    lo, hi = optimum[2]
    interior = min(max(optimum[1], lo + 1e-8), hi - 1e-8)
    observed = objective(keys, queries, step, interior)
    assert abs(observed - optimum[0]) < 1e-7
    assert optimum[0] <= grid_min[0] + 1e-8
    assert optimum[0] <= objective(keys, queries, step, 0.) + 1e-8
    source = Path(__file__).read_bytes()
    receipt = dict(source_sha256=hashlib.sha256(source).hexdigest(), seed=7421,
                   keys=keys.tolist(), queries=queries.tolist(), step=step,
                   baseline=objective(keys, queries, step, 0.),
                   best_infimum=optimum[0], best_phase=optimum[1],
                   best_cell=[lo, hi], nearby_realized=observed,
                   grid_100000=grid_min[0], grid_phase=grid_min[1],
                   cells=cells, crossings=crossings,
                   boundary_upper_bound=56*len(keys))
    Path(__file__).with_name('receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({k: v for k, v in receipt.items() if k not in ('keys', 'queries')}, indent=2))


if __name__ == '__main__':
    main()
