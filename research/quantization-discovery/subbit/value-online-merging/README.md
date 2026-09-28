# First-seen narrow-V labels are poor centers

A paid rank-28 signed-byte V cache repeats full 224-byte rows at Qwen3-0.6B layer 0. Its exact append-only dictionary costs 125.273 bytes/key on four separate 256-token windows. Can one deliberately merge *nearby* codes to keep only 128 entries, spend about the same bytes as the signed-nibble cache, and read fewer labels without expanding any code into int4? I tried a causal dictionary: copy each new row until the block holds 128 representatives; assign later rows to the closest existing representative in the sum of the two paid output-head Gram metrics. Earlier rows and IDs never move. The answer for this fixed first-seen family is no.

The distance between two complete signed-byte rows `c,d` is

`D(c,d) = Σ_g Σ_{h=0,1} || A[g,h] diag(s[g]) (c[g]-d[g]) ||²`, 

where `A` is the frozen paid output map and `s` the charged FP16 per-coordinate V step. For fixed representatives, choosing the smallest `D` minimizes the sum of *isolated* two-head post-O row-response squared errors over independent key assignments. It does **not** minimize the attention-weighted sum: cross-key and cross-head interactions enter after causal mixing. The representative set is first-appearance ordered, not an optimal dictionary. This distinction is the point of the experiment.

| Layer | Entries | Bytes/key | Causal label uses/group | Held post-O teacher relative squared error | Change against unmerged paid output |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 64 | 57.023 | 54,367 | .558620 | .294363 |
| 0 | 96 | 85.023 | 70,926 | .473830 | .155762 |
| 0 | 128 | 112.805 | 79,391 | .403381 | .041785 |
| 0 | exact | 125.273 | 80,671 | .378889 | 0 |
| 14 | 128 | 113.023 | 98,560 | .434637 | .187799 |
| 14 | exact | 225.023 | 131,584 | .326373 | 0 |

These are four previously inspected, **separate** original-producer validation windows. Each block charges 224 bytes per representative, one byte per key ID, a two-byte count and a four-byte arena address. At layer 0, 128 entries merge just 20 keys in each of three windows and none in the fourth, saving 12.469 bytes/key and only 1.59% of the exact dictionary's causal label uses while raising teacher error .024492. Each affected window worsens: its relative squared error rises .036539, .031651 or .029616; the untouched fourth is equal. At layer 14, all keys are unique and exactly half are merged; the teacher error rises .108264. The separate paid signed-nibble image reports .385148/.334500 at 112 bytes/key on these inspected windows, but its producer/output factors differ. It is a useful competitive rate reference, not a controlled same-image comparison. The floating-probability exact-dictionary score .378889/.326373 matches the parent integer-mass reader's .378890/.326401 closely, but those are different attention rounding contracts.

The indexed consumer would histogram the two heads' conserved count masses by ID and dot the distinct signed-byte labels directly. For four windows, there are 131,584 causal key uses per group; the table counts logical label uses, or 56 signed-byte coordinate products per use across two heads. Histogram scatter, zeroing, the paid O projection, and physical reads remain. More importantly, selecting the nearest center at append requires a search over up to 128 *224-coordinate* representatives and a paid-output metric transform. The current prototype computes that transform offline for the CPU experiment; it is not a free native cache append. Fewer label products here do not buy that online search. No native timing, quantized-producer loss or full-model NLL follows.

A better family should learn centers using attention-weighted post-O loss on training text and assign a new row with a much cheaper key-side rule, then measure fresh text and price the append search alongside scatter/dot/O. Another option is to change the V producer so many keys naturally land on the same code; squeezing first-seen frozen labels after the fact costs too much quality at the useful byte boundary. This negative is restricted to 256-key blocks, these frozen paid factors and the first-seen/nearest-center rule. It does not bound a trained codebook or a long-context repetition rate.

[`measure.py`](measure.py) reconstructs the parent's paid signed-byte codes and checks their per-group hashes; it reuses the original-producer probabilities and teacher in the hashed mixed-rate fixture, not that fixture's different V image. Each receipt records source, model, capture, image, decoder, parent and fixture hashes, all capacity assignments and per-window errors. [CPU receipts](/path/to/workspace/data/kelana-subbit/value-online-merging/README.md) are under `/path/to/workspace/data/kelana-subbit/value-online-merging/`. Run `OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/value-online-merging/measure.py --layer 0` or `--layer 14` from a Kelana checkout.
