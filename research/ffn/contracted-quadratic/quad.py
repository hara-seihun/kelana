"""The even (quadratic) part of Bonsai's ternary FFN, after the hidden dimension is contracted out.

Ideal real arithmetic up to but excluding the hidden quantiser:

    h_i(x) = silu(G_i . x) * (U_i . x)          (per hidden unit i, in the rotated input basis)
    h_i(x) + h_i(-x) = (G_i . x) * (U_i . x)    since silu(a) - silu(-a) = a

so twice the even part of one output direction c on the hidden vector is

    e_c(x) = sum_i c_i (G_i . x)(U_i . x) = x^T Q_c x,   Q_c = sym(G^T diag(c) U)

`G` and `U` are the real PTQ1_0 operators: ternary trits times their per-(row,128) fp16 block
scales, as decoded from the HALO tiles. `c` is a real output direction pulled back through the
fixed hidden transform in the deployed order. The engine computes, per token,

    hid = silu(gate) * up
    h   = (1/32) H_1024 diag(signs_ff) hid
    y_r = sum_b lam_d[r,b] c_b (t_d[r] . quant(h))_b

Dropping only the hidden quantiser, y_r = Dr . (1/32) H diag(s) hid with Dr the scaled ternary
down row, and H symmetric, so the coefficient vector on `hid` is

    c = signs_ff * ((1/32) H_1024 Dr)

which is what `down_direction` returns. The input quantiser is dropped as well; that is the
"ideal real arithmetic before the hidden quantizer" domain, not the deployed integer one.

Subcommands:
  build     form Q_c for one output direction and cache it (npy) with its norms
  spec      eigendecomposition of a cached Q_c, energy retained by rank, real-activation error
  shared    how much of several directions' quadratic energy a single shared input basis carries
  cost      arithmetic/storage accounting for the rank-k forms against the deployed FFN
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "batched", "deferred-carrier"))
from carrier_scan import D, FF, halo_matrix, hadamard_1024, load_rows, ffn_input  # noqa: E402

DATA = "/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench"
BLOCK = 128
RANKS = (1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 5120)


def scaled(path, rows, kdim, dtype):
    """Real operator of a HALO matrix: trits * per-(row, 128) fp16 scale."""
    w, s = halo_matrix(path, rows, kdim)
    m = w.astype(dtype)
    m *= np.repeat(s.astype(dtype), BLOCK, axis=1)
    return m


def down_direction(layer, row, rng=None):
    """Coefficient vector on `hid` for one down row (or a random output direction)."""
    wd, sd = halo_matrix(f"{DATA}/{layer}/down.halo", D, FF)
    signs = np.fromfile(f"{DATA}/{layer}/signs_ff.f32", dtype=np.float32)
    if rng is None:
        dr = wd[row].astype(np.float64) * np.repeat(sd[row].astype(np.float64), BLOCK)
    else:
        g = rng.standard_normal(D)
        g /= np.linalg.norm(g)
        dr = (g[:, None] * wd.astype(np.float64) * np.repeat(sd.astype(np.float64), BLOCK, axis=1)).sum(0)
    return (signs * hadamard_1024(dr.astype(np.float32)).astype(np.float64)).astype(np.float64)


def cmd_build(a):
    dt = np.float64 if a.dtype == "f64" else np.float32
    c = down_direction(a.layer, a.row, np.random.default_rng(a.seed) if a.random else None).astype(dt)
    g = scaled(f"{DATA}/{a.layer}/gate.halo", FF, D, dt)
    u = scaled(f"{DATA}/{a.layer}/up.halo", FF, D, dt)
    if a.control == "gauss":
        # iid control with the same shape and the same per-row L2: isolates whatever the real
        # trit pattern and block scales contribute beyond dimensions
        rng = np.random.default_rng(a.seed + 99)
        for m in (g, u):
            n = np.linalg.norm(m, axis=1, keepdims=True)
            m[:] = rng.standard_normal(m.shape).astype(dt)
            m *= n / np.linalg.norm(m, axis=1, keepdims=True)
    elif a.control == "shuffle":
        # same weight values, gate/up column correspondence destroyed
        rng = np.random.default_rng(a.seed + 7)
        g[:] = g[:, rng.permutation(D)]
    g *= c[:, None]
    m = g.T @ u
    del g, u
    q = m
    q += m.T.copy()
    q *= 0.5
    np.save(a.out, q)
    rep = {"layer": a.layer, "row": a.row, "random": bool(a.random), "dtype": a.dtype,
           "c_l2": float(np.linalg.norm(c)), "c_linf": float(np.abs(c).max()),
           "fro": float(np.linalg.norm(q)), "trace": float(np.trace(q)),
           "asym_fro_ratio": None, "out": a.out}
    print(json.dumps(rep))


def energy_table(ev):
    """Frobenius energy retained by the best rank-k symmetric approximation (top |lambda|)."""
    o = np.sort(np.abs(ev))[::-1] ** 2
    tot = o.sum()
    cum = np.cumsum(o)
    return {str(k): float(cum[min(k, len(o)) - 1] / tot) for k in RANKS if k <= len(o)}


def cmd_spec(a):
    q = np.load(a.q)
    n = q.shape[0]
    ev, vec = np.linalg.eigh(q)
    order = np.argsort(np.abs(ev))[::-1]
    ev, vec = ev[order], vec[:, order]
    np.save(a.q.replace(".npy", ".ev.npy"), ev)
    np.save(a.q.replace(".npy", ".vec.npy"), vec[:, :a.keep].astype(np.float32))
    rep = {"q": a.q, "n": n, "fro": float(np.linalg.norm(q)),
           "eig_absmax": float(np.abs(ev).max()),
           "eig_top16": [float(x) for x in ev[:16]],
           "pos": int((ev > 0).sum()), "neg": int((ev < 0).sum()),
           "frobenius_energy_by_rank": energy_table(ev),
           "participation_ratio": float((ev ** 2).sum() ** 2 / (ev ** 4).sum())}
    # error on the real activation domain: 256 captured tokens, ideal real arithmetic
    x, _ = load_rows(a.layer, 256)
    xr = ffn_input(x, a.layer).astype(np.float64)
    proj = xr @ vec
    true = np.einsum("ti,ij,tj->t", xr, q, xr)
    rep["activation"] = {"n_tokens": int(xr.shape[0]), "rms_true": float(np.sqrt((true ** 2).mean()))}
    for k in RANKS:
        if k > n:
            continue
        approx = (proj[:, :k] ** 2) @ ev[:k]
        rep["activation"][str(k)] = float(np.sqrt(((approx - true) ** 2).mean()) /
                                          np.sqrt((true ** 2).mean()))
    # covariance-weighted (whitened) spectrum: what matters if inputs were Gaussian with this cov
    cov = (xr.T @ xr) / xr.shape[0]
    w, v = np.linalg.eigh(cov)
    w = np.clip(w, 0, None)
    root = (v * np.sqrt(w)) @ v.T
    qw = root @ q @ root
    evw = np.linalg.eigvalsh(qw)
    rep["whitened"] = {"rank_cov": int((w > w.max() * 1e-10).sum()),
                       "frobenius_energy_by_rank": energy_table(evw)}
    print(json.dumps(rep))
    if a.json:
        json.dump(rep, open(a.json, "w"), indent=1)


def cmd_check(a):
    """x^T Q_c x against the ideal-arithmetic FFN row, symmetrised over x -> -x."""
    dt = np.float64
    c = down_direction(a.layer, a.row).astype(dt)
    g = scaled(f"{DATA}/{a.layer}/gate.halo", FF, D, dt)
    u = scaled(f"{DATA}/{a.layer}/up.halo", FF, D, dt)
    q = np.load(a.q)
    x, _ = load_rows(a.layer, 8)
    xr = ffn_input(x, a.layer).astype(dt)[:a.tokens]
    ga, ua = xr @ g.T, xr @ u.T
    direct = (ga * ua) @ c                                   # sum_i c_i (G_i x)(U_i x)
    form = np.einsum("ti,ij,tj->t", xr, q, xr)
    sil = lambda t: t / (1.0 + np.exp(-t))
    pipe = (sil(ga) * ua) @ c + (sil(-ga) * (-ua)) @ c        # y_r(x) + y_r(-x), no quantisers
    print(json.dumps({
        "tokens": int(xr.shape[0]), "row": a.row,
        "rms_even": float(np.sqrt((direct ** 2).mean())),
        "rel_form_vs_direct": float(np.abs(form - direct).max() / np.abs(direct).max()),
        "rel_pipeline_vs_direct": float(np.abs(pipe - direct).max() / np.abs(direct).max()),
        "rms_full_row": float(np.sqrt((((sil(ga) * ua) @ c) ** 2).mean()))}))


def cmd_shared(a):
    """One input basis for many output directions: energy of Q_c kept inside a shared subspace.

    The shared basis is the leading eigenspace of sum_c Q_c^2 / ||Q_c||_F^2, i.e. the directions
    that carry the most quadratic-form energy averaged over the sampled output directions. For a
    basis B, B^T Q B is the form a rank-m shared projection can still express, so ||B^T Q B||_F^2 /
    ||Q||_F^2 is the retained Frobenius energy for this fixed basis. It is not an upper
    bound over other choices of a shared basis.
    """
    qs = [(p.split("/")[-1].replace(".npy", ""), np.load(p)) for p in a.q]
    s = np.zeros((D, D), dtype=np.float64)
    for _, q in qs:
        q64 = q.astype(np.float64)
        s += (q64 @ q64) / np.linalg.norm(q64) ** 2
    v = np.linalg.eigh(s)[1][:, ::-1]
    rep = {"layer": a.layer, "dirs": [n for n, _ in qs], "shared_energy_by_rank": {}}
    for k in RANKS:
        if k > a.maxrank:
            continue
        b = v[:, :k]
        rep["shared_energy_by_rank"][str(k)] = [
            float(np.linalg.norm(b.T @ q.astype(np.float64) @ b) ** 2 / np.linalg.norm(q.astype(np.float64)) ** 2)
            for _, q in qs]
    print(json.dumps(rep))
    if a.json:
        json.dump(rep, open(a.json, "w"), indent=1)


def cmd_part(a):
    """How much of the layer's FFN output the even component carries, on the captured tokens."""
    dt = np.float32
    g = scaled(f"{DATA}/{a.layer}/gate.halo", FF, D, dt)
    u = scaled(f"{DATA}/{a.layer}/up.halo", FF, D, dt)
    wd, sd = halo_matrix(f"{DATA}/{a.layer}/down.halo", D, FF)
    dmat = wd.astype(dt) * np.repeat(sd.astype(dt), BLOCK, axis=1)
    signs = np.fromfile(f"{DATA}/{a.layer}/signs_ff.f32", dtype=np.float32)
    x, _ = load_rows(a.layer, a.tokens)
    xr = ffn_input(x, a.layer).astype(dt)
    ga, ua = xr @ g.T, xr @ u.T
    sil = lambda t: t / (1.0 + np.exp(-t))
    hid = sil(ga) * ua
    hid_m = sil(-ga) * (-ua)
    down = lambda h: hadamard_1024((h * signs[None, :]).astype(np.float32)) @ dmat.T
    y, ym = down(hid), down(hid_m)
    ev, od = 0.5 * (y + ym), 0.5 * (y - ym)
    print(json.dumps({"tokens": int(xr.shape[0]),
                      "rms_y": float(np.sqrt((y ** 2).mean())),
                      "rms_even": float(np.sqrt((ev ** 2).mean())),
                      "rms_odd": float(np.sqrt((od ** 2).mean())),
                      "even_share_of_energy": float((ev ** 2).sum() / (y ** 2).sum())}))


def cmd_cost(a):
    """MAC and storage accounting per token for the whole layer (all D outputs), ideal arithmetic."""
    deployed_mac = 3 * D * FF
    specs = {n: json.load(open(f"{a.dir}/spec_{n}.json")) for n in a.names.split(",")}
    ref = specs[a.names.split(",")[0]]

    def need(curve, target, key=lambda v: v):
        ks = sorted(int(k) for k in curve)
        for i, k in enumerate(ks):
            if key(curve[str(k)]) >= target:
                if i == 0:
                    return k
                p, pv = ks[i - 1], key(curve[str(ks[i - 1])])
                cv = key(curve[str(k)])
                return int(round(p + (k - p) * (target - pv) / (cv - pv)))
        return None

    rep = {"D": D, "FF": FF,
           "deployed_mac_per_token": deployed_mac,
           "deployed_mac_per_output": 3 * FF,
           "breakeven_rank_independent": 3 * FF / D,
           "breakeven_shared_basis": None,
           "ranks": {}}
    m = 1
    while m * D + D * m * (m + 1) // 2 <= deployed_mac:
        m += 1
    rep["breakeven_shared_basis"] = m - 1
    for n, s in specs.items():
        rep["ranks"][n] = {
            "rank_for_90pct_frobenius": need(s["frobenius_energy_by_rank"], 0.90),
            "rank_for_99pct_frobenius": need(s["frobenius_energy_by_rank"], 0.99),
            "rank_for_10pct_activation_err": need(
                {k: v for k, v in s["activation"].items() if k.isdigit()}, 0.90, key=lambda v: 1 - v),
            "rank_for_1pct_activation_err": need(
                {k: v for k, v in s["activation"].items() if k.isdigit()}, 0.99, key=lambda v: 1 - v)}
    shared = json.load(open(f"{a.dir}/shared.json"))["shared_energy_by_rank"] if a.shared else {}
    rows = []
    for r in (8, 16, 32, 64, 128, 256, 512, 1024, 2048):
        ind = r * (D + 1) * D
        rows.append({"rank": r,
                     "independent_mac": ind,
                     "independent_vs_deployed": ind / deployed_mac,
                     "shared_mac": r * D + D * r * (r + 1) // 2,
                     "shared_vs_deployed": (r * D + D * r * (r + 1) // 2) / deployed_mac,
                     "own_frobenius_energy_row0": ref["frobenius_energy_by_rank"].get(str(r)),
                     "shared_frobenius_energy_mean": (
                         float(np.mean(shared[str(r)])) if str(r) in shared else None),
                     "activation_relerr_row0": ref["activation"].get(str(r))})
    rep["table"] = rows
    rep["deployed_params_trits"] = 3 * D * FF
    rep["deployed_bytes_halo"] = 3 * 19496960
    print(json.dumps(rep, indent=1))
    if a.json:
        json.dump(rep, open(a.json, "w"), indent=1)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", default="layer00")
    sub = p.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build")
    b.add_argument("--row", type=int, default=0)
    b.add_argument("--random", action="store_true")
    b.add_argument("--seed", type=int, default=0)
    b.add_argument("--dtype", default="f64", choices=("f32", "f64"))
    b.add_argument("--control", default="none", choices=("none", "gauss", "shuffle"))
    b.add_argument("--out", required=True)
    b.set_defaults(fn=cmd_build)
    s = sub.add_parser("spec")
    s.add_argument("--q", required=True)
    s.add_argument("--keep", type=int, default=512)
    s.add_argument("--json")
    s.set_defaults(fn=cmd_spec)
    pt = sub.add_parser("part")
    pt.add_argument("--tokens", type=int, default=256)
    pt.set_defaults(fn=cmd_part)
    k = sub.add_parser("check")
    k.add_argument("--row", type=int, default=0)
    k.add_argument("--q", required=True)
    k.add_argument("--tokens", type=int, default=8)
    k.set_defaults(fn=cmd_check)
    h = sub.add_parser("shared")
    h.add_argument("--q", nargs="+", required=True)
    h.add_argument("--maxrank", type=int, default=1024)
    c = sub.add_parser("cost")
    c.add_argument("--dir", default="/path/to/workspace/work/scratch/cq")
    c.add_argument("--names", default="row0,row137,row2048,rand7")
    c.add_argument("--shared", action="store_true")
    c.add_argument("--json")
    c.set_defaults(fn=cmd_cost)
    h.add_argument("--json")
    h.set_defaults(fn=cmd_shared)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
