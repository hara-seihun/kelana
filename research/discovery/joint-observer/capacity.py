"""Program-independent lower bounds for finite lossy observers under squared error.

Given vectors y_i, any m-state carrier partitions them into <=m clusters. The
best arbitrary decoder returns cluster means. Bounds here relax the partition
problem; they do not charge the encoder or decoder and do not find a program.
"""
import numpy as np


def capacity_bounds(gram, capacities):
    g = np.asarray(gram, dtype=np.float64)
    n = len(g)
    if g.shape != (n, n) or n < 2:
        raise ValueError("a square Gram matrix of at least two centered outputs is needed")
    if any(not 1 <= m <= n for m in capacities):
        raise ValueError("state capacities must be between one and the input count")
    total = float(np.trace(g))
    if not np.isfinite(g).all() or total <= 0:
        raise ValueError("positive finite variation energy is needed")
    tolerance = 1e-10*total
    if np.max(np.abs(g-g.T)) > tolerance or np.max(np.abs(g.sum(axis=0))) > tolerance:
        raise ValueError("Gram matrix must be symmetric and centered")
    if np.linalg.eigvalsh(g).min() < -tolerance:
        raise ValueError("Gram matrix must be positive semidefinite")
    distances = np.maximum(0, np.diag(g)[:, None]+np.diag(g)[None, :]-2*g)/total
    # Self is excluded even if another output has exactly the same value.
    distances[np.diag_indices(n)] = np.inf
    nearest = np.sort(distances, axis=1)[:, :n-1]
    r = np.arange(1, n+1, dtype=np.float64)
    costs = np.column_stack([np.zeros(n), np.cumsum(nearest, axis=1)])/(2*r)
    slopes = 1/r
    # Every breakpoint of the lower envelopes is among these line intersections.
    # Extra inactive intersections only add evaluations; none can invalidate a bound.
    left, right = np.triu_indices(n, 1)
    crossings = (costs[:, right]-costs[:, left])/(slopes[left]-slopes[right])
    lambdas = np.unique(np.r_[0, crossings[crossings >= 0]])
    best = {m: (0.0, 0.0) for m in capacities}
    for begin in range(0, len(lambdas), 256):
        lam = lambdas[begin:begin+256]
        intercept = np.min(costs[None, :, :]+lam[:, None, None]*slopes, axis=2).sum(axis=1)
        for m in capacities:
            values = intercept-m*lam
            at = int(np.argmax(values))
            if values[at] > best[m][0]:
                best[m] = (float(values[at]), float(lam[at]))
    closest = float(nearest[:, 0].min())
    return [{"capacity": m,
             "closest_pair_squared_error_lower_bound": max(0, (n-m)*closest/2),
             "nearest_neighbor_dual_squared_error_lower_bound": max(0, best[m][0]),
             "relative_rms_lower_bound": max(0, best[m][0])**0.5,
             "dual_lambda": best[m][1]}
            for m in capacities]
