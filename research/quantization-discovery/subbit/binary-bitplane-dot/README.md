# Direct bitplane dots for paid binary factors

The already-paid binary U/V factor images admit a direct integer consumer without expanding either sign plane into int4 or float weights. On 64 matched Qwen3-0.6B original-producer inputs, a symmetric dynamic four-bit activation at **both** factor boundaries changes the frozen binary-factor response by 19.7–38.4% relative RMS with one scale per vector. Scaling each 32-coordinate block instead reduces it to 9.8–12.9%, but adds 49,152 scaled partials for an `mlp_up` query. More interestingly, grouped A6 gives 2.5–3.1% error against global A8's 1.9–4.3%, with six rather than eight population counts per weight word. This is a meaningful cost/quality trade, not a native speedup; the group partials may consume the savings.

## Whole-map identity and online work

Let `S` be the *stored* binary sign mask for 32 weights, bit 1 meaning +1. For signed two's-complement `b`-bit input activations `a_i`, prepare the 32-bit mask `A_j` of activation bit `j`. The signed integer response of that block is

```
D(S,A) = sum(j=0..b-2) 2^j [2 popcount(S & A_j) - popcount(A_j)]
         - 2^(b-1) [2 popcount(S & A_(b-1)) - popcount(A_(b-1))].
```

For each bit, `2 popcount(S & A_j)-popcount(A_j)` is the sum of its +1/-1 sign coefficients. Expanding the two's-complement input proves the formula for every packed sign word and every signed `b`-bit input, including the negative endpoint. Summing words recovers each factor's exact **integer** dot, so the first response can be quantized and fed directly into the second factor. The two factor scales are applied at their original boundaries. The real-valued original-factor map is not preserved after the two activation roundings, and a changed FP32 reduction order is not bit-identical. The identity itself needs neither an int4 weight nor a reconstructed float factor.

For an `N × K` projection at rank `R`, both factors together have `W=R(K+N)/32` sign words. The hot contraction uses `bW` sign-and-bitplane popcounts, `bW` bitwise ANDs, a word sum and integer coefficient arithmetic per plane, plus shared input-only population counts. It loads `R(K+N)/8` sign bytes, independent of `b`, and prepares `b(K+R)/32` input bitplane words. Global scaling needs two dynamic activation scales per token. Scaling each 32-coordinate word instead needs `K/32+R/32` max/scale preparations and `W` separately scaled floating partials, rather than `R+N` final output scales. The unchanged pre/post weight scales are still paid in both arms. A conventional byte activation and int4-expanded factor would store `R(K+N)/2` weight bytes, four times as many, but gfx1151 dot4 works on four byte lanes per instruction. For a 32-coordinate block that is eight dot4 instructions against **eight** popcounts at A8, or four popcounts at A4. This is an instruction-class count, not a speedup: ANDs, bit extraction, integer horizontal accumulation, per-row float scaling, first-factor writes, second-factor reads, two max reductions, occupancy and launch scheduling remain charged. At `mlp_up` (`N=3072,K=1024,R=384`), there are 49,152 sign words, 196,608/294,912/393,216 popcounts at A4/A6/A8, and 196,608 sign bytes, including both factors but excluding unchanged scales. A native reader should compare the existing packed-float binary consumer and the half-orbit/routed consumers on the same image, not an expanded-int4 strawman.

## Frozen response pilot

`measure.py` consumes all sixteen `.55` Qwen binary factor images at layers 0, 7, 14 and 27, four projections per layer. It uses the first four previously inspected validation activation rows from each matching fixture. Inputs are rounded-to-even with signed endpoint clipping. The global arm uses one max scale at each factor boundary; the grouped arm uses one per 32-coordinate word at each boundary. The table is the arithmetic mean over sixteen relative output RMS errors per projection, against that *same image's* FP64 binary-factor response with its pre/post scales. These are not errors against the original Qwen teacher, language loss, or a quality-matched int4 baseline.

| Projection | Global A4 | Group-32 A4 | Global A6 | Group-32 A6 | Global A8 | Group-32 A8 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| MLP down | .3842 | .1205 | .1503 | .0311 | .0428 | .0080 |
| MLP up | .2705 | .1158 | .0725 | .0285 | .0191 | .0070 |
| Attention O | .2992 | .1287 | .0866 | .0300 | .0221 | .0075 |
| Attention Q | .1965 | .0984 | .0520 | .0251 | .0195 | .0066 |

Grouped A7, also in the receipt, scores .0156/.0142/.0151/.0130 respectively. It uses seven population counts per word but adds the group-scale work. This is the strongest directly measured approximate point here, not evidence of good complete-model loss.

The first-factor rounding dominates the global-scale samples. At layer 14, the A4 down output's mean first-only error is .4384, versus .1164 for second-only; A8 gives .0530 versus .0062. Both factors' exact integer bitplane outputs were compared with independent unpacked int32 matrix products for every input, image and width. The grouped arm evaluates the same integer block products and applies its individual floating scale before reducing blocks; it does not satisfy the global-scale integer whole-row identity after scaling. The receipt stores each stage's error and scales, dimensions, work counts, image/fixture hashes and the reproducer's source hash at `/path/to/workspace/data/kelana-subbit/binary-bitplane-dot/receipt.json`. Reproduce with `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-bitplane-dot/measure.py`; the run takes seconds and no GPU reservation.

The next useful native panel is grouped A6/A7 against global A8 and the existing packed-float binary consumer at equal image and input, including both quantization passes, per-word float reductions and the intermediate transfer. Separately test composed Qwen loss on quantized-upstream text before selecting a lossy map. The 32-group quality gain has a real online bill; sign-byte savings alone do not pay it. No native timing, full-model NLL, engine executable or serving default changed.
