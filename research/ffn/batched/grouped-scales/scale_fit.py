"""How well a joint scale over G adjacent 128-blocks can replace the per-block scales.

Reads the FP16 weight scales straight out of the HALO tiles of the bench layer, and the real
activations, and answers two questions the GPU candidates then have to confirm:

  weight side      lam[i,b] -> L[i,g] * m[i,b] with m a small integer that rides in the matrix
                   operand itself. The operand width caps m, so it caps the scale resolution.
  activation side  one amax per (token, G*128) instead of one per (token, 128).

Both are offline/free on the weight side and a producer change on the activation side; the point
is what they cost in accuracy, since what they buy in speed is measured natively.
"""
import json
import numpy as np
import sys

DATA = "/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00"
TILE_ROWS, BLOCK, TILE_BLOCK_BYTES, TAIL_OFF = 32, 128, 896, 768


def halo_scales(path, rows, kdim):
    """FP16 scale per (row, 128-block) from a HALO tile image."""
    nb = kdim // BLOCK
    a = np.fromfile(path, dtype=np.uint8)
    a = a.reshape(rows // TILE_ROWS, nb, TILE_BLOCK_BYTES)
    tail = a[:, :, TAIL_OFF:TAIL_OFF + TILE_ROWS * 4].reshape(rows // TILE_ROWS, nb, TILE_ROWS, 4)
    s = tail[:, :, :, 2:4].copy().view(np.float16)[..., 0]     # (tiles, nb, 32)
    return np.ascontiguousarray(s.transpose(0, 2, 1).reshape(rows, nb)).astype(np.float64)


def fit_group(lam, M, trials=192):
    """lam: (n, G) positive. Return (rel_err per element, m, L) for the best L on a search grid.

    m_b = clip(round(lam_b / s), 1, M), L = s. Only s >= max(lam)/M keeps m in range; larger s
    trades resolution for headroom, so the grid runs from that bound upward.
    """
    n, G = lam.shape
    lo = lam.max(axis=1) / M
    hi = lam.max(axis=1) / max(M - 3, 1)
    grid = lo[:, None] * (hi / lo)[:, None] ** (np.linspace(0, 1, trials)[None, :])
    best = np.full(n, np.inf)
    bm = np.zeros((n, G), dtype=np.int32)
    bL = np.zeros(n)
    for t in range(trials):
        s = grid[:, t]
        m = np.clip(np.rint(lam / s[:, None]), 1, M)
        err = (s[:, None] * m - lam) / lam
        score = np.sqrt((err ** 2).mean(axis=1))
        better = score < best
        best = np.where(better, score, best)
        bm[better] = m[better].astype(np.int32)
        bL[better] = s[better]
    return best, bm, bL


def weight_side(report):
    dims = {"gate": (17408, 5120), "up": (17408, 5120), "down": (5120, 17408)}
    rng = np.random.default_rng(0)
    for name, (rows, kdim) in dims.items():
        lam = halo_scales(f"{DATA}/{name}.halo", rows, kdim)
        nb = lam.shape[1]
        take = rng.choice(rows, size=min(rows, 2048), replace=False)
        ent = {"rows": rows, "kdim": kdim, "nonpositive_scales": int((lam <= 0).sum())}
        for G in (2, 4, 8):
            g = lam[take].reshape(-1, nb // G, G).reshape(-1, G)
            spread = g.max(axis=1) / np.maximum(g.min(axis=1), 1e-30)
            ent[f"G{G}"] = {
                "spread_mean": float(spread.mean()),
                "spread_p99": float(np.percentile(spread, 99)),
                "spread_max": float(spread.max()),
            }
            for M, tag in ((7, "int4"), (15, "int5"), (127, "int8")):
                err, m, _ = fit_group(g, M)
                ent[f"G{G}"][tag] = {
                    "rel_rms": float(np.sqrt((err ** 2).mean())),
                    "rel_p99": float(np.percentile(err, 99)),
                    "distinct_m": int(len(np.unique(m))),
                }
            # shared scale with no correction at all: the naive joint scale
            L = g.mean(axis=1)
            ent[f"G{G}"]["shared_only"] = float(np.sqrt((((L[:, None] - g) / g) ** 2).mean()))
        report[name] = ent
        print(name, json.dumps(ent, indent=1), flush=True)


def hadamard_1024(x):
    """(..., n*1024) -> same shape, H_1024 x / 32, matching prep_chunk_r's normalisation."""
    s = x.reshape(*x.shape[:-1], -1, 1024).copy()
    h = 1
    while h < 1024:
        a = s.reshape(*s.shape[:-1], 1024 // (2 * h), 2, h)
        u, v = a[..., 0, :].copy(), a[..., 1, :].copy()
        a[..., 0, :] = u + v
        a[..., 1, :] = u - v
        h *= 2
    return (s / 32.0).reshape(x.shape)


def q_err(u, G, levels):
    """Relative RMS of the deterministic symmetric quantiser with one amax per G*128."""
    n, d = u.shape
    b = u.reshape(n, d // (G * BLOCK), G * BLOCK)
    amax = np.abs(b).max(axis=2, keepdims=True)
    scale = np.where(amax > 0, amax / levels, 1.0)
    q = np.clip(np.rint(b / scale), -levels, levels)
    e = (q * scale - b).reshape(n, d)
    return float(np.sqrt((e ** 2).sum() / (u ** 2).sum()))


def activation_side(report):
    D = 5120
    rows = []
    for c in range(32):
        rows.append(np.fromfile(f"{DATA}/c{c:03d}/x_in.f32", dtype=np.float32).reshape(-1, D))
    x = np.concatenate(rows).astype(np.float64)[:256]
    k = np.fromfile(f"{DATA}/post_norm_s.f32", dtype=np.float32).astype(np.float64)
    inv = 1.0 / np.sqrt((x ** 2).mean(axis=1, keepdims=True) + 1e-5)
    u = hadamard_1024(x * inv * k[None, :])
    ent = {"rows": int(u.shape[0])}
    for G in (1, 2, 4, 8):
        blocks = np.abs(u.reshape(-1, D // BLOCK, BLOCK)).max(axis=2)
        gmax = blocks.reshape(-1, D // (G * BLOCK), G).max(axis=2)
        ratio = np.repeat(gmax, G, axis=1) / np.maximum(blocks, 1e-30)
        ent[f"G{G}"] = {
            "amax_inflation_mean": float(ratio.mean()),
            "amax_inflation_p99": float(np.percentile(ratio, 99)),
            "a4_rel_rms": q_err(u, G, 7.0),
            "a8_rel_rms": q_err(u, G, 127.0),
        }
    report["activation_ffn_in"] = ent
    print("activation", json.dumps(ent, indent=1), flush=True)


if __name__ == "__main__":
    report = {}
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "weights"):
        weight_side(report)
    if what in ("all", "act"):
        activation_side(report)
    with open(f"results/scale-fit{'' if what == 'all' else '-' + what}.json", "w") as f:
        json.dump(report, f, indent=1)
