# One equal-byte joint-norm affine response edit

**A changed objective improves the exact observer it targets, but not every later consumer.** Starting from the frozen 50,320-byte H-fitted mixed group128 Q2/Q3 scalar image, we kept **all 1,024 group bit modes and every packed coefficient digit fixed**. One predeclared full-output Gauss–Newton step updates only its existing FP16 scale/origin fields. Ideal-real train normalized-Q relative squared error falls `.01510073 → .01502263`; the inspected held value also falls `.01811911 → .01800241`. On the original full BF16-rounded causal observer, held normalized-Q improves `.01812619 → .01800902` but attention KL *worsens* `.01821224 → .01830218`; held head-0 post-O response improves `.02185195 → .02158754`. Thus a source-only joint norm metric can improve a real stored image at equal bytes, but it does not faithfully stand in for the entire attention/output response. We exported this sole candidate unconditionally; no held/consumer-aware tuning or next candidate followed.

## Fixed source, program, and single-step policy

The source is the exact [2,048 train / 1,024 inspected held captured Qwen3-0.6B layer-0 q-projection inputs](../quip-full-row-slab/README.md), fixture SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`, first 128 Q rows across all 1,024 inputs. Original H scalar image SHA256 `e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15`; new image SHA256 `18fbba120a75f1788d674099ee82166e3509908c213021196df011ecea66b370`. Both serialize exactly **46,096 coefficient bytes + 4,096 existing FP16 affine-field bytes + 128 mode-mask bytes = 50,320 bytes**, or 3.0712890625 effective bits per source coefficient. In the new image, only 1,949 bytes of the existing fields differ; all code and mode bytes are identical. There is **no new inference metadata, gamma, rank update, shared codebook or per-model runtime state**. Decoding has the same scalar work and field memory layout. Offline original checkpoint, inputs, Hessian and optimizer state are preparation, not charged compressed image fields; source Q/K/V/O and gamma are common to all unchanged consumer arms.

Let the original decoded scalar row be `ŵ_r` and let `z_r=x·ŵ_r`. For each output `r`, choose two parameters `(a_r,b_r)` changing the decoded row to `(1+a_r)ŵ_r + b_r 1`, achievable by multiplying *each* of that row's eight existing FP16 scales and origins by `1+a_r` and adding `b_r` to the origins. Thus 256 real fit parameters affect 2,048 paid FP16 fields; this is **not** an unconstrained per-group or code refit. The original code/mode assignment and all other Q head coordinates are fixed. At each train producer state, minimize locally the **entire 128-output learned-gamma RMSNorm vector** discrepancy to the original Q teacher, ideal real arithmetic and `ε=1e−6`. The Jacobian `J(z)=Γ/√s (I−zzᵀ/(128s))` with `s=||z||²/128+ε` couples output rows. Let `B_t` be its product with the 128×256 derivative of the changed raw response, where columns `(r,0)` and `(r,1)` have raw feature `z_tr` and `sum_j x_tj` on coordinate `r`, respectively. [`fit.py`](fit.py) forms `g=Σ B_tᵀ(F(z_t)−F(Wx_t))` and the **full 256×256** `H=Σ B_tᵀB_t` (including cross-output terms) via a diagonal-plus-low-rank identity for `JᵀJ`. It takes exactly one full step `(H+0.01 diag H)θ=−g`, where `.01` is the *predeclared algorithmic damping fraction*, not a held-selected multiplier. It then FP16-rounds all existing fields once. No line search, rejection criterion, iterative extension or subsequent code selection is used. Gain range is `[.98866169,1.15986803]`, origin shift range `[-.00355677,.00229652]`; rounded scales stay positive. The `.01` damping and finite FP16 rounding mean this is one local, restricted-family GN update, **not the global optimum of the full output-coupled tensor**. The fit stage uses train captures only, not the held split or attention/O.

[`replay.py`](replay.py) is independent of the fitter/packer: it checks source and image hashes, unpacks every 2-/3-bit digit from each stored payload, verifies code/mode identity against the original H image, checks FP16 fields, reconstructs both complete 128×1,024 weights and scores train/held. The original stored image remains available and unchanged. It found:

| Panel | Image | Raw-Q ideal real rel sq | Normalized-Q ideal real rel sq |
| --- | --- | ---: | ---: |
| train | original H scalar | .012346793 | .015100728 |
| train | single-step joint affine | .012676786 | **.015022627** |
| inspected held | original H scalar | .014627799 | .018119107 |
| inspected held | single-step joint affine | .014874633 | **.018002412** |

Raw Q worsens while normalized Q improves: the objective change, not another raw-Q code fit, determines this trade-off. The small held improvement is an *observation of the already frozen image*, not an unbiased model-selection estimate.

## All twelve unchanged causal windows

[`observer.py`](observer.py) reuses the canonical [complete Q-head observer](../quip-complete-head-observer/README.md) numerical contract with its original Q/K/V/O and Q/K gamma, 256-token causal windows, BF16-rounded projections/norm, RoPE, softmax and unchanged peer GQA Q head; it adds the **independently decoded new stored image** to the four frozen original arms. [`aggregate.py`](aggregate.py) requires all eight train and four held windows, sums squared numerators and denominators, checks source/image identity and asserts original arms reproduce canonical baseline totals. Per-window actual causal receipts are `train-0..7.json`, `held-0..3.json`; [`observer-result.json`](observer-result.json) retains combined and per-window values. The scores are **CPU BF16 replay**, not native GPU exact rounding or deployment latency:

| Panel | Frozen/edited arm | BF16 raw-Q | BF16 norm-Q | Attention KL | Head-0 post-O | Two-head GQA post-O |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| train | root_H (50,322 B) | .00384632 | .00650720 | .00577451 | .00603990 | .00053854 |
| train | scalar_H original (50,320 B) | .01234937 | .01510696 | **.01320982** | **.01510679** | **.00134698** |
| train | scalar joint-affine (50,320 B) | .01268085 | **.01502483** | .01336137 | .01514518 | .00135040 |
| inspected held | root_H (50,322 B) | .01310947 | .02141683 | .02416825 | .02784225 | .00285930 |
| inspected held | root_M (50,322 B) | .01261853 | .02097905 | .02312622 | .02603103 | .00267330 |
| inspected held | scalar_H original (50,320 B) | .01462970 | .01812619 | **.01821224** | .02185195 | .00224412 |
| inspected held | scalar joint-affine (50,320 B) | .01488840 | **.01800902** | .01830218 | **.02158754** | **.00221697** |

`scalar_M` is also replayed and retained in the receipts, but the controlled edit starts from `scalar_H`; it is not an additional fit arm. The norm-Q difference improves on both source panels; this does not imply monotonicity of causal attention KL or a quality dominance over the unchanged scalar image. All changed metrics are reported; choosing KL after seeing the held data would disqualify this single predeclared candidate. This is a local fixed-code restricted edit, not Fisher/Gauss–Newton PTQ invention, state-of-the-art whole-model evaluation or complete-program speed claim.

## Bounded reproduction

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/normalized-affine-refit/fit.py
$PY research/isa-quantization/normalized-affine-refit/replay.py
for i in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/normalized-affine-refit/observer.py train "$i"; done
for i in 0 1 2 3; do $PY research/isa-quantization/normalized-affine-refit/observer.py held "$i"; done
$PY research/isa-quantization/normalized-affine-refit/aggregate.py
```

Each CPU command completes within a minute; no GPU is required. [`fit-result.json`](fit-result.json), [`replay-result.json`](replay-result.json) and all window receipts are tracked. The source checkpoint/fixture and four other images remain owned by their original studies; this directory owns only the one additional image, objective-specific preparation, independent reader and consumer evidence. The [joint-metric theorem and finite obstruction](../normalized-observer-metric/README.md) explain why an input covariance alone cannot represent every infinitesimal normalized-output edit, not why this particular finite edit must improve any other endpoint.
