# A tied loop with a recoverable ternary gauge

The paid matrix in this six-token bigram model supplies both the input embedding and the output head. Its transition logits are `L = E A Eᵀ`. A change of hidden coordinates `E -> E G` must change the body to `A -> G⁻¹ A G⁻ᵀ`; fitting either matrix against its original coordinates misses that freedom. In this toy, the *logits themselves* identify a cheap coordinate choice. No gradient descent on the joint model is needed.

Let `C` have rows `(1,0), (0,1), (1,1), (1,-1), (-1,1), (-1,-1)`. The teacher has `E = C R`, where `R = [[1,1],[0,1]]`, and `A = 1.25 R⁻¹ R⁻ᵀ = [[2.5,-1.25],[-1.25,1.25]]`. Thus `L = 1.25 C Cᵀ`. Its embedding contains `(1,2)` and `(-1,-2)`, which a single ternary code and scale per row cannot represent. The jointly chosen image stores `C`, six unit row scales, ternary identity body codes, and one body scale of 1.25. It reproduces *every* teacher logit, although its embedding has squared error 5 against the teacher coordinates. Those coordinates are not what the next operation observes.

The recovery uses two anchor tokens. Their teacher logit block is `L[0:2,0:2] = 1.25 I`. Every code row follows by `C_i = L[i,0:2] (L[0:2,0:2])⁻¹`. All recovered entries are exactly in `{-1,0,1}`. This is a sufficient behavioral observation of the shared code, given the stated anchor/body family. The recovered body and row scales fit in the same format as independent rounding; a decoder reads one embedded row for an input token and computes all six tied-head scores at output. The gauge is selected offline, so its inverse is not executed per token.

## Exact-map result and controls

[`experiment.py`](experiment.py) enumerates all nine ternary codes including zero for each embedding row and analytically chooses its best nonnegative scale by squared error in the teacher's hidden coordinates. It then either enumerates all 81 ternary body codes with an optimized positive scalar, or refits all four body entries as unrestricted real numbers against the full teacher next-token distributions. KL below averages all six teacher contexts and their six possible next tokens. There is no sampled train/test split: this is the complete finite map.

| Image / body fit | Teacher embedding squared error | Mean teacher KL |
| --- | ---: | ---: |
| Jointly recovered ternary gauge, body `1.25 I` | 5 | **0** |
| Independently optimal row codes/scales, best ternary body | **1** | 0.212883 |
| Same independent embedding, four unrestricted real body entries | **1** | 0.080733 |

The equal-format comparison pays 12 embedding trits packed into three radix-243 bytes, six FP16 row scales in 12 bytes, four body trits in one byte, and one FP16 body scale in two bytes: **18 payload bytes** for either ternary image. The ternary control's optimizing body scale is kept as a real number in the calculation, which favors the control slightly over its stored FP16 version. The unrestricted-body oracle replaces the body's three bytes with four FP64 entries, making 47 bytes, and still cannot close the gap. The toy's dimensions and fixed layout are shared model metadata, not a claimed general-purpose container size. There is no online throughput result.

This is more than a bad choice of body quantizer. Let `H = I - 11ᵀ/6` center vocabulary rows. If two logit matrices give the same row-softmaxes, they differ by row-constant offsets and therefore have the same `H L H`. For the independently rounded embedding `D`, every centered candidate `H D B Dᵀ H` has columns in `col(H D)`, whatever real `B` is. Here `||(I-P_col(HD)) H L H||_F = 2.005228`, so the independent embedding has lost observable transition information. The real-body oracle's positive KL is structural, not an unsuccessful optimization run.

## Boundary of the construction

The teacher logits are available during conversion. This method assumes two anchor rows whose *new-gauge* codes are coordinate vectors and a body code/scale family that makes their logit block invertible. Arbitrary layers will not have such anchors, and a general gauge can make their body expensive to store or execute. In particular, this example does not imply that the existing Qwen tied matrix admits this rank-two Gram factorization, or that minimizing a captured final-head response without propagating embedding changes is enough. The earlier [tied-factors study](../../quantization-discovery/subbit/tied-factors/README.md) already showed a head-KL versus gold-NLL ranking reversal on fixed original-model head inputs; this experiment instead gives an exact joint solution and an observable obstruction to separate fitting.

A discriminating transfer test is to capture short-sequence teacher logit kernels after each candidate quantized embedding has propagated through the body. Measure the numerical rank and centered-column-space mismatch of their tied input/output response, then search a restricted low-cost gauge jointly with its transformed body and packed scales. Compare actual whole-model gold NLL against separately optimized rows at identical bytes. A large mismatch that no cheap body gauge resolves would kill this route for that model, even though the tiny construction works.

Run with `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/ternary-toys/tied-consumers/experiment.py`. It rewrites the compact [`results.json`](results.json). The calculation uses NumPy and SciPy on CPU.
