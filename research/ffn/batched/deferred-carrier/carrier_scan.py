"""Can the paired-FP16 radix carrier survive more than one 128-block before it is separated?

The paired map packs a gate row and an up row into one FP16 coefficient `t_g + 2047*t_u`, runs one
`v_wmma_f32_16x16x16_f16`, and separates the two channels out of the accumulator after every
128-block because the weight scales and the activation scale change there. If the scales were
constant over G adjacent blocks, the carrier could stay packed across all G and the separation
epilogue would be paid once per G blocks instead of once per block.

Two things then have to hold, and this file measures both on the real layer:

  representation   lam[i,b] -> L[i,g] * m[i,b] with m a small positive integer folded into the
                   matrix operand, and one activation amax per (token, G*128). The operand is
                   FP16 and must stay an exact integer, so M*(1+R) <= 2048: raising the multiplier
                   range M shrinks the usable radix R, and the separation headroom R/(2M) falls as
                   1/M^2. M = 1 is the only setting with real headroom, and it is a shared scale.

  range            separation needs |S_g| <= R/2 where S_g = sum over the whole deferred run of
                   m_g * t_g * q. Worst case that is 7*nnz, so no deferral is safe by counting
                   alone; what decides it is the realised distribution on real weights and real
                   activations, plus a certificate that is cheap enough to compute online.

Subcommands:
  check     decode the HALO tiles here, run the whole FFN on the CPU, compare to the residual the
            engine produced. Validates the decoder and the activation pipeline before any claim.
  weights   scale-fit statistics for the shared-scale (M=1) and integer-multiplier (M>1) forms.
  carrier   the realised |S_g|, |S_u| and |p| distributions per deferral length, the observed
            wraps, and how often the online L1 certificate proves safety.
"""
import argparse
import json
import sys
import numpy as np

DATA = "/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench"
BLOCK = 128
TILE_ROWS = 32
TILE_BLOCK_BYTES = 896
TAIL_OFF = 768
D, FF = 5120, 17408


# ------------------------------------------------------------------ HALO tiles

def _peel(b, n):
    """The kernel's peel: repeated multiply by three, taking the carry byte."""
    b = b.astype(np.uint32)
    out = []
    for _ in range(n):
        m = b * 3
        out.append((m >> 8).astype(np.uint8))
        b = m & 0xFF
    return out


def halo_matrix(path, rows, kdim):
    """(trits int8 [rows][kdim] in {-1,0,1}, scales float32 [rows][nb]) from a HALO tile image."""
    nb = kdim // BLOCK
    tiles = rows // TILE_ROWS
    a = np.fromfile(path, dtype=np.uint8)
    if a.size != tiles * nb * TILE_BLOCK_BYTES:
        raise SystemExit(f"{path}: {a.size} bytes, expected {tiles * nb * TILE_BLOCK_BYTES}")
    a = a.reshape(tiles, nb, TILE_BLOCK_BYTES)
    qs = np.concatenate([a[:, :, 0:512].reshape(tiles, nb, TILE_ROWS, 16),
                         a[:, :, 512:768].reshape(tiles, nb, TILE_ROWS, 8)], axis=3)
    tail = a[:, :, TAIL_OFF:TAIL_OFF + TILE_ROWS * 4].reshape(tiles, nb, TILE_ROWS, 4)
    scale = np.ascontiguousarray(tail[:, :, :, 2:4]).view(np.float16)[..., 0]
    trit = np.zeros((tiles, nb, TILE_ROWS, BLOCK), dtype=np.uint8)
    for d in range(6):
        for j in range(4):
            t = _peel(qs[:, :, :, 4 * d + j], 5)
            w, half, = j & 1, j >> 1
            p = 2 * d + w
            trit[..., 8 * p + 2 * half + 0] = t[0]
            trit[..., 8 * p + 2 * half + 1] = t[1]
            trit[..., 8 * p + 4 + 2 * half + 0] = t[2]
            trit[..., 8 * p + 4 + 2 * half + 1] = t[3]
            trit[..., 96 + 4 * d + j] = t[4]
    for h in range(2):
        t = _peel(tail[:, :, :, h], 4)
        trit[..., 120 + 2 * h] = t[0]
        trit[..., 121 + 2 * h] = t[1]
        trit[..., 124 + 2 * h] = t[2]
        trit[..., 125 + 2 * h] = t[3]
    w = (trit.astype(np.int8) - 1).transpose(0, 2, 1, 3).reshape(rows, kdim)
    s = np.ascontiguousarray(scale.transpose(0, 2, 1).reshape(rows, nb)).astype(np.float32)
    return w, s


# ------------------------------------------------------------------ activations

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


def quantise(u, group, levels, clip=1.0):
    """Deterministic symmetric quantiser, one amax per (row, group). Returns (q int16, c float32)."""
    n, d = u.shape
    b = u.reshape(n, d // group, group)
    amax = np.abs(b).max(axis=2)
    c = np.where(amax > 0, amax * clip / levels, 1.0).astype(np.float32)
    q = np.clip(np.rint(b / c[:, :, None]), -levels, levels).astype(np.int16)
    return q.reshape(n, d), c


def load_rows(layer, rows):
    x = [np.fromfile(f"{DATA}/{layer}/c{c:03d}/x_in.f32", dtype=np.float32).reshape(-1, D)
         for c in range(rows // 8)]
    y = [np.fromfile(f"{DATA}/{layer}/c{c:03d}/x_out.f32", dtype=np.float32).reshape(-1, D)
         for c in range(rows // 8)]
    return np.concatenate(x)[:rows], np.concatenate(y)[:rows]


def ffn_input(x, layer):
    k = np.fromfile(f"{DATA}/{layer}/post_norm_s.f32", dtype=np.float32)
    inv = 1.0 / np.sqrt((x.astype(np.float32) ** 2).mean(axis=1, keepdims=True) + 1e-5)
    return hadamard_1024((x * inv * k[None, :]).astype(np.float32))


def project(w, s, q, c, group):
    """sum_b lam[i,b] * c[t,b] * (ternary row i . q block b), returned as [tokens][rows]."""
    rows, kdim = w.shape
    nb = kdim // BLOCK
    per = group // BLOCK
    out = np.zeros((q.shape[0], rows), dtype=np.float32)
    for g in range(kdim // group):
        sl = slice(g * group, (g + 1) * group)
        acc = (q[:, sl].astype(np.float32) @ w[:, sl].astype(np.float32).T)
        # one activation scale per group, one weight scale per block: the block partials have to be
        # re-formed when the weight scale still varies inside the group
        if per == 1:
            out += acc * s[None, :, g] * c[:, g, None]
        else:
            out += acc * c[:, g, None] * s[None, :, g * per:(g + 1) * per].mean(axis=1)
    return out


def blockwise_project(w, s, q, c, group):
    """Exact per-128 weight scales, activation scale per `group`. [tokens][rows]."""
    rows, kdim = w.shape
    per = group // BLOCK
    out = np.zeros((q.shape[0], rows), dtype=np.float32)
    for b in range(kdim // BLOCK):
        sl = slice(b * BLOCK, (b + 1) * BLOCK)
        acc = q[:, sl].astype(np.float32) @ w[:, sl].astype(np.float32).T
        out += acc * s[None, :, b] * c[:, b // per, None]
    return out


# ------------------------------------------------------------------ check

def cmd_check(args):
    rows = args.rows
    x, y = load_rows(args.layer, rows)
    wg, sg = halo_matrix(f"{DATA}/{args.layer}/gate.halo", FF, D)
    wu, su = halo_matrix(f"{DATA}/{args.layer}/up.halo", FF, D)
    wd, sd = halo_matrix(f"{DATA}/{args.layer}/down.halo", D, FF)
    signs_ff = np.fromfile(f"{DATA}/{args.layer}/signs_ff.f32", dtype=np.float32)
    report = {"layer": args.layer, "rows": rows,
              "trit_density": {"gate": float((wg != 0).mean()), "up": float((wu != 0).mean()),
                               "down": float((wd != 0).mean())},
              "max_nonzeros_per_128": {
                  "gate": int((wg != 0).reshape(FF, D // BLOCK, BLOCK).sum(axis=2).max()),
                  "up": int((wu != 0).reshape(FF, D // BLOCK, BLOCK).sum(axis=2).max()),
                  "down": int((wd != 0).reshape(D, FF // BLOCK, BLOCK).sum(axis=2).max())}}
    u = ffn_input(x, args.layer)
    for levels, tag in ((127.0, "a8"), (7.0, "a4")):
        q, c = quantise(u, BLOCK, levels)
        gate = blockwise_project(wg, sg, q, c, BLOCK)
        up = blockwise_project(wu, su, q, c, BLOCK)
        hid = (gate / (1.0 + np.exp(-gate))) * up * signs_ff[None, :]
        h = hadamard_1024(hid)
        qh, ch = quantise(h, BLOCK, levels)
        out = x + blockwise_project(wd, sd, qh, ch, BLOCK)
        err = out - y
        report[tag] = {"rel_rms": float(np.sqrt((err ** 2).sum() / (y ** 2).sum())),
                       "bias": float(err.mean()),
                       "ref_rms": float(np.sqrt((y ** 2).mean()))}
        print(tag, json.dumps(report[tag]), flush=True)
    print(json.dumps(report["trit_density"]), json.dumps(report["max_nonzeros_per_128"]))
    if args.json:
        json.dump(report, open(args.json, "w"), indent=1)


# ------------------------------------------------------------------ weight scales

def fit_shared(lam):
    """One scale per (row, group). Best multiplicative L is the one that minimises relative RMS."""
    # minimise sum ((L - l)/l)^2 over L: L = sum(1/l) / sum(1/l^2)
    inv = 1.0 / lam
    L = inv.sum(axis=1) / (inv ** 2).sum(axis=1)
    return (L[:, None] - lam) / lam, L


def fit_multiplier(lam, M, trials=192):
    """lam -> L * m, m integer in [1, M]. Grid search on L, same shape as grouped-scales' fit."""
    n, G = lam.shape
    lo = lam.max(axis=1) / M
    hi = lam.max(axis=1) / max(M - 3, 1) if M > 1 else lo * 1.0000001
    grid = lo[:, None] * (hi / lo)[:, None] ** (np.linspace(0, 1, trials)[None, :])
    best = np.full(n, np.inf)
    bm = np.ones((n, G), dtype=np.int32)
    for t in range(trials):
        s = grid[:, t]
        m = np.clip(np.rint(lam / s[:, None]), 1, M)
        err = (s[:, None] * m - lam) / lam
        score = np.sqrt((err ** 2).mean(axis=1))
        better = score < best
        best = np.where(better, score, best)
        bm[better] = m[better].astype(np.int32)
    return best, bm


def cmd_weights(args):
    report = {"layer": args.layer, "note": "M*(1+R) <= 2048 keeps the FP16 operand an exact integer"}
    for name, rows, kdim in (("gate", FF, D), ("up", FF, D), ("down", D, FF)):
        _, lam = halo_matrix(f"{DATA}/{args.layer}/{name}.halo", rows, kdim)
        lam = lam.astype(np.float64)
        nb = lam.shape[1]
        rng = np.random.default_rng(0)
        take = rng.choice(rows, size=min(rows, 2048), replace=False)
        ent = {"rows": rows, "kdim": kdim, "blocks": nb}
        for G in args.groups:
            if nb % G:
                continue
            g = lam[take].reshape(-1, nb // G, G).reshape(-1, G)
            spread = g.max(axis=1) / np.maximum(g.min(axis=1), 1e-30)
            e = {"spread_mean": float(spread.mean()), "spread_max": float(spread.max())}
            err, _ = fit_shared(g)
            e["M1_shared"] = {"rel_rms": float(np.sqrt((err ** 2).mean())),
                              "rel_p99": float(np.percentile(np.abs(err), 99)),
                              "radix": 2047, "headroom": 1023}
            for M in (2, 3, 7):
                R = 2048 // M - 1
                err, m = fit_multiplier(g, M)
                e[f"M{M}"] = {"rel_rms": float(np.sqrt((err ** 2).mean())),
                              "radix": R, "headroom": R // (2 * M),
                              "mean_multiplier": float(m.mean())}
            ent[f"G{G}"] = e
        report[name] = ent
        print(name, json.dumps(ent, indent=1), flush=True)
    if args.json:
        json.dump(report, open(args.json, "w"), indent=1)


# ------------------------------------------------------------------ carrier range

def carrier_stats(acc_g, acc_u, headroom, radix):
    """acc_*: [tokens][rows] exact integer channel sums for one deferred run.

    Only the low channel has an algebraic bound. `u = rint(p/R)` and `g = p - R*u` recover any
    integer u exactly as long as |g| <= R/2, so a large high channel is not a wrap; it raises |p|
    and therefore the FP32/reciprocal condition, which the native probe measures separately.
    """
    ag, au = np.abs(acc_g), np.abs(acc_u)
    p = acc_g + radix * acc_u
    return {"n": int(ag.size),
            "max_g": float(ag.max()), "max_u": float(au.max()),
            "p999_g": float(np.percentile(ag, 99.9)), "p9999_g": float(np.percentile(ag, 99.99)),
            "rms_g": float(np.sqrt((acc_g.astype(np.float64) ** 2).mean())),
            "max_p": float(np.abs(p).max()),
            "wraps": int((ag > headroom).sum()),
            "high_over_headroom": int((au > headroom).sum())}


def merge_stats(a, b):
    if a is None:
        return b
    out = {"n": a["n"] + b["n"]}
    for k in ("max_g", "max_u", "max_p"):
        out[k] = max(a[k], b[k])
    for k in ("wraps", "high_over_headroom"):
        out[k] = a[k] + b[k]
    for k in ("p999_g", "p9999_g"):
        out[k] = max(a[k], b[k])      # per-chunk percentile upper envelope
    out["rms_g"] = float(np.sqrt((a["rms_g"] ** 2 * a["n"] + b["rms_g"] ** 2 * b["n"]) / out["n"]))
    return out


def scan_matrix(w, q, c, group, headroom, radix, pair_rows, chunk=4096):
    """Exact integer channel sums over each deferred run of `group` columns.

    `pair_rows` picks the row pairing: (lo_rows, hi_rows) index arrays, gate/up or d/d+D/2.
    """
    lo, hi = pair_rows
    kdim = w.shape[1]
    stats = None
    for g in range(kdim // group):
        sl = slice(g * group, (g + 1) * group)
        qs = q[:, sl].astype(np.float32)
        for r0 in range(0, len(lo), chunk):
            rows_lo = lo[r0:r0 + chunk]
            rows_hi = hi[r0:r0 + chunk]
            acc_g = qs @ w[rows_lo][:, sl].astype(np.float32).T
            acc_u = qs @ w[rows_hi][:, sl].astype(np.float32).T
            stats = merge_stats(stats, carrier_stats(acc_g, acc_u, headroom, radix))
    if c is not None:
        pass
    return stats


def cmd_carrier(args):
    rows = args.rows
    layer = args.layer
    x, _ = load_rows(layer, rows)
    signs_ff = np.fromfile(f"{DATA}/{layer}/signs_ff.f32", dtype=np.float32)
    wg, sg = halo_matrix(f"{DATA}/{layer}/gate.halo", FF, D)
    wu, su = halo_matrix(f"{DATA}/{layer}/up.halo", FF, D)
    wd, sd = halo_matrix(f"{DATA}/{layer}/down.halo", D, FF)
    u = ffn_input(x, layer)

    # hidden activation, computed once with the per-128 control semantics
    qb, cb = quantise(u, BLOCK, 7.0)
    gate = blockwise_project(wg, sg, qb, cb, BLOCK)
    up = blockwise_project(wu, su, qb, cb, BLOCK)
    hid = (gate / (1.0 + np.exp(-gate))) * up * signs_ff[None, :]
    h = hadamard_1024(hid)

    report = {"layer": layer, "rows": rows, "radix": 2047, "headroom": 1023,
              "levels": 7, "clip": args.clip,
              "note": "exact integer channel sums; headroom is R/2 for M=1"}
    gate_rows = (np.arange(FF), np.arange(FF))
    down_rows = (np.arange(D // 2), np.arange(D // 2) + D // 2)
    for stage, act, mats in (("gate_up", u, (("gate", wg, gate_rows[0]), ("up", wu, gate_rows[1]))),
                             ("down", h, (("down", wd, None),))):
        kdim = act.shape[1]
        ent = {}
        for G in args.groups:
            group = G * BLOCK
            if kdim % group:
                continue
            q, c = quantise(act, group, 7.0, args.clip)
            l1 = np.abs(q.astype(np.int32)).reshape(rows, kdim // group, group).sum(axis=2)
            e = {"group": group,
                 "cert_l1_max": int(l1.max()), "cert_l1_mean": float(l1.mean()),
                 "cert_l1_certified_fraction": float((l1 <= 1023).mean())}
            if stage == "gate_up":
                s = scan_matrix(np.concatenate([wg, wu]), q, c, group, 1023, 2047,
                                (np.arange(FF), np.arange(FF) + FF), chunk=args.chunk)
            else:
                s = scan_matrix(wd, q, c, group, 1023, 2047, down_rows, chunk=args.chunk)
            e.update(s)
            e["wrap_fraction"] = e["wraps"] / e["n"]
            ent[f"G{G}"] = e
            print(stage, f"G{G}", json.dumps(e), flush=True)
        report[stage] = ent
    if args.json:
        json.dump(report, open(args.json, "w"), indent=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["check", "weights", "carrier"])
    ap.add_argument("--layer", default="layer00")
    ap.add_argument("--rows", type=int, default=256)
    ap.add_argument("--clip", type=float, default=1.0)
    ap.add_argument("--chunk", type=int, default=4096)
    ap.add_argument("--groups", type=lambda s: [int(v) for v in s.split(",")],
                    default=[1, 2, 4, 8])
    ap.add_argument("--json")
    a = ap.parse_args()
    {"check": cmd_check, "weights": cmd_weights, "carrier": cmd_carrier}[a.cmd](a)


if __name__ == "__main__":
    main()
