# Direct consumers of packed values

Goal: replace `packed projection → separate gate/up → activation × up` with a
consumer of the packed projection itself. Recover the required output, not every
intermediate that the original program named.

The main-thread proofs are in [DirectConsumer.lean](../../../../Kelana/DirectConsumer.lean).
They establish exact integer maps and carry conditions. They do not establish a
Bonsai speedup or native floating WMMA accuracy.

## A product without either operand

Let `R = 65536`, `p = g + R*u`, and `g,u ∈ [-127,127]`.

```
p² = g² + 2R*gu + R²*u²
q = MUL_LO_U32(p,p)
answer = BFE_I32(q,17,15)
```

The high square disappears modulo 2³². The low square cannot reach the product
field. The product fits signed 15 bits. Two instructions produce `gu`, without
reconstructing `g` or `u`.

`product_word_correct` proves this using actual `BitVec 32` multiplication,
shift, width truncation and signed interpretation. It has no floating arithmetic
hypothesis. `product_i24_correct` also proves that the faster signed-24 operand
multiply suffices on this domain. The domain fits that operand window; it does
not exhaust all inputs that fit. `relu_correct` adds one observation of the gate sign to select
`max(g,0)*u`. Neither theorem calls SiLU equal to ReLU.

This radix is too wide for the current FP16 paired-weight WMMA producer.
The consumer's advantage cannot be credited to the whole FFN without an
inexpensive producer. Encoding already computed gate/up values would put their
computation back into the cost.

## Carry through the downstream projection too

For signed downstream weights `c_i`, accumulate the *squares of packed words*:

```
S = Σ c_i*p_i²   modulo 2³²
L = Σ c_i*g_i²
T = Σ c_i*g_i*u_i
S = L + 2R*T + R²*Σ c_i*u_i²
answer = BFE_I32(S + R,17,15)
```

If `-R ≤ L < R` and `-16384 ≤ T < 16384`, the answer is exactly `T`.
The bias prevents a negative low-field sum borrowing from the product field.
The high square sum has no size restriction.

There is **one extraction per final output**, not one per hidden unit. The
program need not construct gate, up, or the individual hidden products.
`downstream_correct` proves the general condition. `downstream_128` proves it
for up to 128 terms, ternary `c_i`, and `g_i,u_i ∈ [-7,7]`.
[The full-row carry study](CARRY.md) tightens the 32-bit worst-case span to 334 terms, gives a 335-term counterexample, and proves that one 64-bit extraction suffices for all 17,408 terms even with signed A8 gate/up integers. The native producer, SiLU and quantizer are not part of that integer theorem.

[check.py](check.py) also exercises a complete bounded composition: seven ternary
inputs, two 128-row ternary projections prepared as packed integer weights, a
bilinear or ReLU product, and a 16-row ternary down projection. The packed path
never constructs the individual hidden values. This is a correctness example,
not a tensor-unit performance claim. Its prepared weight integers are wide.

## General rule: evaluate an antiderivative on the carrier

For every integer polynomial `P`,

```
P(g + R*u) = P(g) + R*u*P'(g) + R²*H
```

for some integer `H`. Thus a program can compute `u*f(g)` directly by choosing
`P' = f`, evaluating `P(p)` modulo 2³², and extracting the middle coefficient.
A final scalar factor can absorb rational polynomial coefficients when an
integer multiple has been used.

This is bounded dual-number arithmetic. It is not an isomorphism between the
32-bit word ring and a dual-number ring: carries from `P(g)` matter. The proof
retains them explicitly.

`packed_polynomial` proves the identity for every coefficient list.
`word_polynomial` proves that wrapping at every Horner multiply/add has the same
result as reducing once at the end. `word_derivative_correct` gives the direct
consumer when both `P(g)` and `u*P'(g)` fit signed 16 bits. Add 32768 before the
final signed extraction to center the low-field remainder.

A concrete nonlinear case is

```
P(p) = 480p² + 80p³ - p⁵
P'(g) = 960g + 240g² - 5g⁴
```

For `g ∈ [-3,3]`, `u ∈ [-7,7]`, all bounds hold. The extracted result divided by
3840 is

```
u * (g/4 + g²/16 - g⁴/768)
```

which is the quartic Taylor approximation to `u*SiLU(g/2)`.
`silu_polynomial_small` proves the integer computation, not equality to SiLU.
The construction demonstrates a nonlinear direct consumer, with no separate
operand recovery. Whether its instruction mix beats reconstruction is a native
component question. Whether its precision suffices is a separate model question.

### Use only the part of the instruction result the consumer observes

Native 32-bit multiplication costs more than signed-24 multiplication on this
part. This is a representation decision too. Signed-24 multiplication always
preserves a product modulo 2²⁴, even when the full operands exceed its signed
range. Upper-bit disagreement is irrelevant to a consumer of the lower 24 bits.

`native_polynomial24` proves that an entire polynomial can be evaluated with
signed-24 multiplies and ordinary 32-bit destinations, with no explicit mask
between stages, while preserving its low 24-bit result. There is **no bound on
intermediate polynomial values**. `native_derivative24_correct` then gives a
12-bit low field and 12-bit derivative field. Both final coefficient bounds are
explicit. Finding a useful SiLU approximation inside that budget remains open.

This is a concrete case where demanding that each instruction reproduce the
whole intermediate integer would rule out a valid cheaper computation.

## What information may disappear?

The existing `Composition.factors_iff` proves that a direct consumer on reachable
encodings exists exactly when any two inputs merged by the encoding have the
same required output. Existence says nothing about instruction cost.

For SiLU, `gu` alone is insufficient. The pairs `(1,1)` and `(-1,-1)` have the
same product but different SiLU-products. `product_only_insufficient` states
this for any gate factor taking different values at ±1. One can still discard
`u` after producing `gu` if the needed gate factor remains observable. Preserving
that factor does not require preserving a full FP32 gate tensor.

## Real-model quality reconnaissance

[quality_probe.py](quality_probe.py) applies candidate nonlinear consumers to
eight captured native gate/up rows in layers 0 and 10, then propagates their
errors through the deployed-shaped sign/Hadamard, int8 quantization and down
projection in float64. This is one-layer perturbation analysis, not native
whole-model acceptance. Raw results are [layer 0](quality-layer00.json) and
[layer 10](quality-layer10.json).

| Consumer | Layer 0 residual relative RMS | Layer 10 |
|---|---:|---:|
| ReLU product | 13.26% | 9.51% |
| `gu/2` | 9.89% | 5.00% |
| Quadratic SiLU Taylor | 2.37% | 1.29% |
| Quartic SiLU Taylor | 0.836% | 0.989% |
| Sixth-degree SiLU Taylor | 0.331% | 0.854% |
| Sixth-degree fixed-interval fit | 0.106% | 0.150% |

The last fit uses a fixed grid on `[-3.5,3.5]`, not these activation samples. Its
coefficients are floating numbers; this is **not yet a carry-safe packed
implementation**. The inexpensive proven seven-level gate toy is much too coarse
on these samples. Even exact SiLU evaluated on a uniform 15-level gate grid over
`[-3.5,3.5]` gives 8.30% and 3.98% residual error. A good activation approximation
and a cheap sufficiently precise carrier must be found together.

Most gates are small, but this does not make the linear approximation safe.
Large gates correlated with large up values dominate enough energy to make that
shortcut inaccurate.

## Remaining FFN obligations

- Produce a suitable carrier directly from the projections. Existing blockwise
  gate/up scales differ, so the current packed block results cannot simply be
  added as if they shared one radix and scale.
- Find a polynomial/basis and numeric representation whose approximation,
  coefficient precision and carry margins fit the useful instruction widths.
  The theorem does not restrict discovery to monomial coefficients or 32 bits.
- Preserve or deliberately replace the hidden per-block amax quantizer. It is
  nonlinear and cannot be commuted through the down matrix by distributivity.
- Charge all input-dependent preparation, memory traffic and consumer work.
  Weight preparation alone is free. Compare matched pipelines and whole-model
  quality before claiming a Bonsai improvement.

The result so far is a proved family of programs that skip intermediate
reconstruction. It removes the assumption that every packed channel must be
separated before further useful work. It does not remove the numerical and
hardware constraints of producing and consuming that representation.

## Native experiment

The [native component experiment](native/README.md) compares exact consumers of
the same packed inputs, including signed-24 versus general 32-bit multiplication,
gate-sign observation, the polynomial, and extraction after a downstream sum.
It measures components, not a complete Bonsai inference implementation.

After repairing the producer comparison and recording clocks, 20 randomized
matched rounds give 1.969× for the direct product consumer, 1.223× for the
ReLU-product consumer, and 1.180× for the bounded downstream-sum component.
The measured packed quartic loses 1.44× because this particular implementation
uses two slow 32-bit multiplies.

The first producer proxy was wrong: it squared a duplicated channel rather than
packing two separate operands. The repaired three-instruction pack-and-consume
sequence is cheaper than the four-instruction decoder, but remains 2.74× the cost
of simply multiplying values that are already separate. A suitable producer need
not be free, but no complete FFN producer/consumer speedup was measured here.

Clock ramping also mattered. An initial run started at 0.625 GHz and reached
2.6 GHz later. The retained warmed run records 2.678–2.833 GHz, all timing samples,
round order and visible GPU clients. The existing server and browser were not
stopped, so the results describe the recorded shared-machine conditions.

## Reproduce

```
lake build Kelana.DirectConsumer
python3 research/ffn/batched/direct-consumers/check.py
OPENBLAS_NUM_THREADS=4 python3 research/ffn/batched/direct-consumers/quality_probe.py \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0/layer00 \
  --out research/ffn/batched/direct-consumers/quality-layer00.json
```
