# A carried residual label must pay for the next skip

**Decision:** no nonstandard two-block residual label earns a complete error/bytes/work advantage from the construction examined here. There is a useful exact obstruction stronger than the previous one-block radial probe: **the first projected norm observation and the next full norm after an additive residual update jointly separate every original residual state**, provided the update depends only on the first observation. Therefore a lossless shared label cannot merge states just because their first norm projection collides. A radius-plus-signed-direction code can carry the missing state approximately; on the genuine Qwen layer-0 skip it is precisely ordinary per-token int8 activation quantization with a paid FP16 scale. It halves transient state bytes but adds preparation, decoding and re-encoding and changes no model weight bytes. We do not mislabel this known tradeoff as a new quantizer or claim dominance without a native two-block reader.

## Two observations undo a projected quotient

Let `t` be the full residual state (the entire window if attention couples tokens), `o=first(t)` the possibly projected/normalized first consumer, and `t⁺=t+A(o)` the next residual. The update `A` may contain an arbitrary nonlinear attention program shared across the window. Let `second(t⁺)` be its next *full* RMSNorm output. If `second` is injective on reachable residuals, then the pair

`( first(t), second(t+A(first(t))) )`

is injective: equality of first outputs makes both updates `A` identical; equality of second outputs makes their updated residuals identical; cancelling the common update recovers the original `t`. [`TwoBlock.lean`](TwoBlock.lean) proves this for arbitrary types with an injective second observer and an update injective in its state at fixed first observation, and proves that **any exact code serving both observations must be injective**. It does not assume decoding the source branch, Q/K/V or any intermediate vector. The next Qwen block's actual post-attention full RMSNorm with positive epsilon and nonzero gamma is injective in ideal reals: with `y=Γ⁻¹Nε(v)` and `q=||y||²/d<1`, its inverse is `v=y sqrt(ε/(1−q))`. This analytic premise is explicit rather than smuggled into the Lean generic theorem. BF16-rounded norm is not injective; the theorem is an ideal-real exact-map statement, not a lower bound on lossy code rates.

**Closure/cost witness.** Even before the second observation, a finite ray dictionary need not close under one simple branch. States `(r,0)` with `r=1,2` share the initial direction, but adding the constant branch `(0,1)` produces `(1,1)` and `(2,1)`, which have different directions (Lean checks the unequal slopes). For arbitrary positive `r`, this yields arbitrarily many next directions. Either add direction descriptions/IDs, compute a fresh direction and norm, or keep another coordinate representation. On this particular example a Cartesian `(r, phase)` program is cheaper than a polar dictionary: retain the scalar `r` and an implicit second coordinate `0→1`, with no per-radius direction table. A direct two-state transition table is also competitive on the tiny finite witness. It would be invalid to present that toy as a polar compression win; its value is the exact closure condition a proposed program must satisfy. The injectivity theorem does **not** forbid reversible encodings, coefficient sharing across several blocks, low-dimensional invariant subspaces or controlled approximation.

## The executable carried state and its ordinary control

A plausible carried representation for width 1,024 is `q_i∈int8` for every coordinate and one FP16 per-token scale `s`; decode `t̂_i=sq_i`. The source state is BF16 (2,048 transient bytes/token); this representation stores **1,026 bytes/token**, saving 1,022 bytes at a boundary. Here codes are chosen by the standard per-token max-absolute scale `max|t_i|/127` and rounded/clipped to `[-127,127]`. A separate conventional control uses the *same codes* and refits the scale by least squares before FP16 storage. This is familiar activation quantization, not a new radius/direction ISA. Neither pays model-specific stored bytes, and the BF16 direct-state control has no quantization error or scale metadata.

To consume Q/K/V without materializing normalized float coordinates, the exact ideal-real map **of the decoded code** can be written

`W Nε(sq) = [s / sqrt(s² mean(q_i²)+ε)] · (W Γ q)`.

This carries the direction label directly into the projection and pays one integer-square reduction, one scale/square-root calculation and a scalar on every projected output, as well as the dot itself. Source Q/K/V weights are BF16; an int8-input-native mixed dot or separately quantized/folded `WΓ` image would require an actual lowering and its bytes. At the next skip addition `sq+A(...)`, a general noncollinear `A` still needs all 1,024 coordinates (or an equivalent fused per-coordinate update) and must prepare another code and scale if the next block also carries this representation. Initial encoding, both updates and final decoding cannot be charged zero. Two boundaries save at most 2,044 transient state bytes/token against BF16 before accounting for code buffers, while adding at least two max reductions, two 1,024-coordinate divide/round/clamp encodings, and the coordinate addition/renormalization work. These are logical operation counts, **not a native timing lower bound**. The model's MLP/QKV static weights are unchanged, so no static effective-BPW gain is established. A competent activation-quantized packed scalar reader would use the same factorization and is the relevant control; an enormous sample-indexed direct-transition table is not.

[`screen.py`](screen.py) places this ordinary code at a **genuine** source layer-0 skip. Its owned [capture](/path/to/workspace/data/kelana-subbit/full-model/mlp-quantized-producer-capture.json) records `*_teacher_post` as the BF16 residual after source layer 0, not the post-attention normalized MLP input; train has 2,048 and previously inspected validation 1,024 positions. Using original BF16 layer-1 gamma, `ε=10⁻⁶`, and all 4,096 layer-1 Q/K/V projection rows, the frozen boundary scores are:

| Conventional state representation | Validation state relative RMS | Validation next full norm RMS | Validation all-QKV RMS |
| --- | ---: | ---: | ---: |
| BF16 source residual, 2,048 B/token | 0 | 0 | 0 |
| signed int8 + FP16 max scale, 1,026 B/token | .026055 | .032555 | .024323 |
| same codes + FP16 least-squares scale, 1,026 B/token | .026032 | .032555 | .024323 |

Train numbers and source/capture SHA-256 receipts are in [`results.json`](results.json). Refitting one radius scarcely changes either norm or QKV: direction-code error dominates at this boundary. The code does **not** replay the full second attention update and second MLP or model loss; its measured row response cannot be promoted to a two-block quality point. This screen decides that this simple carried label is no more than a paid, lossy transient activation format. It leaves open a truly coupled program that reuses packed labels in a native reader and amortizes re-encoding over multiple consumers. Such a proposal needs a non-Cartesian closure/invariant or a demonstrated cheaper complete two-block implementation against ordinary int8 activation and packed-weight controls; merely adding a radius field is insufficient.

## Reproduce and evidence level

```sh
cd /path/to/workspace/projects/kelana
lean research/isa-quantization/two-block-residual-label/TwoBlock.lean
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/two-block-residual-label/screen.py
```

Each CPU call completes under one minute. The theorem is exact conditional structural mathematics; the measured errors are FP32/ideal RMSNorm on frozen BF16 source states; neither proves a native ISA advantage, a full-model score or a family-wide approximation bound.
