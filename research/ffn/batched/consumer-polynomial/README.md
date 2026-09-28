# A packed-half nonlinear consumer

The proposed representation keeps pairs of gate values and pairs of up values in
native FP16 lanes, then evaluates SiLU-times-up with packed arithmetic. Adjacent
outputs of the same kind share an operation, so the representation need not
expand into two persistent FP32 arrays at the consumer. This directory owns the
activation approximation and its full-model quality intervention. It does not
measure a half-precision projection accumulator.

## Coefficients and operation order

[fit.py](fit.py) fits the even part of SiLU on a fixed interval, preserving the
exact odd term `g/2` and the value at zero. It minimizes the maximum absolute
error on a 4097-point grid, rounds coefficients to half precision, then makes
small coefficient adjustments against all binary16 gate values in the interval.
[fit.json](fit.json) records the coefficients and errors for degrees 4, 6 and 8.
No model activations enter the fit.

For the degree-eight half consumer:

```
z = half(g*g)
t = half_fma(z, -0.000026285648345947266, 0.0010166168212890625)
t = half_fma(z, t, -0.0176849365234375)
t = half_fma(z, t,  0.246826171875)
s = half_fma(z, t, half(0.5*g))
h = half(s*up)
```

Use the exact native SiLU expression when the half-rounded gate has magnitude
greater than 3.5, then round that result to half. This is an explicit piecewise
consumer; extrapolating the polynomial outside its fitted interval is not the map.
[consumer.hpp](consumer.hpp) implements this arithmetic with native half intrinsics.

Across every finite binary16 input in `[-3.5,3.5]`, the host half-FMA simulation
has maximum absolute activation error 0.0030233 for degree eight and 0.0068897 for
degree six. The reference uses float64 `exp`; the simulation rounds float64
products and sums to half. This enumeration is not a formal real-arithmetic bound
or a proof of every native floating instruction.

## Native full-model quality

The existing [quality intervention](../lossy/README.md) now accepts an optional
fourth configuration field: `bits:first_layers:stochastic:consumer`.

| Consumer | Operation |
|---:|---|
| 0 | Deployed SiLU-times-up |
| 1 | Half-rounded gate/up, native SiLU, half activation and product |
| 2 | Half degree-six polynomial, exact SiLU outside the interval |
| 3 | Half degree-eight polynomial, same tail rule |
| 4 | Float32 degree-eight polynomial, exact native SiLU outside the interval |

The intervention rounds *completed FP32 projection outputs*. It does not simulate
rounding after every scale-block accumulation. Production Bonsai source and all
attention/recurrent operations remain unchanged. The selected FFN hidden chunks
are replaced in place before the unchanged sign/Hadamard/quantizer stage.
Separate counters validate the number of modified quantizer and consumer chunks.

[quality-a8.json](quality-a8.json) scores 128 next-token distributions from two
64-token prompts, modifying all 64 FFNs. The repeated reference is bit-identical.

| Consumer, A8 activations | Mean KL to native model | Mean TV | Argmax changes |
|---|---:|---:|---:|
| Half boundary, exact SiLU | 0.0001605 | 0.006041 | 0/128 |
| Half degree eight | 0.0001707 | 0.006239 | 1/128 |

[quality-pilot.json](quality-pilot.json) is the earlier 32-position experiment,
including degree six and the float32 polynomial. It is not additional held-out
acceptance data.

### Four-bit quantization changes the comparison

[quality-a4.json](quality-a4.json) uses direct A4 quantization at both FFN
boundaries. [quality-a4-matched.json](quality-a4-matched.json) uses that A4
computation itself as the reference, with the same tokens and model state reset.

| Consumer | KL from original model | KL from matched A4 model |
|---|---:|---:|
| Deployed SiLU, A4 | 0.015977 | 0 |
| Half boundary, exact SiLU | 0.012187 | 0.025179 |
| Half degree eight | 0.014589 | 0.029072 |

A small local consumer change can alter later coarse quantization decisions.
The two approximations can each stay comparably close to the original model
while differing substantially from each other. Lower KL on these short prompts
is not evidence of a quality improvement, and the differences between the first
column's numbers are not an additive error budget.

No model-quality threshold has been accepted. These are short teacher-forced
sequences used during development, not long-context or task-level acceptance.
There is no throughput claim here. A kernel changing the projection accumulation
must account for that additional error separately.

## Range comes from the producer, not the storage type

A gate tensor stored in FP32 is not an arbitrary FP32 input to this region.
In real arithmetic, RMS normalization gives norm at most `sqrt(D)`. Multiplying
by the folded norm diagonal contributes at most `max|k|`; the normalized Hadamard
preserves the Euclidean norm. Nearest quantization with 7 levels in each
128-element block has error norm at most `sqrt(128)/(2*7)` times that block's
input norm. Therefore each projection row has the token-independent bound

```
B_i = ||W_i||₂ * max|k| * sqrt(D) * (1 + sqrt(128)/14).
```

Cauchy–Schwarz also gives this bound for the sum of absolute block partials,
which is the quantity used in accumulation-error analysis. This does not assume
that rounding errors cancel.

[range_bound.py](range_bound.py) computes row norms from every real scaled ternary
row, not sampled activations. [range-bound.json](range-bound.json) records both
layers. Maximum gate/up bounds are 191.71/135.07 in layer 0 and 311.63/185.49 in
layer 10. A static power-of-two row gauge `s_i`, chosen so `B_i/s_i ≤ 30000`, is
mostly `2^-8` and `2^-7`. Accumulating with row scales divided by `s_i`, then
restoring it at the consumer, can improve the numerical range of half arithmetic
without choosing the gauge from calibration samples.

These are real-map bounds. Native coefficient rounding, half accumulation,
denormal behavior and the floating implementation of normalization still need
their own margins. The range scan is not an IEEE overflow certificate.

## Reproduce

```
OPENBLAS_NUM_THREADS=2 python3 research/ffn/batched/consumer-polynomial/fit.py
python3 research/ffn/batched/lossy/run_quality.py --tokens 64 \
  --configs 8:0:0,8:64:0:1,8:64:0:3 \
  --out research/ffn/batched/consumer-polynomial/quality-a8.json
python3 research/ffn/batched/lossy/run_quality.py --tokens 64 --direct --down \
  --reference 4:64:0:0 --configs 4:64:0:0,4:64:0:1,4:64:0:3 \
  --out research/ffn/batched/consumer-polynomial/quality-a4-matched.json
```

The runner includes the shared consumer header in its source fingerprint and
uses the research GPU lock. `--reference` changes the numerical reference, not
the prompts. Omitting it retains the original deployed-model reference.
