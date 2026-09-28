"""Small ternary examples behind the absorption analysis, plus the quantisation wall.

1. Brute-force lemmas about the image of {-1,0,1}^n under a Walsh-Hadamard map.
2. The alphabet after absorbing k of the log2(n) butterfly stages.
3. Why the absorbed map is not the deployed function: the int8 quantiser sits
   between the transform and the weights, and it is not linear.

Everything here is self-contained (no model data).
"""

import itertools
import json
import numpy as np

from gguf_read import hadamard


def brute_force_lemmas(n=8):
    H = hadamard(n)
    T = np.array(list(itertools.product((-1, 0, 1), repeat=n)), dtype=np.int64)
    V = T @ H
    nnz = (T != 0).sum(1)
    out = dict(n=n, num_ternary=len(T))
    # L1 parity: every transformed coefficient has the parity of nnz(t)
    out["L1_parity"] = bool(np.all((V & 1) == (nnz & 1)[:, None]))
    # L2 all-even iff nnz even (a free bit when the quantiser fixes block sparsity)
    out["L2_even_iff_nnz_even"] = bool(np.all((np.abs(V) % 2 == 0).all(1) == (nnz % 2 == 0)))
    # L3 injective, and membership test V in image <=> HV = n t with t ternary
    out["L3_injective"] = bool(len(np.unique(V, axis=0)) == len(T))
    back = V @ H
    out["L3_membership"] = bool(np.all(back % n == 0) and np.all(np.abs(back // n) <= 1))
    # L4 column differences are always even, magnitude <= n/2 (Hadamard columns
    # differ in exactly n/2 positions)
    d = V[:, :, None] - V[:, None, :]
    off = ~np.eye(n, dtype=bool)
    out["L4_diff_even"] = bool(np.all(d[:, off] % 2 == 0))
    out["L4_diff_absmax"] = int(np.abs(d[:, off] // 2).max())
    # alphabet growth: coefficient range and order-0 entropy of the image
    vals, cnt = np.unique(V, return_counts=True)
    p = cnt / cnt.sum()
    out["image_alphabet"] = dict(size=int(vals.size), absmax=int(np.abs(vals).max()),
                                 entropy_bits=float(-(p * np.log2(p)).sum()))
    return out


def stage_alphabet(kmax=10, trials=200000, seed=0, p_zero=1 / 3):
    """Absorbing k butterfly stages replaces each weight by a signed sum of 2^k trits."""
    rng = np.random.default_rng(seed)
    out = []
    for k in range(kmax + 1):
        m = 1 << k
        t = rng.choice([-1, 0, 1], size=(trials, m), p=[(1 - p_zero) / 2, p_zero, (1 - p_zero) / 2])
        # one Hadamard output coefficient is a signed sum of the 2^k trits
        s = (t * rng.choice([-1, 1], size=(trials, m))).sum(1)
        vals, cnt = np.unique(s, return_counts=True)
        pr = cnt / cnt.sum()
        out.append(dict(stages=k, terms=m, sd=float(s.std()), absmax=int(np.abs(s).max()),
                        alphabet=int(vals.size), entropy_bits=float(-(pr * np.log2(pr)).sum())))
    return out


def quantisation_wall(n=1024, rows=256, seed=0, crests=(3, 6, 12, 25, 50)):
    """Deployed pipeline vs absorbed pipeline on synthetic heavy-tailed activations.

    Deployed:  quantise AFTER the randomised Hadamard (what Bonsai does).
    Absorbed:  transform folded into the weights, so the raw activation is quantised.
    Both use one int8 scale per 128 values, exactly like prep_chunk_r.

    The activation model is synthetic; the point is the mechanism and how the error
    ratio tracks the crest factor of the raw activation block.
    """
    rng = np.random.default_rng(seed)
    H = hadamard(n).astype(np.float64)
    s = rng.choice([-1.0, 1.0], size=n)
    T = (H * s[None, :]) / np.sqrt(n)           # orthogonal, matches (1/32) H diag(s)
    W = rng.choice([-1.0, 0.0, 1.0], size=(rows, n), p=[1 / 3, 1 / 3, 1 / 3])

    def q128(v):
        b = v.reshape(-1, 128)
        c = np.abs(b).max(1, keepdims=True) / 127.0
        c = np.where(c > 0, c, 1.0)
        return (np.round(b / c) * c).reshape(v.shape)

    WT = W @ T
    out = []
    for crest in crests:
        acc = np.zeros(4)
        trials = 20
        for _ in range(trials):
            h = rng.standard_normal(n)
            idx = rng.choice(n, size=max(1, n // 256), replace=False)
            h[idx] = crest * rng.choice([-1.0, 1.0], size=idx.size)  # a few large channels
            u = T @ h
            y_exact = W @ u
            y_deployed = W @ q128(u)             # quantise in the transformed basis
            y_absorbed = WT @ q128(h)            # transform absorbed, quantise raw h
            den = np.linalg.norm(y_exact)
            acc += [np.abs(h).max() / h.std(), np.abs(u).max() / u.std(),
                    np.linalg.norm(y_deployed - y_exact) / den,
                    np.linalg.norm(y_absorbed - y_exact) / den]
        a = acc / trials
        out.append(dict(outlier_sigma=crest, crest_factor_raw=float(a[0]),
                        crest_factor_transformed=float(a[1]),
                        rel_err_deployed=float(a[2]), rel_err_absorbed=float(a[3]),
                        error_ratio=float(a[3] / a[2])))
    return out


def exchange_rate(D=5120, FF=17408, bytes_per_s=1.0e12, ops_per_s=1.5e14):
    """Cost of absorbing one butterfly stage of the shared input map.

    Saves one add per input element per token; costs ~0.5 extra bits on every
    weight of the matrix that the map feeds.
    """
    adds_saved = FF
    extra_bytes = 0.5 * D * FF / 8
    return dict(adds_saved_per_token=adds_saved, extra_weight_bytes=extra_bytes,
                seconds_saved=adds_saved / ops_per_s, seconds_added=extra_bytes / bytes_per_s,
                loss_factor=(extra_bytes / bytes_per_s) / (adds_saved / ops_per_s))


if __name__ == "__main__":
    R = dict(lemmas_n8=brute_force_lemmas(8), lemmas_n4=brute_force_lemmas(4),
             stage_alphabet=stage_alphabet(), quantisation_wall=quantisation_wall(),
             exchange_rate_one_stage=exchange_rate())
    print(json.dumps(R, indent=1))
    with open("small_examples.json", "w") as f:
        json.dump(R, f, indent=1)
