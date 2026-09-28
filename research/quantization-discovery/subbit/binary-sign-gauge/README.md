# Rank-sign gauge has little leverage on the paid A7 reader

Flipping a rank coordinate in both paid binary factors leaves their real product unchanged and costs no stored bits or online work. It can change the grouped A7 reader because its integer codes range from -64 to +63. On four Qwen3-0.6B `mlp_up` matrices, two layers have **no** second-stage codes that respond to any rank-sign flip on the 64 train and 128 held activations. The other two have a few dozen active coordinates. A train-only greedy fit barely moves held complete-response RMS and sometimes worsens it. This closes sign orientation as a useful frozen-image follow-up to the [rank permutation](../binary-rank-gauge/README.md) on these inputs; it does not reject a newly trained binary image or another activation quantizer.

## Exact cell and cost statement

Let `V` be the paid 384-by-1024 sign matrix, `U` the paid 3072-by-384 sign matrix, and `s_j` independent rank signs. Replacing `V[j,:]` by `s_j V[j,:]` and `U[:,j]` by `s_j U[:,j]` preserves `UV` over the reals. The first signed integer reduction emits `s_j h_j` exactly, provided its accumulator does not overflow. The second A7 group's maximum absolute value, ladder selector, multiplier and final shared scale are unchanged by any sign choice. If `q` is its round-to-even, clipped `[-64,63]` code, the contribution after the second factor for a flipped coordinate changes by

`U[:,j] * w_group * (-q(-h_j) - q(h_j))`.

The parent first-stage common scale and second-stage scale multiply this expression at the final boundary. The bracket is zero whenever rounding and clipping stay in the symmetric `[-63,63]` range; it has magnitude at most one otherwise. Thus if none of the observed second-stage coordinates reaches the asymmetric cell, **every one of the 2^384 rank-sign orientations produces the identical final integer output** for those inputs. This is an exact integer statement for the declared two-factor ladder, not an FP32 execution-identity claim. It is not a claim about unobserved model inputs. A triangle bound on the Frobenius norm of all possible held response corrections is recorded per arm in the receipt; it is deliberately loose where active cells exist.

The chosen sign gauge repacks V rows and U columns in place. Both packed matrices retain their shapes, byte counts, sign-word products, two quantizers, group reductions, rank intermediate and final scales. There is no sign metadata or activation gather. It can alter cache pattern and FP32 reduction order in a native reader, neither of which is timed here.

## Complete-response panel

The parent `.55` paid image, pre/post scales and Qwen3-0.6B original-producer activations are fixed. Train uses WikiText train fixture positions 512–575; a separate validation split at positions 576–703 is held, disjoint also from the parent rank-gauge report's validation 512–575. Both factor boundaries use the parent's two-choice A7 cap-eight integer ladder. Layers 0/14 freeze their independently fitted threshold pairs `.77/.77` and `.78/.77`; 7/27 use the safe `.75/.75`. The denominator is the same paid image's FP64 unrounded response, not original dense weights. For each layer we compare the original rank order and the independently train-energy-sorted order. We fit flips by greedy positive decreases of the exact train squared **final-output** error quadratic over the active coordinates, then replay both repacked sign planes and both integer stages. This is not a global sign-fit optimum.

| Layer | Rank order | Train / held active coordinates | Flips | Train RMS before → after | Held RMS before → after |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | original | 24 / 56 | 8 | .01728497 → .01727221 | .01737008 → .01736928 |
| 0 | energy sorted | 14 / 50 | 4 | .01701287 → .01700717 | .01734852 → .01734646 |
| 7 | original | 0 / 0 | 0 | .01622102 → .01622102 | .01635207 → .01635207 |
| 7 | energy sorted | 0 / 0 | 0 | .01578089 → .01578089 | .01619628 → .01619628 |
| 14 | original | 26 / 48 | 14 | .01559212 → .01556963 | .01601782 → .01601886 |
| 14 | energy sorted | 26 / 43 | 17 | .01501510 → .01498308 | .01580884 → .01581002 |
| 27 | original | 0 / 0 | 0 | .01291171 → .01291171 | .01104641 → .01104641 |
| 27 | energy sorted | 0 / 0 | 0 | .01247610 → .01247610 | .01064090 → .01064090 |

On this 128-held-input panel, the sorted unflipped layout is better than the original unflipped layout at all four layers. The sign-fit gain at layer 0 is about two millionths of relative RMS on the sorted layout, while layer 14 reverses. This is not a whole-model quality comparison. The exact zero-response result at layers 7/27 is more decisive than the fitted scores: no better sign-search algorithm can improve *this* fixed reader on these observed inputs without changing its quantizer or factors.

Run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-sign-gauge/measure.py` from Kelana. `/path/to/workspace/data/kelana-subbit/binary-sign-gauge/receipt.json` holds source/parent/image/fixture hashes, both packed-plane hashes, selected flips, event counts, complete integer output hashes, per-input held errors and the possible-change bounds. The replay checks the predicted correction against the actual integer pipeline for every input. No GPU, model NLL, native timing, Bonsai executable or service changed.

The useful next question is not a longer sign-flip search on these frozen factors. Fit the binary signs and rank grouping against quantized-producer *composed MLP or gold loss*, or change the signed activation-code alphabet so its orientation can affect more than a handful of boundary events. Price the complete native reader only after such an image survives fresh model-quality evaluation.
