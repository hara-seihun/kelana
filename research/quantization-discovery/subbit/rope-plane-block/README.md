# Score-optimal gains on retained RoPE planes

Can a richer score decoder recover much of the variance lost by retaining only 112 Q/K RoPE planes? The [plane allocation](../rope-plane-rate-allocation/README.md) uses coefficient one on each retained plane. Here the same 28-component-per-group cache and the same score products use a learned scalar coefficient on each plane. This is the cheapest non-binary score decoder that still commutes with every RoPE position.

## Exact conditional optimum

Let `z_i` be the real dot-product contribution of plane `i`, including its relative RoPE rotation. The domain is the previous study's independent isotropic hidden Q/K inputs, the original BF16 Q/K matrices cast to FP64, both Q heads averaged, and uniformly sampled relative positions 0–4095. Its 64-by-64 positive-semidefinite Gram is `M_ij = E[z_i z_j]`. For a fixed retained set `S`, choose coefficients `a` for `sum_(i in S) a_i z_i` while the target is `sum_(i=0)^63 z_i`. Write `A=M_SS`, `c=M_S,S^c 1`. Its squared-error objective is

`1_(S^c)^T M_(S^c,S^c) 1_(S^c) - 2(a-1)^T c + (a-1)^T A(a-1)`.

Therefore `a*=1 + A^+ c` is the globally optimal real decoder **for that fixed mask**, with improvement `c^T A^+ c` over coefficients one. The pseudoinverse expression is valid even if `A` is singular: a covariance Gram has `c` in the range of `A`. Rounding `a*` to FP16 adds exactly `(round(a*)-a*)^T A (round(a*)-a*)` to this real score objective. Those formulas are a quantitative certificate for every fixed-mask result, not an assertion about model loss.

For isotropic score queries the Gram is diagonal, `c=0`, and **no plane gain can improve any mask at all**, regardless of K's cross-plane covariance or the position horizon. In the Q-weighted domain, `c` is nonzero and the code fits each mask's gain by least squares. A one-plane exchange search from each previous uniform mask also reoptimizes the gains after each candidate exchange. That search is local, not a proof of the best mask.

## Pinned-weight result

Pooled retained score-variance fractions across eight groups are below. `Capped` is the previous 112-plane allocation with each group at most 16 planes, so every aligned BF16 key group remains within one 64-byte line. Each row holds the masks and total score products fixed while fitting coefficients; the uniformly allocated mask exchange changes one layer-0 group and none at layer 14.

| Layer | Mask | Coefficient one | Optimal real gain | FP16 gain |
| --- | --- | ---: | ---: | ---: |
| 0 | Uniform 14/group | .44170327 | .44220474 | .44220473 |
| 0 | Capped 112 total | .44537068 | .44595635 | .44595634 |
| 14 | Uniform 14/group | .55788532 | .55793271 | .55793270 |
| 14 | Capped 112 total | .56755236 | .56758698 | .56758698 |

The capped gain recovers only **.000586** of layer-0 full score variance and **.000035** at layer 14. By contrast, redistributing the same 112 whole planes without gains recovered .003667 and .009667. The capped fitted coefficients range .8866–1.2341 at layer 0 and .9440–1.0176 at layer 14. FP16 rounding spends practically none of the real gain. The complete per-group masks, gains, Gram hashes, source/model/config/allocation hashes and all score fractions are in `data/kelana-subbit/rope-plane-block/receipt.json`.

One FP16 coefficient per plane adds 224 bytes per layer or 6,272 bytes over 28 layers, about .000084 payload bits per unique model parameter. The score/cache loop still reads 512 aligned BF16 key bytes per occupied token per layer and does 448 real score products across two heads. Scaling the two query components of every retained plane for both heads once per new query takes 448 scalar multiplications per layer, rather than one extra scale per plane **per key**. A compressed Q producer might fold these gains into paid scales, but no such image exists here, so the extra storage and query preparation are charged. The key projection and cache producer still have to be built and timed; no native or whole-model result follows.

This closes gain-only optimization of the weight-covariance surrogate. The tiny conditional optimum is stronger evidence than another gain grid: even perfect real gains on these masks cannot recover more than the table shows. It says nothing about the gain on causal text or the quality of learned sub-bit Q/K codes. The next experiment should fit selected-row packed Q/K against both heads' causal attention on quantized-producer text, compare a paid binary control, and test held post-O behavior and complete-model loss. The current mask can be held fixed while that more consequential objective changes.

Reproduce on CPU with the prior allocation receipt:

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/rope-plane-block/block.py \
  --output /path/to/workspace/data/kelana-subbit/rope-plane-block/receipt.json
```

No GPU lock, Bonsai executable or resident service changed.
