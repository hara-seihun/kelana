# Reachable quotients in a two-key attention recurrence

The interesting failure here is not that a ternary matrix is inaccurate. It is that the **best coefficient-fit ternary matrix destroys a distinction that the normalized consumer needs**, so no downstream decoder can repair it. A worse-looking matrix preserves that distinction and produces the complete two-step response exactly. The construction also shows the limit: one extra residual branch that reads the common logit makes the quotient invalid.

## Finite model

Enumerate all 27 inputs `x=(x0,x1,h)` in `{-1,0,1}³`. The two full-precision key logits are

```
a = 2*x0 + x1 + 2*h
b = x0 + 2*x1 + 2*h
```

A two-key normalized attention with values `(1,0)` returns `p1=sigmoid(a-b)`. Its residual state is `h1=h+p1`. A second attention uses query `q=1+1[h1>1/2]`, returns `p2=sigmoid(q*(a-b))`, and leaves `h2=h1+p2`. Both `p1` and `h2` are required observations. The second query depends on the first answer, so the test actually composes a gate, normalization and residual. Calibration weight is 60% on `x0=x1` with uniform `h`, and 40% uniform over all 27 inputs. Exactness claims cover every input, not just this distribution.

The full logits distinguish 27 states. Their normalized consumers only need `(d=a-b=x0-x1,h)`, which has 15 reachable states. This quotient is sufficient throughout the two-step schedule: `(d,h)` determines `p1,h1,q,p2,h2`, while the pair `(p1,h1)` distinguishes all 15 quotient states. Neither original logit is reconstructed. This is a fixed attention-region interface, not a quotient stable under arbitrary model operations.

## Quantize the producer, then inspect the fibers

The search enumerates all `3^6=729` ternary code matrices, and analytically optimizes a nonnegative *shared* real scale for each code matrix against coefficient squared error. The winner has all six codes equal to one and scale `5/3`. Its squared coefficient error is only `4/3`, but both produced logits are equal. For instance `(-1,0,-1)` and `(0,-1,-1)` have identical quantized logits and identical `h`, while their true differences are `-1` and `+1`. No decoder downstream of this quantized producer can recover their first attention probabilities. The producer image shrinks from 27 states to seven. Its calibration-weighted final residual absolute error is 0.167660.

Ordinary shared-scale-two rounding keeps codes `[[1,0,1],[0,1,1]]`. It retains the difference but doubles it; its final error is 0.063207. Searching exact-difference ternary producers, and breaking ties by coefficient error, chooses **those same codes at scale one**. The coefficient squared error rises from two for ordinary rounding to six, while both attention outputs and the entire residual recurrence become exact on all 27 inputs. The calibration-weighted error is zero. It has 19 producer states; the consumer still needs only 15 `(d,h)` states. An even sparser `[[1,0,0],[0,1,0]]` works but has coefficient error 12. The exhaustive exact-difference search considers scales `1/2` and `1`, the only positive scales possible because the target difference coefficient is one and two trits differ by at most two.

There is an equally strong consumer-side control. Keep the ordinary scale-two image and halve both attention query temperatures. That also gives zero error, with no changed trits or weight scales. It requires editing every consumer of these scores. For the coefficient-fit winner, even such a correction cannot recover the lost distinction. The result supports joint producer-consumer scale selection, **not** a claim that these particular ternary codes are novel or that the scale-one image is uniquely optimal.

| Producer and consumer | Coefficient SSE | First probability MAE | Final residual MAE | Exact inputs |
| --- | ---: | ---: | ---: | ---: |
| Best coefficient SSE of all 729 codes, scale 5/3 | 1.333333 | 0.074926 | 0.167660 | 9/27 |
| Ordinary rounding, shared scale 2 | 2 | 0.035617 | 0.063207 | 9/27 |
| Same rounding, both query temperatures halved | 2 | 0 | 0 | 27/27 |
| Minimum-coefficient-error exact producer, shared scale 1 | 6 | 0 | 0 | 27/27 |

No extra codes or side table enter the scale-one arm. Each producer has six trits and one shared FP16-representable scale. Radix-243 packing requires two bytes for these six trits plus two bytes for the scale, four bytes before container/layout overhead; the coefficient oracle's `5/3` is an unrounded real scale, an intentionally favorable control. The residual `h` already exists at the attention interface. Online arithmetic still includes projection, subtraction and both softmax evaluations. This is an exact-quality result, not a packed-throughput saving; the 15-state quotient is an information count, not a free hardware encoding.

## Where it breaks

If the next residual branch also reads `a+b`, inputs `(0,0,0)` and `(1,1,0)` have the same `(d,h)=(0,0)` but different sums, zero and six. No continuation using only the 15-state quotient can implement that branch. The exact construction depends on the logits having **only normalized consumers** and on preserving the live residual state. Additional attention heads need their own difference constraints, and quantizing the producer of `x` may change its reachable domain. Neither extension follows from this 27-input example.

The next transfer test should capture one actual Qwen attention head's logits with earlier layers quantized, fit a shared key/query scale or codes to *attention probabilities and residual output*, and compare it to coefficient/GPTQ fitting and to an explicit query-temperature correction at the same bytes. Include all queries and positions served by the edited keys; a shared softmax-invariant offset for one query need not be invariant for another. Select on held composed loss rather than an isolated softmax error.

Run `python3 research/ternary-toys/reachable-quotients/experiment.py` from the repository root. It rewrites [results.json](results.json) after enumerating the coefficients and all reachable continuations. No GPU or external data is needed.
