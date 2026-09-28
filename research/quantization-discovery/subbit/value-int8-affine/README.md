# Affine signed-byte value labels on the paid narrow V/O map

Can a free-looking shift of each signed-byte code's rounding grid repair the late-layer cache quality without changing the direct integer dot? On the frozen Qwen3-0.6B rank-28 V/O image, no. The shift is not actually free, and the train-fitted group arm improves its own complete post-O target but loses on the four inspected validation windows. A coordinate-MSE arm nearly ties the early layer and damages layer 14. This closes threshold translation of these *frozen* producer coordinates, not a newly learned V basis or an affine codebook trained with the whole model.

For group `g` and coordinate `j`, retain the paid right and left factors and FP16 cache step `s[g,j]`. Select `a[g,j]` on the five-point grid `{-1/2,-1/4,0,1/4,1/2}`, encode the BF16 producer coordinate `z` as `q=clamp(round(z/s-a),-127,127)`, and interpret its value as `s(q+a)`. The conserved 4,095-unit attention counts satisfy `sum_t n[h,t]=4095`, so

```
A[h,j] = s[g,j] * (sum_t n[h,t]*q[t,j]/4095 + a[g,j]).
```

The offset moves *after* the integer byte dot. In real arithmetic its post-O effect is the constant `sum_h O_paid[h] (s_g * a_g)`, independent of the query and context length. This is a whole-region factorization, not a need to expand codes into int4 or BF16 per key. It is also not an FP32 bit-identity: the reported script applies the offset before the paid O matrix multiplication, and folding a constant into the residual stream changes its floating reduction order. Signed products still fit `127*4095=520065` in int32. The input domain here is the frozen BF16 right-factor outputs and the original-producer attention probabilities converted to conserved counts. The observed result is the real/FP32 post-O response against original Qwen V/O, not the original model's full logits.

Two train-only policies were tried at equal cache payload. Coordinate-MSE chooses each of 224 offsets independently to minimize its own train BF16 value reconstruction error with the existing steps. The second policy evaluates all five uniform offsets per group against the *complete* two-head paid-O teacher response, greedily choosing eight group offsets in order on eight train windows. The latter is a more consumer-aware fit, not an exhaustive 5^8 search. Both use the same frozen V/O factor image and the same cache steps as the [paid signed-byte reader](../value-int8-consumer/README.md). The parent control is reproduced within 3e-8 relative squared error in the code. All scores below are complete post-O teacher relative squared errors; validation is four previously inspected, separate 256-token windows per layer.

| Layer | Policy | Train | Validation |
| ---: | --- | ---: | ---: |
| 0 | Unshifted direct int8 | .22286458 | .37889031 |
| 0 | Coordinate-MSE grid | .22285655 | .37888733 |
| 0 | Group complete-response grid | .22283109 | .37889603 |
| 14 | Unshifted direct int8 | .16460302 | .32640123 |
| 14 | Coordinate-MSE grid | .16475855 | .32674927 |
| 14 | Group complete-response grid | .16445056 | .32643822 |

The group-policy layer-14 training gain of .00015247 reverses to a validation loss of .00003698. Coordinate shifts worsen all four layer-14 validation windows. At layer 0 the coordinate arm's .00000298 absolute validation gain is smaller than the variation across the four windows and costs an additional offset read and add per coordinate if used directly. The group policy improves one or two individual validation windows but loses in aggregate on both layers. The original paid BF16 narrow cache already scores .37888697/.32619491 on this panel; neither fitted affine signed-byte arm establishes a better quality/cost point than it or a complete-model gain.

The 224-byte logical cache row, 4,095-count dot and paid factor bytes stay fixed. A packed 3-bit index costs 84 static bytes/layer for coordinate offsets, or three bytes for the eight group offsets, plus extraction and one offset subtraction per coordinate at append. Direct consumption adds 448 offset additions per layer/query before O. Precomputing the complete 1,024-element output correction trades those additions for 4,096 FP32 bias bytes/layer, or 2,048 BF16 bytes with another approximation, and 1,024 output additions/query. Neither preserves the script's floating map bit-for-bit. Signed-byte dot and sparse-overflow work are unchanged; no GPU time or quantized-producer model loss was measured. Even the best apparent early-layer gain is too small to justify those costs on this frozen image.

The next useful question is to **learn the V producer basis, byte codes and paid O labels against quantized-upstream composed loss**, rather than shift this old coordinate's thresholds again. If a learned affine family earns a quality margin, compare the complete append/count/dot/offset/O program with the unshifted signed-byte and E4M3 readers at occupied context before adopting it.

The [CPU receipts](/path/to/workspace/data/kelana-subbit/value-int8-affine/README.md) bind source, factor decoder, model, capture, paid image and parent; they keep per-window scores, offset choices and held cache-code hashes. Run from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-int8-affine/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
