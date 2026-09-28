# One extraction after a full bilinear down projection

The native 32-bit packed-square component was measured at fan-in 128. Its final extraction can be delayed farther, but not across an entire 17,408-wide Bonsai FFN down row under worst-case signed inputs. A 64-bit carrier can cross that whole row with one extraction. `Kelana/DirectConsumer.lean` checks both claims as integer and modular-arithmetic statements.

Let `c_i ∈ {-1,0,1}` be prepared downstream weights, `g_i,u_i` integer producer results, `L = Σ c_i g_i²`, and `T = Σ c_i g_i u_i`. For `p_i = g_i + 2^b u_i`, a signed accumulated square is

```
Σ c_i p_i² = L + 2^(b+1) T + 2^(2b) Σ c_i u_i².
```

The summation is over the *entire observed down row*. Neither channel nor the individual products have to be reconstructed at the handoff. At `b=16`, the last term vanishes modulo `2^32`. Add `2^16` to the wrapped sum and sign-extract bits 17..31. The extraction is `T` if `-2^16 ≤ L < 2^16` and `-2^14 ≤ T < 2^14`. For `|g_i|,|u_i|≤7`, each term contributes at most 49 in magnitude. **334 terms** meet both conditions. This strengthens the earlier 128-term theorem; 335 terms of `(c,g,u)=(1,7,7)` yield `T=16415`, which cannot fit the 15-bit signed field. The Lean counterexample checks the actual extractor, not just a bound. In this fixed carrier/extractor and worst-case domain, a complete 17,408-term row therefore needs at least `ceil(17408/334)=53` extracts. Partitioning into 52 groups of 334 and one of 40 achieves 53, then 52 integer additions combine the extracted results. This is a lower bound for that fixed grouping scheme, **not** for arbitrary 32-bit instruction programs.

At `b=32`, the last term vanishes modulo `2^64`. Add `2^32` and sign-extract bits 33..63 of a wrapped 64-bit sum. For the same row with signed **A8** `|g_i|,|u_i|≤127`, both `|L|` and `|T|` are bounded by `17408*16129 = 280,773,632`, below the low-field limit `2^32` and signed product limit `2^30`. So a single final extraction recovers the exact integer down result for **every** such row. The theorem `downstream64_a8_17408` proves this for every list of at most 17,408 ternary-weight terms; `centered64_wrap_invisible` proves a modular accumulator has the same observation. No distributional assumption or calibration sample enters the proof. A 64-bit packed value needs up to 40 signed bits for A8, so the existing fast signed-24 multiplication cannot implement this square.

The 64-bit result saves up to 52 final extractions relative to 32-bit [-7,7] chunks, or one per hidden coordinate relative to extracting each product. It does **not** save 17,408 squares, 17,408 signed weighted additions, or the cost of forming the packed producer. A wide multiply, 64-bit accumulator traffic and cross-wave reduction can make it slower. The shipped FFN also applies SiLU, per-block scales, hidden Hadamard and quantization before down. The exact bilinear integer map proved here does not commute through those operations or establish FP32 bit identity. There is no runtime change.

A decisive native component experiment would use the existing `direct-consumers/native` probe to compare a 64-bit wrapped square/sum plus one extraction against 53 independent 32-bit sums and extracts at equal term count, input and producer cost. Price integer64 multiplication throughput, register lifetime, weighted accumulation, and the reduction across lanes. Only after a competitive native result would a producer and the intervening nonlinear/quantizer map justify a whole-FFN candidate.

Reproduce the checked bounds from the repository root:

```
lake build Kelana.DirectConsumer
```
