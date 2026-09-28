"""Measure what happens when the fixed sign/Hadamard input maps are absorbed
into Bonsai's ternary FFN-down weights.

Read-only on /path/to/workspace/data/bonsai2/PTQ1_0.gguf. Works on a bounded set of
real 1024-wide Hadamard blocks, not the full 89M-value matrix.

Deployed down-projection (kernels/phases.hpp prep_chunk_r + mvw_rows):

    h   in R^FF                       (silu(gate) * up)
    u   = (1/32) H_1024 . diag(s) h   blockwise over 17 chunks of 1024
    q_j = round(u_j / c_b),  c_b = amax(u over 128-block b)/127
    y_i = sum_b  lam[i,b] * c_b * sum_{j in b} t[i,j] q_j

Absorption asks for M = (Lam (.) T_trit) . (1/32) H . diag(s) as stored weights.

Usage:  python3 absorb_stats.py [--layer 10] [--rows 512] [--blocks 4]
"""

import argparse
import json
import numpy as np

from gguf_read import Gguf, hadamard, sign_vectors

GGUF = "/path/to/workspace/data/bonsai2/PTQ1_0.gguf"
D, FF, HAD, GRP = 5120, 17408, 1024, 128


def entropy_bits(v):
    _, c = np.unique(v, return_counts=True)
    p = c / c.sum()
    return float(-(p * np.log2(p)).sum())


def describe(name, v):
    v = np.asarray(v)
    return dict(name=name, n=int(v.size), min=int(v.min()), max=int(v.max()),
                absmax=int(np.abs(v).max()), sd=float(v.std()),
                distinct=int(np.unique(v).size), zero_frac=float((v == 0).mean()),
                entropy_bits=entropy_bits(v.ravel()),
                bits_needed=int(np.ceil(np.log2(2 * np.abs(v).max() + 1))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--layer", type=int, default=10)
    ap.add_argument("--rows", type=int, default=512)
    ap.add_argument("--blocks", type=int, default=4, help="1024-wide column blocks")
    ap.add_argument("--col0", type=int, default=0)
    ap.add_argument("--json", default="absorb_stats.json")
    ap.add_argument("--exponent-survey", action="store_true",
                    help="check single-exponent-per-1024-block across several layers")
    a = ap.parse_args()

    g = Gguf(GGUF)
    signs = sign_vectors(g)[FF]

    if a.exponent_survey:
        out = []
        for layer in (0, 10, 31, 47):
            for col0 in (0, 8192, 16384):
                t, s = g.rows_ptq1_0(f"blk.{layer}.ffn_down.weight", 0, 128, col0, HAD)
                ex = np.frexp(s.reshape(128, 1, 8))[1]
                out.append(dict(layer=layer, col0=col0,
                                frac_single_exponent=float((ex.max(2) == ex.min(2)).mean()),
                                ratio_max=float((s.max(1) / s.min(1)).max())))
        print(json.dumps(out, indent=1))
        return
    name = f"blk.{a.layer}.ffn_down.weight"
    ncols = a.blocks * HAD
    trit, scale = g.rows_ptq1_0(name, 0, a.rows, a.col0, ncols)
    R = dict(tensor=name, rows=a.rows, col0=a.col0, ncols=ncols)

    H128 = hadamard(128).astype(np.int32)
    H1024 = hadamard(1024).astype(np.int32)

    # ---- 0. raw ternary facts ------------------------------------------------
    nnz = (trit != 0).reshape(a.rows, -1, GRP).sum(2)          # per 128-group
    R["trit"] = dict(nnz_frac=float((trit != 0).mean()),
                     nnz_per128_mean=float(nnz.mean()),
                     nnz_per128_min=int(nnz.min()), nnz_per128_max=int(nnz.max()),
                     plus_frac=float((trit > 0).mean()), minus_frac=float((trit < 0).mean()),
                     nnz_hist={int(v): int(c) for v, c in zip(*np.unique(nnz, return_counts=True))},
                     nnz_even_frac=float((nnz % 2 == 0).mean()))

    # ---- 1. per-128 weight scales inside one 1024 Hadamard block -------------
    sc = scale.reshape(a.rows, a.blocks, 8)                     # lam[i, block, group]
    smax, smin, smean = sc.max(2), sc.min(2), sc.mean(2)
    ratio = smax / smin
    rel_sd = sc.std(2) / smean
    ex = np.frexp(sc)[1]                                        # fp16 binary exponent
    R["scale"] = dict(
        mean=float(sc.mean()), ratio_mean=float(ratio.mean()), ratio_p99=float(np.percentile(ratio, 99)),
        ratio_max=float(ratio.max()), rel_sd_mean=float(rel_sd.mean()), rel_sd_max=float(rel_sd.max()),
        exponent_spread_max=int((ex.max(2) - ex.min(2)).max()),
        frac_blocks_single_exponent=float((ex.max(2) == ex.min(2)).mean()),
        # collapsing the 8 group scales to one per 1024: relative weight perturbation
        collapse_rel_l2=float(np.sqrt((((sc - smean[:, :, None]) ** 2 * nnz.reshape(a.rows, a.blocks, 8)).sum()) /
                                      ((sc ** 2 * nnz.reshape(a.rows, a.blocks, 8)).sum()))),
    )

    # ---- 1b. the opposite move: re-encode the per-128 scales instead --------
    # The 8 scales in a 1024 block share an exponent and differ by <1.6x, so they
    # fit a shared fp16 maximum plus a short per-group code. Error is measured as a
    # weight perturbation weighted by the nonzeros each scale covers.
    nnz3 = nnz.reshape(a.rows, a.blocks, 8).astype(np.float64)
    sc64 = sc.astype(np.float64)

    def scale_err(approx):
        return float(np.sqrt(((approx - sc64) ** 2 * nnz3).sum() / ((sc64 ** 2 * nnz3).sum())))

    smax_b = sc64.max(2, keepdims=True)
    R["scale_recompression"] = []
    for bits in (2, 3, 4, 5):
        lo, n_lv = 0.5, 2 ** bits
        grid = lo + (1.0 - lo) * np.arange(n_lv) / (n_lv - 1)       # ratio grid in [0.5, 1]
        r = sc64 / smax_b
        code = np.abs(r[..., None] - grid).argmin(-1)
        approx = smax_b * grid[code]
        bytes_per_block = (bits * 8 + 16) / 8 / 8                   # per 128-group
        R["scale_recompression"].append(dict(
            code_bits=bits, rel_l2_weight_err=scale_err(approx),
            scale_bytes_per_128=bytes_per_block,
            block_bytes=26 + bytes_per_block,
            tensor_bytes_x=(26 + bytes_per_block) / 28))

    # ---- 2. transformed integer coefficients, scales factored out ------------
    t3 = trit.reshape(a.rows, a.blocks, 8, GRP).astype(np.int32)
    V128 = t3 @ H128                                            # inner transform only
    t1024 = trit.reshape(a.rows, a.blocks, HAD).astype(np.int32)
    V1024 = t1024 @ H1024                                       # full transform
    R["V128"] = describe("t . H_128 (per scale group)", V128)
    R["V1024"] = describe("t . H_1024 (whole block)", V1024)

    # parity lemma: every transformed coefficient shares the parity of nnz(t)
    R["parity_lemma_holds"] = dict(
        V128=bool(np.all((V128 & 1) == (nnz.reshape(a.rows, a.blocks, 8, 1) & 1))),
        V1024=bool(np.all((V1024 & 1) == (nnz.reshape(a.rows, a.blocks, 8).sum(2)[:, :, None] & 1))))

    # lattice membership: V in H Z^n  <=>  H V = n t
    R["lattice_check"] = bool(np.array_equal((V1024 @ H1024) // HAD, t1024) and
                              np.array_equal((V1024 @ H1024) % HAD, np.zeros_like(t1024)))

    # H_1024 = H_8 (x) H_128 under (group, offset): V1024[a,b] = sum_g H8[a,g] V128[g,b]
    H8 = hadamard(8).astype(np.int32)
    V1024g = V1024.reshape(a.rows, a.blocks, 8, GRP)
    R["kron_split_exact"] = bool(np.array_equal(np.einsum("ag,rbgc->rbac", H8, V128), V1024g))

    # sign vector: diag(s) sits on the far side of H from the weights, so moving it
    # onto the weights means conjugating: H diag(s) H^-1, which is dense.
    s_blk = signs[a.col0:a.col0 + HAD].astype(np.float64)
    conj = (H1024 * s_blk[None, :]) @ H1024 / HAD
    R["sign_conjugate"] = dict(density=float((np.abs(conj) > 1e-12).mean()),
                               is_diagonal=bool(np.allclose(conj, np.diag(np.diag(conj)))))

    # ---- 3. real absorbed matrix, scales included ---------------------------
    # M[i, block, a, c] = (1/32) sum_g H8[a,g] lam[i,b,g] V128[i,b,g,c]
    M = np.einsum("ag,rbg,rbgc->rbac", H8.astype(np.float64), sc.astype(np.float64),
                  V128.astype(np.float64)) / 32.0
    # is there useful sparsity? energy kept by the largest-magnitude fraction
    e_sorted = np.sort((M ** 2).ravel())[::-1]
    cum = np.cumsum(e_sorted) / e_sorted.sum()
    R["M_real"] = dict(absmax=float(np.abs(M).max()), sd=float(M.std()),
                       distinct_frac=float(np.unique(M).size / M.size),
                       zero_frac=float((M == 0).mean()),
                       energy_in_top={f"{f:.2f}": float(cum[int(f * cum.size) - 1])
                                      for f in (0.05, 0.10, 0.25, 0.50)},
                       trit_energy_in_top_nnz=float(1.0))

    # If the 8 group scales are collapsed to their mean, M becomes lam_bar * integer.
    Mbar = smean[:, :, None, None] * V1024.reshape(a.rows, a.blocks, 8, GRP).astype(np.float64) / 32.0
    err = np.linalg.norm(M - Mbar) / np.linalg.norm(M)
    R["collapse_to_one_scale_rel_l2"] = float(err)

    # how far the exact absorbed matrix is from ANY integer multiple of the row scale:
    # round M/(lam_bar/32) and measure residual -> is there a finite integer alphabet?
    # ---- 3b. EXACT dyadic absorption ---------------------------------------
    # Every fp16 scale in a 1024 block shares one binary exponent (measured above),
    # so lam[i,b,g] = m[i,b,g] * 2^(e[i,b]-10) with m an 11-bit integer, and
    #   32 * M[i,b,a,c] / 2^(e-10) = sum_g H8[a,g] m[i,b,g] V128[i,b,g,c]  exactly in Z.
    mant, expo = np.frexp(sc.astype(np.float64))
    e0 = expo.min(2)
    m_int = np.round(sc.astype(np.float64) / 2.0 ** (e0[:, :, None] - 11)).astype(np.int64)
    exact_ok = bool(np.all(m_int.astype(np.float64) * 2.0 ** (e0[:, :, None] - 11) == sc.astype(np.float64)))
    Zex = np.einsum("ag,rbg,rbgc->rbac", H8.astype(np.int64), m_int, V128.astype(np.int64))
    R["exact_dyadic"] = dict(
        all_scales_are_11bit_integers_times_2pow=exact_ok,
        mantissa_min=int(m_int.min()), mantissa_max=int(m_int.max()),
        int_absmax=int(np.abs(Zex).max()),
        int_bits=int(np.ceil(np.log2(2 * np.abs(Zex).max() + 1))),
        int_entropy_bits=entropy_bits(Zex.ravel()),
        gcd_of_all=int(np.gcd.reduce(np.abs(Zex).ravel())),
        reconstruct_exact=bool(np.array_equal(
            Zex.astype(np.float64) * 2.0 ** (e0[:, :, None, None] - 11) / 32.0, M)))

    # ---- 3c. B-bit absorbed weights, one fp16 scale per (row, 1024 block) ---
    R["bbit_absorbed"] = []
    amax_rb = np.abs(M).max((2, 3))
    for B in (6, 7, 8, 9, 10, 12):
        step = (amax_rb / (2 ** (B - 1) - 1))[:, :, None, None]
        Zb = np.clip(np.round(M / step), -(2 ** (B - 1) - 1), 2 ** (B - 1) - 1)
        R["bbit_absorbed"].append(dict(
            bits=B, rel_l2=float(np.linalg.norm(M - Zb * step) / np.linalg.norm(M)),
            bits_per_weight=B + 16.0 / HAD,
            storage_x_vs_deployed=(B + 16.0 / HAD) / 1.75))

    R["round_to_row_lattice"] = []
    for k in (1, 2, 4, 8):
        step = smean[:, :, None, None] / (32.0 * k)
        Z = np.round(M / step)
        R["round_to_row_lattice"].append(dict(
            lattice_step=f"lam_bar/(32*{k})",
            rel_l2=float(np.linalg.norm(M - Z * step) / np.linalg.norm(M)),
            absmax_int=int(np.abs(Z).max()),
            bits=int(np.ceil(np.log2(2 * np.abs(Z).max() + 1))),
            entropy_bits=entropy_bits(Z.ravel())))

    # ---- 3d. stage sweep: absorb k of the 10 butterfly stages ---------------
    # Absorbing k stages replaces each weight by a signed sum of 2^k trits.
    # Arithmetic saved per stage: 1 add per input element, amortised over D output rows.
    R["stage_sweep"] = []
    P = trit.reshape(a.rows, a.blocks, HAD).astype(np.int32).copy()
    for k in range(11):
        R["stage_sweep"].append(dict(
            stages_absorbed=k, alphabet_size=int(np.unique(P).size),
            absmax=int(np.abs(P).max()), sd=float(P.std()),
            entropy_bits=entropy_bits(P.ravel()),
            zero_frac=float((P == 0).mean()),
            extra_weight_MB_vs_trit=(entropy_bits(P.ravel()) - entropy_bits(trit.ravel())) * D * FF / 8 / 2**20,
            adds_saved_per_token=k * (FF // HAD) * HAD))
        if k < 10:
            bit = 1 << k
            Q = P.reshape(a.rows, a.blocks, HAD // (2 * bit), 2, bit)
            lo, hi = Q[:, :, :, 0, :], Q[:, :, :, 1, :]
            P = np.stack([lo + hi, lo - hi], axis=3).reshape(a.rows, a.blocks, HAD)

    # information content: a 1024-block of trits carries at most 1024*log2(3) bits,
    # whatever the transformed values cost to store.
    R["information"] = dict(
        trit_content_bits_per_weight=float(np.log2(3)),
        ternary_empirical_bits=entropy_bits(trit.ravel()),
        V1024_order0_bits=entropy_bits(V1024.ravel()),
        V128_order0_bits=entropy_bits(V128.ravel()))

    # ---- 4. storage / arithmetic accounting for the whole down matrix -------
    n_w = D * FF
    ptq_bytes = (FF // GRP) * 28 * D
    plans = {
        "deployed ternary PTQ1_0 + shared H_1024": dict(
            weight_bytes=ptq_bytes, bits_per_weight=ptq_bytes * 8 / n_w,
            per_token_adds=(FF // HAD) * HAD * 10, per_token_macs=n_w),
        "absorb H_128 only (int8 weights, H_8 + sign stay shared)": dict(
            weight_bytes=n_w + (FF // GRP) * D * 2, bits_per_weight=(n_w + (FF // GRP) * D * 2) * 8 / n_w,
            per_token_adds=(FF // HAD) * HAD * 3, per_token_macs=n_w),
        "absorb full H_1024 (int8 weights, one scale per row-block)": dict(
            weight_bytes=n_w + (FF // HAD) * D * 2, bits_per_weight=(n_w + (FF // HAD) * D * 2) * 8 / n_w,
            per_token_adds=0, per_token_macs=n_w),
        "absorb full H_1024 (int16, no clipping)": dict(
            weight_bytes=2 * n_w + (FF // HAD) * D * 2, bits_per_weight=(2 * n_w + (FF // HAD) * D * 2) * 8 / n_w,
            per_token_adds=0, per_token_macs=n_w),
    }
    base = plans["deployed ternary PTQ1_0 + shared H_1024"]
    for p in plans.values():
        p["weight_MB"] = p["weight_bytes"] / 2**20
        p["storage_x_vs_deployed"] = p["weight_bytes"] / base["weight_bytes"]
        p["adds_saved_frac_of_macs"] = (base["per_token_adds"] - p["per_token_adds"]) / base["per_token_macs"]
    R["plans"] = plans

    # int8 feasibility of the absorbed alphabets
    R["int8_fit"] = dict(V128_absmax=int(np.abs(V128).max()), V1024_absmax=int(np.abs(V1024).max()),
                         V128_fits_i8=bool(np.abs(V128).max() <= 127),
                         V1024_fits_i8=bool(np.abs(V1024).max() <= 127),
                         V1024_clip_frac_at_127=float((np.abs(V1024) > 127).mean()))

    print(json.dumps(R, indent=1, default=str))
    with open(a.json, "w") as f:
        json.dump(R, f, indent=1, default=str)


if __name__ == "__main__":
    main()
