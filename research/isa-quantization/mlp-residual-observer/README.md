# The MLP residual is not its branch; the next skip is not its norm

**Decision.** A projected next RMSNorm has genuine nontrivial *exact* residual fibers even with positive epsilon and nonzero gamma. But a normal decoder block uses the same residual as the next skip: if its normalized attention observation is held fixed, changing the residual changes the subsequent residual by exactly the same vector. Dropping branch-vector fidelity can buy something only after the replacement also represents that live skip (or a jointly changed continuation). The existing all-three-projection Q4 image has just **1.04%** of its squared held residual error radial to its own output on a real, separately captured layer-0 boundary. On that frozen image, exploiting only radial slack is unlikely to repair its normalized response. This is a scoped negative, not a theorem against joint residual-coordinate programs.

## Exact quotient and its missing consumer

Let `h` be the actual pre-MLP skip, `x=RMSNorm_post-attn(h)` the MLP *input*, `F(x)` its complete nonlinear branch and `t=h+F(x)`. The next layer reads `Nε(t)=Γt/sqrt(||t||²/d+ε)` for Q/K/V, but also retains `t` for its own next skip. An alternative branch `P(x,h)` gives `b=h+P(x,h)`. For a row reader `w`, equality of `w·Nε(b)` and `w·Nε(t)` is the observation obligation; preserving `P=F` is sufficient but not necessary. It is wrong to substitute the previously captured normalized `x` for `h`.

A concrete rational witness has `d=2`, `ε=1`, `Γ=I`, `h=(2,0)`, `t=(1,4)` and `b=(1/3,0)`. The branches are `F=(-1,4)` and `P=(-5/3,0)`. Yet their first normalized outputs are both positive and have identical square `2/19`, hence are exactly equal. The second coordinate differs. [`Fiber.lean`](Fiber.lean) kernel-checks the squared first-coordinate equality and branch distinction over rationals; positivity of both first coordinates and denominators supplies the elementary square-root step in prose. This is a **structural** witness, not a compression win: the full normalized vector, another nonzero second-coordinate reader or an unmodified next skip distinguishes it. A direct static response reader is a serious control for this tiny constant example and can be cheaper than the branch construction.

For any `c>0`, `Nε(cb)=Γb/sqrt(||b||²/d+ε/c²)`: at positive epsilon radial scaling is *nearly*, not exactly, invisible when signal energy dominates epsilon. If the next attention update is `A(Nε(b), context)`, then the continuation `b + A(Nε(b), context)` retains the raw residual. For two states with the same complete normalized attention context, their next outputs differ by `b−t`. Carrying a shared normalized label without a radius cannot serve that continuation. When all gamma coordinates are nonzero, positive epsilon even makes the *full* norm output injective in ideal reals; inversion of `y=Γ⁻¹Nε(t)` requires `t=y sqrt(ε/(1−||y||²/d))`. A hypothetical retained full label still pays gamma inversion, reduction, scalar square root, scaling and numerical conditioning to recreate the skip. A small projected label does not even contain enough information for that inversion.

## Frozen real boundary, all next Q/K/V rows

[`screen.py`](screen.py) reads the owned [layer-0 teacher/quantized-producer capture](/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.json). Its `*_teacher_pre` arrays were saved by a **pre-hook on `post_attention_layernorm`**, before the MLP norm; `*_teacher_input` was saved by the gate projection pre-hook, *after* that norm. Its `*_teacher_post` is the layer output. This capture comes from original BF16 layer-0 attention and MLP, with tied source embeddings, not from the ternary producer used by the earlier MLP-response studies. The source branch plus captured skip reproduces the recorded BF16 layer output to .00262 train/.00258 validation relative RMS in the ideal FP32 replay, a useful independent boundary check (BF16 output rounding and operation order differ). The captured panels are 2,048 train and 1,024 previously inspected validation positions. Do not transfer scores from the separate ternary-capture experiment as if they shared a producer.

The control independently decodes all original Qwen3-0.6B layer-0 Q4 **gate, up and down** images, with group-128 FP16 scales and shape descriptors: **4,866,096 model payload bytes**. The source uses the pinned BF16 checkpoint. After the true skip add, the live local observer is layer-1 input RMSNorm (`ε=10⁻⁶`, actual gamma) and **all layer-1 Q/K/V projection rows** (4,096 outputs). Those next-layer source weights are shared unchanged in all arms. The output norm, next layer's attention mixing and next MLP are not measured. All calculations here use FP32 matrix products and an ideal-real FP32 RMSNorm, not a BF16 native replay.

| Relative RMS against source, complete positions | Train | Validation |
| --- | ---: | ---: |
| Frozen Q4 MLP branch | .155441 | .154330 |
| Q4 **residual** `h+Fq(x)` | .082266 | .080613 |
| Next RMSNorm of Q4 residual | .091005 | .090248 |
| All next Q/K/V rows of that norm | .070390 | .069311 |
| Half-scaled residual `(h+Fq(x))/2`: branch | .958802 | .971062 |
| Half-scaled residual: next norm / all QKV | .091004 / .070389 | .090248 / .069311 |
| Twice-scaled residual: branch | 1.871089 | 1.895968 |
| Twice-scaled residual: next norm / all QKV | .091005 / .070390 | .090249 / .069312 |

The half/twice arms are **executable perturbations**, not fitted or proposed quantizers: each needs another 1,024-coordinate multiply and, if the branch interface is explicit, a 1,024-coordinate subtraction of the available skip. Their scalar constants can be machine immediates (no new model field), but code/instructions/traffic are not free. Their residual errors on validation are .507225/.990341 versus Q4 .080613. They expose a nearly null *local normalized observer* while failing the live skip badly. The ratio `||Nε(b/2)−Nε(b)||/||Nε(t)||` is `2.64e−5` on validation; the twice-scaled ratio is `6.60e−6`. A downstream continuation cannot adopt either from these local numbers.

Projecting the Q4 residual error `t−b` onto `span(b)` *after reading teacher targets* accounts for **.01044** of its squared validation error (.01063 train). Granting that complete per-token radial correction for free changes validation next-norm RMS from `.09024845931` to `.09024846093`—no improvement at reported precision. The oracle is neither stored nor executable without teacher responses. It probes whether this particular already-frozen Q4 error lies in the cheap radial direction; it does not bound a redesigned quantizer that moves its error toward that direction. A more productive route would search a paid coupled MLP/next-attention/skip representation rather than scale this frozen Q4 branch.

This experiment does **not** establish a new rate-distortion frontier point: there is no smaller stored image, emitted native reader, or full-model gold loss. The Q4 is a calibrated local scalar control, not a claim of global SOTA. The exact projected-fiber witness states why the source branch can be discarded at a restricted endpoint; the genuine next-skip obligation and measured error geometry state why this particular easy continuation does not deliver that saving here. A future paid candidate must price the exact skip/state representation and every next consumer before claiming a whole-region advantage.

## Reproduce

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/mlp-residual-observer/screen.py
lean research/isa-quantization/mlp-residual-observer/Fiber.lean
```

Both are bounded CPU commands under one minute. [`results.json`](results.json) binds capture, source and every packed Q4 image by SHA-256 and records full-precision split scores. The source arrays and original capture stay with their existing data owner; this study adds no duplicate copies, persistent preparation table, GPU job or service change.
