# Finite-grid decisions do not require a floating division

The first complete [metric K-flush implementation](../kivi-metric-native-flush/README.md) computes a continuous quadratic vertex and rounds it, paying4,096 FP64 quotients per32-key chunk. Its output is only one of16 codes. The finite choice can instead be characterized by **ordered adjacent-cost signs**, without ever constructing the quotient. This is a standard discrete convex quadratic fact, not a new optimizer or evidence that the resulting hardware map is cheap.

This study derives that decision contract and replays it with **exact integers** on the already-saved first and last32-key chunks of all twelve source windows. All98,304 coordinate decisions reproduce the frozen metric donor bytes exactly. The resulting exact thresholds need up to **74 magnitude bits** on this panel: replacing floating division is not the same as obtaining a free32-bit instruction.

## Adjacent differences characterize the global finite minimum

In the [low-rank code-update notation](../low-rank-code-update/README.md), current code c has gradient g, positive curvature h and stored positive affine step b. Up to a constant, candidate code j has cost

```
f(j) = h b² (j-c)² + 2 b g (j-c).
f(j+1)-f(j) = b T_j,
T_j = 2g + hb [2(j-c)+1].                              (1)
```

The thresholds are strictly increasing: `T_k-T_j=2hb(k-j)>0` for k>j. On codes0…K, j is a global minimum **if and only if** its left threshold is nonpositive (unless j=0), and its right threshold is nonnegative (unless j=K). `Kelana/GridThresholdDecision.lean` derives the finite adjacent difference, strict ordering, both monotone walks and this iff statement for arbitrary rational h,b,g,c with h,b>0. It also proves exact-zero neighboring ties. The proof does not assume the final minimum inequality.

For codes0…15 there are fifteen ordered boundaries. Binary selection needs at most **four ordered sign comparisons**, plus the final zero/tie test and endpoint/control logic. The first nonnegative boundary gives the left minimizer; if it is exactly zero, select the even of its two adjacent codes to match nearest-even. The even-tie implementation and four-comparison decision tree are analytic/executable scope, not asserted as part of the Lean proof. At b=0 every code represents the same coordinate; retain the donor code instead of dividing by zero.

This keeps the same one-coordinate-at-a-time Gauss–Seidel recurrence. It removes the continuous quotient from the decision specification, **not** the128-step serial dependence, the rank-gradient work, key source preparation or nibble packing.

## Dyadic arithmetic on the actual stored metric

The frozen paid FP16 U,D are dyadic. On this metric use common integer labels

```
U = U_int / 2^24,
D = D_int / 2^48,
e = e_int / 2^E,     b = b_int / 2^E.
s_int[r] = sum_d U_int[d,r] e_int[d],
h_int[d] = D_int[d] + sum_r U_int[d,r]^2,
g_int[d] = D_int[d] e_int[d] + sum_r U_int[d,r] s_int[r].
```

Here E is the common exponent of the actual source BF16 words and stored affine fields in the available source chunk. The exact threshold has positive denominator2^(48+E), so its sign is the sign of

```
2 g_int + h_int b_int [2(j-c)+1].                       (2)
```

After selecting j, update `e_int[d] += b_int(j-c)` and `s_int[r] += U_int[d,r] b_int(j-c)`. No floating arithmetic or rounding is needed in this recurrence. Existing min/max and initial-code generation are **not redefined**: the exact replay starts with the original saved KIVI codes and FP16 fields, then checks the new metric assignment against the saved metric donor.

`exact.py` uses Python unbounded integers. It reads only the owner's pre32/pre256 binary snapshots and timed K-event logs, checks their original manifest hashes, and uses the fixed paid metric SHA. It does not reproject source tokens, fit a candidate, regenerate captures or rescore attention. Every binary decision is also checked against all16 **exact integer objective differences**; the full mode recurrence and each final token energy are independently recomputed. Final2,560B event bytes must equal the immutable metric donor, including untouched FP16 fields.

## Saved-source receipt

The subset is chosen by available original snapshots: the first and last32-key chunks in every8train/fourheld window, **24 of96 chunks**, not a claim about every possible producer input. The prior C++/FP64 encoder matched all96 chunks; this new exact-integer receipt has the smaller explicitly stated scope.

- **98,304** exact coordinate choices; **393,216** binary sign comparisons.
- **61,440 compared output bytes**, all identical to the metric donor.
- **7,030** codes differ from original scalar KIVI assignments.
- No exact-zero boundary occurs in this selected source panel; the generic tie rule still remains part of the program.
- Source/field common exponent E ranges16…24.
- Maximum observed **magnitude** widths: U25bits, D44, curvature50, source error29, mode45, gradient67, curvature×step69, threshold74. A signed storage lane requires its sign in addition to these magnitude bits.

Each per-chunk JSON contains hashes, exact energy numerators/denominator exponent, threshold statistics and equality receipt. `aggregate.py` combines completed receipts without rerunning source work. Each exact chunk takes roughly a tenth of a second on the current CPU; that Python wall time is not a comparative encoder benchmark.

## What still costs work and storage

Four sign decisions may be implemented in floating arithmetic with separately justified signs, or in exact wide integer arithmetic on a bounded domain. This study does neither native lowering. An FP64 threshold expression has different rounding from the original quotient; exact rational equivalence alone does not license attributing the saved image to it. The observed integer widths do not cover arbitrary BF16 source exponents or values, and no all-input128-bit guarantee is claimed.

For the observed metric, an expanded integer U table in signed32-bit fields would use4,096B, D in signed64-bit fields1,024B, plus an optional precomputed64-bit curvature table1,024B: **6,144B prepared data**, versus the original2,304B FP16 metric. Loading/converting original fields on demand trades that storage for work. Eight45-bit modes need wide register state; multiplying25-bit factors by45-bit modes and comparing74-bit thresholds requires multiword operations or a suitable wide instruction. Intermediate carry bounds, source exponent extraction, packing, compiler code size/register allocation and synchronization are not supplied by a semantic relabeling.

The precise conclusion is therefore **an exact division-free decision map and preserved source bytes**, not a speedup, a smaller complete encoder, or a new attention-quality point. The same code family still needs a better complete realization to overcome the first encoder's serial/register cost. A stronger named SKVQ comparator is being investigated separately rather than tuning the metric's rank or source objective.

```sh
python3 research/isa-quantization/grid-threshold-decision/exact.py train 0 32
# Individually: train0..7 and held0..3, at prefix32 and256.
python3 research/isa-quantization/grid-threshold-decision/aggregate.py
lake env lean Kelana/GridThresholdDecision.lean
```
