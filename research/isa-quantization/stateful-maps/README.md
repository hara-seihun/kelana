# Quantize an observed recurrence, not its entries

Consider `h[t+1] = A h[t] + (u[t],0)` with zero initial state and an observer that reads only `y[t] = h[t,0]`. The complete input/output behavior can survive a large error in every coefficient of `A`. This is a two-state, real-arithmetic statement about *all* input sequences, not a fit to one rollout.

## A four-impulse certificate

Write `A = [[a,b],[c,d]]` and `g[k] = (A^k)[0,0]`. Direct multiplication gives

```
g[0] = 1
g[1] = a
g[2] = a² + bc
g[3] = a³ + bc(2a+d).
```

If `bc != 0`, these four values recover `a`, `bc` and `d`. Every later impulse then follows `g[k+2] = (a+d)g[k+1] - (ad-bc)g[k]` by Cayley-Hamilton. Equality of the first four impulses for two such recurrences therefore certifies equality of *all* observed trajectories under *any* scalar input word. If `bc=0`, `g[k]=a^k`, regardless of `d`; two models with the same first four values still agree forever. This is a finite complete observation test for this specific input/output interface. It reduces structural search from four entries to the triple `(a,d,bc)` when `bc` is nonzero. More data or a different observer changes the certificate.

There is also a direct state witness. For any nonzero `k`, let `E=diag(1,k)` and `A'=E A E⁻¹`. Then `A'E=EA`, `E(1,0)=(1,0)` and `(1,0)E=(1,0)`. Once the recurrent state lives in `z=Eh`, neither an encode nor a decode is needed per step. This is the familiar linear-system similarity gauge, applied here as a quantization search coordinate; the finite impulse test also admits observational matches that do not present a chosen gauge explicitly. We do not claim similarity theory is new.

## A small rate/behavior example

The rational teacher and a same-rate ternary image are

```
A  = [[ 1/2, 1/8], [-2,   1/2]]
A' = [[ 1/2, 1/2], [-1/2, 1/2]],    E = diag(1,1/4).
```

`A'E=EA` exactly. Both have spectral radius `sqrt(1/2)`. In `A'`, four trits `[[1,1],[-1,1]]` and two shared row scales of `1/2` represent the entire transition exactly in encoded state. The state remains two-dimensional: `bc=-1/4` is required to make the second observed impulse zero. One-step rowwise coefficient fitting instead chooses `[[1/2,0],[-2,0]]`, deletes that feedback, and has the wrong long-horizon response despite a much smaller coefficient error.

The control is deliberately strong. The search enumerates **all 81 ternary 2×2 code images**, optimizes each pair of nonnegative row scales from four starts against 128 impulse lags, rounds those scales to FP16, and selects the best evaluated image. It finds `[[1/2,-1/2],[1/2,1/2]]`, which has the same impulse response as `A` and uses the sign-reversed hidden coordinate. This means the similarity coordinate is a way to *find and explain* the code, not an extra advantage over a properly fitted all-code ternary control.

| Teacher | Rowwise coefficient-fit impulse error | All-code impulse-fit error | Teacher radius | Joint-fit radius |
| --- | ---: | ---: | ---: | ---: |
| Rational example | 0.3333333333 | 0 | 0.707107 | 0.707107 |
| Seeded entry perturbation, each in `[-.025,.025]` | 0.2326367372 | 0.0003972560 | 0.674134 | 0.670959 |
| Seeded stable unstructured 2×2 matrix | 0.0000146978 | 0.0000001560 | 0.734375 | 0.734514 |

Each error is the sum of 128 squared scalar impulse differences. For white unit-variance input, it is the output-error variance contributed by those 128 lags. The unstructured teacher's product `bc` is small, so *both* errors are already tiny; the ratio there does not indicate a general prevalence or a worthwhile hardware gain. The exact rational example is designed, while the perturbation is only its local neighborhood. The 81-code sweep is exhaustive over trit assignments but the continuous scale optimization is multistart, **not** certified globally optimal. The local coefficient-fit scales retain ideal real precision, favoring that baseline; the joint-fit scales are actually rounded to FP16. See [results.json](results.json) for the matrices and four observed impulses.

Four trits require seven bits at ideal fixed-block capacity, plus 32 bits for two FP16 scales, for 39 bits of static description versus 64 bits for four dense FP16 entries. Two-bit trit storage instead needs 40 bits; any peel/packing work must be charged. A row-factored scalar lowering of the ternary image uses two row-scale multiplications and two additions; dense row-by-row arithmetic uses four multiplications and two additions. On this teacher the dense coefficients are also cheap dyadic shifts, so the operation count is not an ISA or throughput comparison. No native instruction count, timing or throughput saving is claimed. Source and encoded recurrence have different internal second coordinates; reading that coordinate, supplying input to it, or requiring a conventional initial state needs the corresponding boundary conversion. Tanh or other nonlinear state updates need a separate conjugated nonlinearity and are **not** covered by this linear certificate.

This extends the [recurrent-stability control](../../ternary-toys/recurrent-stability/README.md), which restores a dropped feedback link with an exception, by showing an exact same-rate observed realization without an exception for a different chosen teacher. It complements the [packed-recurrence control](../../ternary-toys/packed-realization/README.md): no per-state table or route fusion is involved here. The proposed search reduction is to screen cheap quantized transitions by `(a,d,bc)` or four impulses before testing trajectories, then account for every observer and any paid state conversion. Against a full-state observer the present exact code does not reproduce the teacher's second coordinate without a decode.

Reproduce from the repository root:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/isa-quantization/stateful-maps/experiment.py
```

The script uses NumPy and SciPy, asserts the rational state intertwining with exact fractions, and regenerates `results.json`. Its numerical experiment uses ideal real matrix operations and FP16-rounded *stored scales*, not emitted FP16 arithmetic or measured ISA instructions.
