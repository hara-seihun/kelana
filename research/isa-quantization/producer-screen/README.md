# Producer-state screen: rank limits and a selected signed-carrier fit

**Comparable-size scope:** rank floors and the 8,128-byte signed-image result below are compared with a local 8,704-byte Q4 accuracy point. They preserve the stated geometry/fit evidence, but do not exclude every useful lower-size carrier or establish a state-of-the-art matched-rate result. The criterion is the [complete comparable-size frontier](../BRIEF.md#comparable-size-state-of-the-art-is-the-target), not Q4 accuracy at any byte count.

The real Qwen3-0.6B layer-0 `q_proj` fixture contains 2,048 train and 1,024 held BF16-producer input states, original BF16 weights, and a complete linear consumer. This study isolates **one 128-input-column by 128-output-row subprojection**, retaining *every* input and output at that subprojection's boundary: `F(x)=W[0:128,0:128] x[0:128]`. It does not replace the remaining columns or rows of the original Q projection, nor the attention continuation. It asks whether its 128 outputs could cheaply share a small bank of signed dot carriers instead of preserving 16,384 separate scalar coefficients.

The proposed reader computes `t_j = sum_k sign_jk*x_k`, optionally scales each carrier, then forms all 128 outputs from the shared carriers. With `r` carriers and even **arbitrary real readout coefficients**, its response matrix has rank at most `r`. No fitting of sign patterns or packed codes is needed to screen it: for `Y=XWᵀ`, the Eckart–Young squared-error floor is `sum_{j>r} sigma_j(Y)^2 / ||Y||²`. This is a *response-space* floor on the actual captured producer states, not a weight Frobenius proxy. It is optimistic: real signed carriers, FP16 gains/readout, quantization, memory scheduling and native arithmetic only constrain the family further. The SVD is a numerical floor, not a Lean-certified numeric inequality.

| Family | Static image estimate | Train response squared-error floor | Held error of free rank projection |
| --- | ---: | ---: | ---: |
| 8 shared signed carriers | 2,192 B | .096875 | .098595 |
| 16 shared signed carriers | 4,384 B | .060860 | .062523 |
| 24 shared signed carriers | 6,576 B | .042344 | .045340 |
| 31 shared signed carriers | 8,494 B | **.030937** | .033622 |
| Locally fitted affine Q4 scalar control | **8,704 B** | **.005174** | **.005174** |

Q4 packs 16,384 nibbles (8,192 B) and pays 128 FP16 scale/origin pairs (512 B). Each shared-carrier estimate pays `128*r/8` sign bytes, `128*r*2` FP16 readout bytes and `2*r` FP16 gains; it does not pay framing, decode, or instruction code. Thus *every* signed-carrier image at or below this Q4 payload has `r<=31` and even its free-real-readout floor exceeds the actual Q4 train error by at least **5.98×**. This rejects the entire shared signed-dot/linear-readout family at this local byte ceiling **for beating this scalar control on these captured responses**, without searching a single sign code. It is not a same-error optimality theorem at larger budgets or for nonlinear, routed or input-dependent continuations. Rank 64 still has .006092 floor and spends 17,536 B. The rank projection's held score is a diagnostic, not a rigorous held floor; the train floor alone makes the local rejection.

## Which constraint is doing the work?

The smallest *unconstrained-real-readout* rank whose response floor does not exceed the Q4 result is **67**. Dense FP16 readout at that rank requires 18,358 bytes before program overhead, so the initially tested family loses from a combination of **rank at its byte budget** and **description price**, not from an intrinsic low-rank obstruction at all plausible image prices. Replace its dense readout by packed signed four-bit coefficients with one FP16 scale per output row: the estimated image is `16r` signed-carrier bytes + `64r` readout bytes + `2r` carrier gains + 256 output-scale bytes. At 8,704 B it could hold rank **103** (8,702 B). The rank-only floor is already below Q4 by rank 67. This does *not* prove signed carriers can realize the good rank-67 subspace.

To discriminate the readout grid as well, the script takes the teacher response's right singular vectors as output basis, quantizes each row of that basis to signed Q4 with train-fitted, FP16-rounded scales, and then optimally projects the **complete 2,048×128 response** onto the resulting readout span. It gives the input-side carrier stage *arbitrary real* linear functions and pays its hypothetical sign plane but does not fit it. This is a **feasible response for the relaxed free-input family with one chosen Q4 readout**, not a lower bound on all Q4 readouts or a feasible signed-carrier program.

| Packed-Q4 readout rank | Estimated bytes | Train error with free input factors |
| ---: | ---: | ---: |
| 67 | 5,750 | .010459 |
| 80 | 6,816 | .005523 |
| 96 | 8,128 | **.003504** |
| 103 | 8,702 | **.002687** |

Thus neither linear response rank nor a four-bit output description **by itself** rules out a same-byte improvement: sign-constrained input factors are the next decisive screen. In contrast, fitting sign carriers under a dense FP16 readout below Q4's bytes cannot repair its certified response floor. These low-bit payloads exclude framing and executable overhead, so rank 103 has just two bytes of headroom; rank 96 is the more useful search target.

## Sign-constrained follow-up: a paid witness loses

[`fit_sign.py`](fit_sign.py) fixes **the same rank-96 Q4 readout** as the relaxed comparison, initializes the signed input rows from the sign of their optimal free-real factors, globally refits carrier gains, and then takes 160 train-improving single-sign flips in four groups of 40, refitting gains between groups. It does not look at held inputs for fitting. Its exported [`signed-carrier96.bin`](signed-carrier96.bin) is exactly **8,128 bytes**: 1,536 sign bits, 6,144 signed-four-bit output codes, 256 FP16 output scales and 192 FP16 carrier gains. Decoder replay of *those stored bytes* supplies both reported response scores.

| Rank-96 study on the same 128×128 map | Train response relative squared error | Held |
| --- | ---: | ---: |
| Fixed Q4 readout, optimal **free real input factors** | .003504 | not evaluated as an exported carrier |
| Initial signed rows + globally fitted gains | .192665 | — |
| After 160 sign flips, exported signed/Q4 reader | **.100115** | **.105783** |
| Same final signs but arbitrary real readout, free of Q4 codes and scales | .013148 | — |
| Exported scalar Q4 control | **.005174** | **.005174** |

On this explicit candidate the input signs erase the relaxed gain; even allowing its final sign plane an *unpaid optimal dense real readout* fails to match scalar Q4. This is a useful optimization-gap diagnosis for the fixed readout/basis and sign initialization, **not a sound lower bound over all signed-input matrices**. Sign-plane optimization stopped at a declared 160 improving flips, with no global certificate or claim that more search cannot find a different program. Rotating/mixing the 96-carrier basis, jointly searching signs and Q4 readout codes, or changing the consumer could change the answer. The score's evidence level is a paid, replayed candidate plus a free-input relaxation. The signed construction adds two 128×96 dense reductions (first signs, then four-bit readout) and gains/scales; no native execution timing or full attention continuation was measured.

The scalar control has a **real exported image** [`affine-q4.bin`](affine-q4.bin), 8,704 bytes, with 128 row records of 64 packed code bytes (first coordinate in the low nibble), followed by little-endian FP16 origin and FP16 step. The script decodes those stored bytes independently and asserts bitwise equality of all reconstructed FP64 coefficients with the fitted grid before scoring both response panels. Its SHA256 is recorded in `results.json`. Each row tries seven clipping starts, alternates 5 times between four-bit code assignment and a response-covariance-weighted least-squares fit of origin/step, rounds those coefficients to FP16, and selects the best train response. This is stronger than naive nearest rounding, weaker than the full-covariance sequential GPTQ/Q4 model converter. The current [Q4 complete-model report](../../quantization-discovery/q4-diagnostic/README.md) records test NLL **3.795795** at **4.251313 BPW**; the [selected rotated and scale-repaired ternary Qwen image](../../ternary/README.md) records test NLL **4.646432** at **1.727086 BPW**. Neither model-level result is a loss score for this isolated 128×128 subprojection, and this study does not infer model quality from its local squared error. In particular, the simple older Q4 rounding control is not the quality baseline.

## What the producer does and does not guarantee

The 128 captured input coordinates have **896 distinct sign patterns in train and 472 in held**, include nonbinary magnitudes (train extrema −3.578125 and 3.84375), and the 2,048×128 train matrix has full column rank with smallest/largest singular-value ratio .02744. Replacing it by a six-bit or binary producer would not preserve these observed states. It may be possible to approximate their output by a polynomial of a *chosen* input code, but binary cubic closure from [nonlinear closure](../nonlinear-closure/README.md) does not apply exactly here.

There is also a finite, exact obstruction to **zero-error** shared-carrier compression on the captured states. Multiply both the BF16 weight submatrix and FP32 train inputs by `2^28`; every entry becomes an integer. Gaussian elimination modulo 65,521 returns rank 128 for each. Their rational product `XWᵀ` therefore has rank 128, so no rank-`r<128` map agrees on all captured train states. This is a replayable modular certificate for those two exact arrays; it does **not** certify that an unseen producer's reachable set has full span. Nor does the sample covariance imply a guaranteed enclosure, much less a global worst-case response bound: it only weights the declared captured panel. Additional states could change the floor in either direction. The producer-program invariant from [complementary routes](../reachable-domains/README.md) has a different status: that complement survives *every* input by construction. No such exact low-dimensional Qwen producer identity is assumed here.

## Provenance and reproduction

Fixture owner: `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz`, SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`. The [binary-factor comparison](../../quantization-discovery/subbit/binary-factors/README.md) describes its pinned Qwen revision `c1899de289a04d12100db370d81485cdf75e47ca`, disjoint train/validation source windows and extraction contract. The full 20-MB fixture remains with that owner, rather than being copied here. `results.json` records slices, signs, ranks, low-bit contrast, exported-image hash and measured floors.

From the repository root, CPU only, one BLAS thread, roughly seconds:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/producer-screen/screen.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/producer-screen/fit_sign.py
```

The modular-rank check is exact integer arithmetic; floating SVD and local response errors use FP64. Both scalar Q4 and rank-96 signed-carrier images are exported and replayed. There is no native signed-dot reader, so carrier execution costs remain unmeasured and payload bytes exclude code/framing. A candidate aiming specifically at this Q4 error must respect the recorded rank/readout constraints. Lower-byte families need their own paid, size-matched controls and complete continuation tests; this Q4 comparison alone does not terminate that work.
