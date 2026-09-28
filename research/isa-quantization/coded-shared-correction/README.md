# Code and shared correction should be chosen together

**Comparable-size scope:** the co-designed/frozen-code comparison is genuinely same-byte and shows a gain. The 4,836,094-byte co-designed container versus the 4,866,096-byte Q4 payload is a nearby but unequal-size diagnostic, not family exclusion or a named SOTA comparison. Preserve that distinction under the [current benchmark contract](../BRIEF.md#comparable-size-state-of-the-art-is-the-target).

**Outcome:** Co-designing the coarse codes with a shared nonlinear-branch correction materially helps this representation, but it still does not beat the complete calibrated scalar Q4 MLP. On all 1,024 outputs of the original Qwen3-0.6B layer-0 MLP and 1,024 held producer states, a source-only co-designed image scores **.27849 relative RMS**, versus **.29093** for the same-size correction added to frozen Q3 codes, **.30812** for Q3 alone and **.16253** for the 4,866,096-byte all-three-projection Q4 control. The co-designed image pays **4,833,328 model payload bytes**, or **4,836,094 physical container bytes**. Its held error remains 1.71× Q4; do not install it. This is a bounded negative for this explicit source-only shared low-rank code/correction construction, not for joint quantization generally.

The substantive premise changed from the [fixed Q3 plus direct Jacobian correction](../joint-residual-reader/README.md) and the [MoE shared-compensation negative](../../moe/shared-compensation/README.md): **gate and up Q3 codes are re-encoded after a candidate correction has been assigned**. Neither a frozen original-image residual nor a learned free output table is the central object. The correction carries a shared 80-dimensional input observation into *both* gate and up projections *before* the nonlinear SiLU/product. This keeps the full nonlinear response topology. No coefficient is fit against the 1,024 target responses: the source BF16 matrices alone determine the Q3 codes and FP16 factors, so the separate held panel genuinely measures producer transfer of a source-derived image. Held was already inspected elsewhere in this programme, and is not untouched final evaluation.

## Executable family and code step

Let the original source be `F(x)=D[SiLU(Gx)⊙Ux]` with `G,U:3072×1024` and `D:1024×3072`. Store group-128 calibrated Q3 code/scales for all three matrices. Store `A:[6144,80]` and `B:[80,1024]` in FP16, with the upper/lower halves of `A` shared between the gate/up correction:

```
z = B x
ĝ = Gq x + A_gate z
û = Uq x + A_up z
P(x) = Dq [SiLU(ĝ) ⊙ û].
```

The frozen control first independently quantizes `G,U,D`, then finds a deterministic randomized rank-80 SVD of the stacked `[(G−Gq);(U−Uq)]`. The co-designed arm starts from precisely that paid image and factor; it next **re-quantizes both gate and up** against their *source minus the planned factor product*, then recomputes the rank-80 factor of their new residual. Down remains the identical original Q3 image in both arms. This is one alternating code/factor update, not an output-target fit or a rank/ridge sweep. The algorithm is standard low-rank-plus-quantization alternating reconstruction in coefficient space; the new evidence is whether its changed source error geometry transfers to the **complete real MLP endpoint at a physically paid budget**. [`Kelana/CodedSharedCorrection.lean`](../../../Kelana/CodedSharedCorrection.lean) states the shifted-target identity and an exact finite-grid witness that a fixed correction can change the best coarse code. No global optimality of this alternating step is implied.

The shared input factor is computed **once** per token. The product `A B` is never materialized as a second online weight matrix. The randomized SVD uses a deterministic seed, 16 oversampling directions and one power pass; FP16 factors are serialized *before* output replay. Each group stores every signed Q3 code packed into three bitplanes and its FP16 scale. Shape descriptors are stored for all three images. No branch IDs, per-token gains or free consumer decoder exist.

| Model-specific fields | Bytes |
| --- | ---: |
| Three group-128 Q3 images, codes + FP16 scales + descriptors | 3,686,448 |
| FP16 shared input factor `[80,1024]` | 163,840 |
| FP16 gate/up factor `[6144,80]` | 983,040 |
| **Total model payload** | **4,833,328** |
| **Actual serialized `.npz` container** | **4,836,094** |
| Complete scalar Q4, all three matrices, payload | **4,866,096** |

Even comparing the candidate's physical container with the Q4 **payload** leaves 30,002 bytes. A Q4 `.npz` container would itself have framing overhead; the mixed comparison is favorable to Q4. The candidate computes 9,437,184 dense base coefficient products, plus 81,920 for `Bx` and 491,520 for `Az`: **10,010,624** coefficient products per token, also gate/up elementwise sums. It reads an extra 1,146,880 bytes of FP16 factors. This is a semantic executable program, not an assembled gfx1151 reader or native speed claim. The same generic quantizer/reader implementation is not model-specific payload. Runtime work and memory traffic make a speed advantage implausible absent a measured layout or downstream reuse.

| Full original BF16 MLP endpoint, RMS | Train | Held |
| --- | ---: | ---: |
| Actual all-three calibrated Q4 | .16516 | **.16253** |
| Calibrated Q3, no correction | .31182 | .30812 |
| Frozen Q3 + shared low-rank gate/up correction | .29418 | .29093 |
| **Co-designed gate/up Q3 codes + shared correction** | **.28143** | **.27849** |

Thus co-design recovers .01244 additional held RMS over the same-byte frozen correction (roughly 40% of the total .02962 improvement over raw Q3). The corresponding relative coefficient error of the *stacked gate/up source matrix* improves from .17926 frozen to .16953 co-designed. Train and held changes agree closely; the limited gain is not trace interpolation. Q4's large remaining lead shows that source-coefficient improvement is not sufficient at this byte/work point. In particular, the fully nonlinear product amplifies gate/up errors and Q3 down remains independently quantized. This one update does not establish a lower bound against a complete-output-optimized code step, a different carrier, or code/correction sharing across layers.

## Reproduction and custody

The code reads the original BF16 checkpoint and the durable ten-array [ISA response capture](/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response/README.md). The reused scalar fitter is `research/quantization-discovery/subbit/spectral_quant.py` (SHA-256 `916023173ad9c675c4a45b46541295aa176e51396093209ff55d02e67acbc75a`); it uses four clipping seeds and five alternating code/scale steps per seed. Source checkpoint SHA-256 is `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`. [`results.json`](results.json) holds physical image hashes, exact payload/container sizes and complete response scores. All model-specific fields in the images are serializable and replayed from the saved bytes; the failed candidate images are ignored generated artifacts, not deployed weights.

From Kelana root on the existing CPU, one BLAS thread, each command under a minute:

```sh
D=research/isa-quantization/coded-shared-correction
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/study.py" fit
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/study.py" replay
lean Kelana/CodedSharedCorrection.lean
```

No GPU, native reader, full-model NLL or untouched new producer panel was involved. The result distinguishes a genuine same-byte co-design effect from an improvement competitive with Q4, and avoids another scalar-gain or rank ladder on frozen error directions.
