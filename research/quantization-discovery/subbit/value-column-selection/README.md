# Which paid output groups should the narrow-V reader keep?

The [preserved-column reader](../value-column-skeleton/README.md) copies ten of sixteen paid rank-28 V/O output groups and replaces the six omitted groups by a two-bit transfer. Its greedy group selection optimized the real projection of the *paid* output onto the retained columns. This experiment asks whether that selection leaves a cheap exchange, either under its own projection objective or under the actual quantized teacher response. The Qwen3-0.6B layer-0/14 captures, paid V codes, original Q/K producers and four validation windows are identical to the parent study.

For retained columns `C=A[:,S]` and omitted columns `D`, fit `Tᵀ=C⁺D` on the paid decoder. The online map remains `y=(z_S+z_D T) Cᵀ`, with only `T` newly quantized to two bits. The 224-byte narrow-value cache and the paid V producer are untouched. Each candidate copies the same ten groups and pays 107,426 output bytes, .428472 V/O BPW and 333,760 logical output terms per token. It still needs an actual native two-stage reader, including the 280-coordinate intermediate and routing; none was measured here.

The parent greedy set is a strict single-group-exchange local optimum for its exact train paid-response projection score at both layers. We scored all `10 × 6 = 60` distinct swaps. That closes a simple post-greedy repair of **this** objective, not a global combinatorial optimum. We also rebuilt and quantized the paid-output transfer at every swapped set and evaluated the *complete teacher response* on 2,048 train rows by the quadratic identity below. The selected swap minimizes that train criterion among the original set and its 60 neighbors. Held rows never chose a set.

| Layer | Parent groups' train / held teacher error | Best quantized train groups' train / held error | Best held error among 61, diagnostic only |
| --- | ---: | ---: | ---: |
| 0 | .283859 / .413157 | .283859 / .413157, unchanged | .412238 |
| 14 | .244014 / .375237 | .238514 / .376436, group 5 replaced by 1 | .370348 |

The layer-14 train choice improves relative squared teacher error by .005499 but loses .001200 held. Its four held windows change .369798→.371661, .424825→.417060, .336479→.339530 and .371977→.379243. The best held neighbor, which was **not** train-selected, scores .370348 and shows that the frozen paid columns have some conditional capacity. A longer local search against the same 2,048 original-producer train rows is not the next useful step. It is more likely to fit their distribution than to improve a changed, quantized-upstream model. Train on broader independent text with quantized producers, and co-fit V labels and the decoder transfer against composed post-O or model loss. Then price the reader against the full paid V/O map at matched quality.

For each set, let `B` be the `448×280` mapping with identity rows on retained coordinates and the rounded transfer rows elsewhere. If `Z` is the attended narrow-value feature matrix and `Y` the original post-O teacher, the squared response loss is

`||Y-ZBCᵀ||² = ||Y||² - 2⟨B, ZᵀYC⟩ + ⟨Bᵀ ZᵀZ B, CᵀC⟩`.

This evaluates all 61 rounded candidates using the same full output observation, not a rank-coordinate proxy. Direct full-response replay of the greedy and chosen sets agrees with the quadratic score to rounding. The output projection's real single-exchange score is `tr((CᵀC)⁻¹ CᵀY_paidᵀY_paid C)`, with `Y_paid=ZAᵀ`. The exchange result assumes the paid output columns and per-group two-bit transfer codebook, ten retained whole 28-coordinate groups, and original-producer finite captures. It is neither an FP32 identity nor a claim against learned factorized V/O.

Run the source and inspect all candidate train/held scores, group sets, image hashes, pinned model/capture/decoder hashes and per-window replay in [`data/kelana-subbit/value-column-selection/`](/path/to/workspace/data/kelana-subbit/value-column-selection/README.md):

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-column-selection/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```

This is a CPU original-producer quality and fixed-program cost result. No GPU, whole-model NLL, native timing, Bonsai executable or resident service changed.
