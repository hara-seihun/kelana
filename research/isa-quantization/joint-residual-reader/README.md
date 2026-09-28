# A nonlinear Q3 base plus a source-derived output correction

**Comparable-size scope:** this 4,742,148-byte container improves Q3 but is compared with a larger 4,866,096-byte Q4 payload. Its fixed-direction floor rules out that particular Q4 accuracy, not competitive lower-size corrections. The [benchmark contract](../BRIEF.md#comparable-size-state-of-the-art-is-the-target) requires strong quantization at comparable effective sizes; all results below retain their stated local/pool boundaries.

**Decision:** This complete MLP executable image does not beat the actual decoded all-three-projection scalar Q4 control. The calibrated group-128 Q3 gate/up/down image preserves the original SiLU-times-up topology and leaves **1,179,648 bytes** beneath Q4's 4,866,096-byte payload ceiling. A signed Q8 **direct output Jacobian correction** with FP16 per-output scales and bias consumes 1,052,672 of those bytes. On all 1,024 outputs of 1,024 actual Qwen3-0.6B layer-0 producer inputs, held relative RMS improves from **.30812 to .24942**, but Q4 scores **.16253**. This is a negative for this specifically source-informed correction, not all jointly fitted base-plus-correction programs.

The discriminating obstruction is stronger than merely this failed fit. Freeze the **stored Q3 base and stored Q8 Jacobian direction**, then grant each output its own arbitrary real gain and bias, optimized with hindsight against **both** train and validation responses. Its least-squares pooled RMS floor is **.24848**, whereas the physically exported Q4 scores **.16384** on that union. No output-wise gain, intercept calibration, optimizer or more trace queries can make this fixed-direction family win on the observed union. In contrast, a fully unrestricted FP64 affine correction of this same Q3 base has pooled floor **.09999**. The obstruction is the **direction provided by averaging source Jacobians**, not a theorem ruling out affine residual correction or nonlinearity-preserving bases in general. The latter oracle has 1,025 unconstrained fields per output and fits targets from both panels; it is emphatically not a payable, transferable image.

## Construction and complete byte ledger

The source is the full bias-free BF16 layer-0 map `F(x)=D[SiLU(Gx)⊙(Ux)]`, input width 1,024, hidden width 3,072, output width 1,024. The base `B` uses the existing calibrated scalar fitter's four clipping seeds and five alternating code/scale steps per seed on **all three source matrices**, now with three-bit codes. It is serialized as three packed code planes and FP16 group-128 scales. The previously inspected separate validation has four disjoint 256-state windows, as does train. The source is consulted for offline derivative preparation, not evaluated in the online corrected reader.

For any model matrices `G,U,D`, write `g=Gx`, `u=Ux`, `s=σ(g)`. The Jacobian is

```
J(x) = D [diag(s(1+g(1-s))⊙u) G + diag(sg) U].
```

Average each diagonal vector over **train only** for source and Q3 base separately, producing `J̄_source−J̄_base` without learning a million unrelated coefficients from 1,024 traces. Quantize each output row of this difference to signed int8 with its own FP16 scale. The 1,024-entry FP16 bias is the mean train complete-output residual minus the mean-input contraction with the *unrounded* derivative difference. Online execution decodes the Q3 matrices, evaluates `B(x)`, then adds `x @ Jq.T + bias`. All responses include the actual down projection and every output; no free target/down readout remains.

| Paid model-specific field | Bytes |
| --- | ---: |
| Q3 codes, scales, three 16-byte shape descriptors | 3,686,448 |
| Direct `[1024,1024]` signed int8 correction | 1,048,576 |
| 1,024 FP16 correction row scales | 2,048 |
| 1,024 FP16 correction bias | 2,048 |
| **Total decoded payload** | **4,739,120** |
| **Actual two serialized `.npz` containers, including ZIP/framing** | **4,742,148** |
| Complete calibrated scalar Q4 payload, all three matrices | **4,866,096** |

Thus even **charging the actual container overhead against Q4's payload** leaves 123,948 bytes. Generic decoder instructions are shared code, not model-specific constants; all model-specific values are in these containers. The shape follows the existing Qwen layer-0 architecture; the Q3 payload explicitly includes the shape descriptors. Q3 alone has 9,437,184 coefficient-input products per token, and the Q8 correction adds 1,048,576 (total **10,485,760**), a further output accumulation and dense correction read. Q4 has the same base product count plus nonlinear work, but only Q4's three packed matrices are read. These counts do **not** imply native speed: no packed reader was assembled or timed, and the extra correction erodes the small byte saving.

| Complete 1,024-output RMS / BF16 source | Train | Separate validation |
| --- | ---: | ---: |
| Stored calibrated Q3, three matrices | .31182 | .30812 |
| **Stored Q3 + decoded Q8 direct correction** | **.24916** | **.24942** |
| Stored calibrated scalar Q4, three matrices | .16516 | **.16253** |
| Pooled oracle: Q3 + fixed Q8 direction, arbitrary output gains and biases | — | **.24848 over union** |
| Pooled oracle: Q3 + arbitrary complete FP64 affine correction | — | **.09999 over union** |

The first oracle projects each output's centered Q3 error onto its centered, stored-Jacobian response direction; the remaining centered residual is exactly orthogonal. The second projects onto the centered complete 1,024-dimensional input span. The tiny gap between .24942 and the first oracle's .24848 means coefficient rescaling cannot help. The wide gap from unrestricted affine correction points to the missing producer-sensitive directions, **not** a rank ladder or a few unoptimized gain constants. The latter pooled fit uses validation targets and is only a finite-panel capacity relaxation; validation itself was already inspected in the preceding ISA programme and is not untouched final evaluation. No full-model language loss, native ISA timing or unseen producer guarantee is claimed.

The analogous [Qwen MoE Q3 residual corrector](../../moe/q3-residual-corrector/README.md) and [scalar direction oracle](../../moe/q3-scalar-correction/README.md) reject source-frozen corrections for a different 2,048-output routed-sum endpoint. Their results motivated checking the entire correction direction instead of another rank/ridge ladder. Here the **base is a different model**, all three dense MLP projections are re-encoded, and the new proof-of-limitation distinguishes a weak analytic direction from a potentially useful arbitrary correction. [`Kelana/JointResidualReader.lean`](../../../Kelana/JointResidualReader.lean) establishes the joint-error and product-mixed-term identities; the numerical QR floors are separate calculations, not formalized numerical certificates.

## Reproduction and custody

From the Kelana repository root, with the installed NumPy/Torch/safetensors environment, all CPU computations use one BLAS thread and each of the five commands is under a minute:

```sh
D=research/isa-quantization/joint-residual-reader
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/study.py" q3
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/study.py" fit
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/study.py" replay
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/direction_floor.py"
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 "$PY" "$D/floor.py"
lean Kelana/JointResidualReader.lean
```

[`results.json`](results.json) records all physical image SHA-256 hashes and split scores; [`direction-floor.json`](direction-floor.json) and [`floor.json`](floor.json) record the two generous projection floors. Source checkpoint SHA-256 is `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`; the reused calibrated scalar quantizer source SHA-256 is `916023173ad9c675c4a45b46541295aa176e51396093209ff55d02e67acbc75a`. The ten captures live in the durable [ISA-response owner](/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response/README.md), and the scalar Q4 image provenance is in the [nonlinear-response-bank receipt](../nonlinear-response-bank/results.json). The two reproducible `.npz` images are ignored generated outputs rather than a selected deployable candidate; no altered model/service is installed. The negative is scoped to **fixed calibrated Q3 codes plus this source-mean-Jacobian correction direction** on the recorded producer endpoint. A better path has to jointly change the base codes or construct different transferable residual directions, and then export and test a frozen full image.
