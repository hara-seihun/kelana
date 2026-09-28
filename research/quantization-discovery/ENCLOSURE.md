# A source-aware floating-point producer enclosure

The [producer-domain investigation](PRODUCER.md) left a concrete missing component: carry a declared input domain through the actual Bonsai floating-point producer. This round implements that component from the upstream quantized operand to the hidden quantized operand. It does not assert a global workload domain or change inference serving.

## Result

For layer 0, captured row 0, fix the 5,120 upstream int8 codes and allow each of the 40 FP32 activation scales to vary in an explicit interval approximately one part per million around its captured value. The resulting Cartesian scale set contains exactly

```
117954418633593662093109477384746565771381855010986328125
```

tuples of binary32 values, about `1.18e56`. These are admitted scale tuples, not a count of reachable full-model histories.

The enclosure proves that every input in that contract produces the **same first 128 hidden int8 codes**. The hidden scale may change. Exact assignment within the existing codec menu then replaces the real 128-trit down-projection block with **36 meaningful bits, padded to 40 bits**, including the original FP16 weight scale. Its integer dot product is unchanged throughout the contract. Keeping the same scale and surrounding accumulation tree preserves that block's contribution at the existing consumer boundary.

The packet is `e521094000`. The solver needs 88,404 transitions and at most 2,263 states, and certifies the 36-bit minimum within its menu. It uses the same exact frontier DP as the preceding round, with a scalar hidden-code response and a penalty greater than the literal upper bound, so a nonzero integer error cannot be optimal.

This is a conditional semantic result, not net model compression. A literal runtime guard stores 5,120 code bytes plus 320 bytes of scale endpoints. The packet plus that guard is **5,445 bytes**, larger than the original **28-byte** weight block. No guard sharing, amortization or workload coverage is credited. The guarded packet is not installed in the inference engine.

## The input contract is executable

`guard_membership` in [fp_enclosure.py](fp_enclosure.py) checks:

- the live operand contains exactly the declared 5,120 int8 codes;
- the 40 live scales are actual finite positive FP32 values;
- each scale's bit pattern lies between its recorded endpoints.

A SHA-256 in the evidence identifies data; the guard itself compares the full code vector. It does not turn hash equality into a mathematical equality premise. Out-of-domain inputs are rejected. No approximate comparison is used.

The scales share one exact dyadic lattice. The evaluator expresses each as a center plus a power-of-two step times a bounded integer coefficient. This retains 40 common generator labels throughout the calculation. Its interval contains every binary32 value between the endpoints, including when an endpoint crosses a binade.

The input boundary is after RMS normalization and upstream quantization. It supplies their actual outputs, not a proof about raw residuals or arbitrary prompts. Extending the contract to those earlier stages remains separate work.

## The source arithmetic matters

The [floating-point audit](FLOAT-CONTRACT.md) establishes the contract from the captured Bonsai source, kernel descriptors, compiler lowering and AMD's local RDNA 3.5 ISA manual. It corrected an earlier simplification in our source notes.

- Gate and up each use **eight waves of five FMAs**, followed by a seven-add reduction. They are not one sequential 40-FMA chain.
- `__expf(x)` is a rounded multiplication by the binary32 `log2(e)` constant followed by AMD `V_EXP_F32`. That instruction has a documented one-ULP bound and flushes denormals. It is not ideal `exp` rounded once.
- Ordinary divisions lower through the high-precision division sequence and implement binary32 nearest-even division. The bare reciprocal instruction's error bound is not the source division contract.
- The Hadamard contains ten rounded add/subtract stages and the final multiplication by `1/32`.
- The quantizer computes `RN32(127/m)` and `RN32(m/127)` separately, then rounds products and converts them to integers with ties to even.

The implementation follows these boundaries. It rejects unsupported ranges, including nonfinite ordinary intermediates, native-exp arguments outside `(-80,80)`, and hidden maxima outside its positive normal-scale range. The first implementation does not handle an identically zero hidden block or the transcendental overflow/underflow transitions.

## Keeping correlations through rounding

Each scalar is represented as

```
v = center + sum_j generator_j z_j + error,
|z_j| <= radius_j,
|error| <= residual.
```

The generator coefficients and centers are exact binary64 values defining the enclosure. Directed binary64 bookkeeping pays for arithmetic error in constructing them. Source binary32 rounding is a separate residual, bounded by `2^-24 * magnitude + 2^-149` for ordinary finite IEEE operations. Shared labels survive the gate/up calculations and Hadamard; only the unknown rounding contributions enter the independent residual.

For multiplication, the retained linear terms are

```
center_a * center_b
+ center_a * linear_b
+ center_b * linear_a.
```

The residual is bounded by

```
|center_a| residual_b + |center_b| residual_a
+ total_radius_a * total_radius_b.
```

`ProducerEnclosure.affineProduct_residual` proves this identity and bound for arbitrary integer or common-scaled integer quantities. It does not assume the two operands' generator labels are independent.

### SiLU

The ideal-real SiLU is enclosed by a tangent form at the affine center, with explicit error for the center value, slope and curvature. For `sigma = sigmoid(x)`,

```
silu''(x) = 2 sigma(1-sigma) + x sigma(1-sigma)(1-2 sigma).
```

Since `sigma(1-sigma) <= 1/4` and `|x| sigma(1-sigma) <= |x| exp(-|x|) <= 1`, the absolute second derivative is at most `3/2`, hence at most 2. Taylor's remainder is therefore at most the squared total input radius. This analytic step is documented mathematics, not a real-analysis theorem in our Std-only Lean module.

Python Decimal supplies correctly rounded high-precision ideal exponentials. Adjacent Decimal values and outward binary64 conversion enclose them. The source approximation is then paid separately. If `C` is the binary32 `log2(e)` constant, the difference between `RN32(C*x)*ln(2)` and `x` is bounded using

```
|x| |C ln(2)-1| + ln(2) * RN-multiply-error,
```

plus the native instruction's possible subnormal-input flush. The evaluator uses a conservative `2^-22` relative allowance for the documented one-ULP instruction error. Its argument restriction keeps the mathematical exp result normal and finite. The addition and division in source SiLU each have their own rounding allowance.

No observed CPU/GPU discrepancy is used as an error bound.

### Dynamic quantization without freezing the maximum index

For prequantized source value `y_i` and source block maximum `m`, let `s` be the separately rounded stored scale and `q_i` the actual rounded integer code. In the supported normal-scale range,

```
|q_i s - y_i| <= max_stored_scale / 2 + 5 * 2^-24 * max_magnitude
                + 16 * 2^-149.
```

The first term pays for integer rounding. The second encloses the separate reciprocal, multiplication and scale-rounding errors; `(1+u)^3-1 < 4u` for `u=2^-24`, leaving slack for underflow terms. Thus the **dequantized operand keeps the prequantization affine generators**, with this additional coordinate residual. The maximizing coordinate need not remain the same. Treating the rounded scale as a fixed reciprocal would not give this guarantee.

Integer code intervals are computed separately through the rounded reciprocal/product and nearest-even conversion. When all endpoints of a block coincide, the complete hidden code vector is fixed even though its scale varies. That is the cell used by the exact local replacement above.

## Evidence on the captured producer

The [fixture](instances/bonsai-layer00-producer-chunk0.npz) contains exact gate/up integer block accumulators, weight scales, source scale vectors and captured outputs for eight real rows and the first 1,024 hidden coordinates. Its [provenance](instances/bonsai-layer00-producer-chunk0.json) names all source hashes and reuses the existing HALO decoder. [enclosure_fixture.py](enclosure_fixture.py) rebuilds it on the CPU from the adopted dataset.

The experiment evaluates all eight rows at three scale contracts: singleton, approximately one ppm, and approximately 0.1%. Every captured gate/up value, hidden code, hidden scale and dequantized hidden value lies in its corresponding enclosure. Those checks test implementation consistency; they do not replace the source-derived inequalities.

For captured row 0:

| Scale radius | Fixed codes out of 1,024 | Fixed codes in first block | Affine bound for earlier candidate | Independent-box bound |
|---|---:|---:|---:|---:|
| Singleton | 1,019 | 128 | 0.028145 | 0.028145 |
| About 1 ppm | 1,019 | 128 | 0.028146 | 0.028154 |
| About 0.1% | 361 | 61 | 0.030009 | 0.036983 |

The error columns concern the preceding round's 63-bit candidate, measured in dequantized hidden-input dot-product units before the common weight scale. They are not output residual error, perplexity or generation quality. The newly discovered 36-bit candidate has zero integer error within the tighter contract; no zero-error claim is made for the wider contract.

The full suite runs in about eight seconds. It also checks 2,016 primitive interval operations against exact rational arithmetic and 108 affine product cases. The local replay checks the source guard, rejects a changed code and an out-of-range scale, reconstructs the enclosure, verifies the fixed hidden block, and repeats the finite exact assignment.

## Proof and deployment boundary

[ProducerEnclosure.lean](../../Kelana/ProducerEnclosure.lean) proves interval add/subtract/four-endpoint multiplication, approximate-primitive error composition, monotone rounding transport, rational scaling, arbitrary-dimensional box composition, rounded Hadamard butterflies, division endpoint certificates and affine-product residuals. The [proof guide](ENCLOSURE-PROOFS.md) states the API and assumptions.

The Python evaluator, IEEE implementation, AMD transcendental specification and real-calculus Taylor argument are not end-to-end Lean-verified. The certificate's stated arithmetic contract is pinned and auditable; neither the saved JSON nor capture agreement upgrades the whole executable to a Lean proof.

The captured dataset lacks the loaded code-object hash. The source audit identifies the corresponding committed gfx1151 object and compiler family, but a new deployed last-bit acceptance should record the object actually loaded. This round runs no GPU work and changes no service or engine binary.

## Operations

```
lake build Kelana.ProducerEnclosure
python3 research/quantization-discovery/enclosure_experiments.py
python3 research/quantization-discovery/check_enclosure.py
```

[fp_enclosure.py](fp_enclosure.py) owns the numerical enclosure and guard. [enclosure_experiments.py](enclosure_experiments.py) owns the experiments and [enclosure-results.json](enclosure-results.json). [check_enclosure.py](check_enclosure.py) replays the selected local result. NumPy is the only non-stdlib runtime dependency. No SciPy, GPU or model service is needed. Each command is intended for a foreground timeout below 60 seconds.

A broad, cheaply described producer contract shared by many weight blocks remains useful for lossy or domain-exact quantization. This result supplies a checked local route through the nonlinear and rounded program. It does not pay for a useful global contract, the guard, or a native consumer of the variable-length packet.

The [response-first fiber follow-up](FIBER.md) takes a different route. It retains the information discarded here as an exact within-response rank. This supports every input without an original-weight copy, produces a modest net serialized saving on the complete real block, and exposes a partial-read shortcut. Its current obstacle is online reconstruction cost rather than validity outside a local contract.
