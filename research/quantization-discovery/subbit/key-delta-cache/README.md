# Exact temporal coding of the paid nibble-key cache

A neighboring post-RoPE key is not an independent symbol on the inspected Qwen3-0.6B text. For the frozen paid binary Q/K observer's 256 selected signed-nibble key coordinates, a three-bit temporal difference plus an occasional four-bit absolute escape stores the **same key codes** at 3.7363 bits/code in layer 0 and 3.2257 in layer 14. The 128-byte/token nibble cache becomes a logical 119.6 and 103.2 bytes/token, respectively, including the first-key anchor. Restarting every 32 keys, so decoding any key needs at most 31 predecessor steps, gives 119.8 and 103.9 logical bytes/token. Byte-aligning each block and charging a four-byte address per group/block gives 120.83 and 104.96 bytes/token. This is an exact cache-rate result on frozen codes, not a new weight-rate or language-quality result.

| Inspected validation layer | Escapes, whole 256-key history | 256-key bits/code | 32-key logical / aligned-plus-offset bytes/token | Original bytes/token |
| --- | ---: | ---: | ---: | ---: |
| 0 | 47,998 / 261,120 = 18.38% | 3.7363 | 119.77 / 120.83 | 128 |
| 14 | 14,536 / 261,120 = 5.57% | 3.2257 | 103.90 / 104.96 | 128 |

Each measurement includes four previously inspected 256-token validation windows, eight GQA groups, 32 selected coordinates per group. Layer-0 window escape fractions are 17.33%, 20.55%, 18.24%, 17.41%; layer 14 has 5.30%, 5.41%, 6.02%, 5.53%. The same train-selected raw/centered nibble steps and paid producer from `key-nibble-cache` determine the integer codes. We did not choose a codebook with held labels. Even a held-oracle choice of the seven most frequent *global* difference symbols picks precisely `-3,...,3` on both layers. An eight-key restart costs 120.62/106.24 logical bytes per token; four-byte block addresses raise its physical byte requirement further. The recorded aligned-plus-offset figure counts one separate four-byte address per group/block and no extra alignment to cache lines.

## Map and bound

Store the first signed nibble `c_0` in each block. For each later coordinate, let `d_t = c_t - c_{t-1}`. The three-bit alphabet encodes `-3,...,3` and one escape; the escape is followed by the original four-bit `c_t`. Induction reconstructs every integer key code, so the two observing heads see the same real score map as the frozen direct-nibble consumer after reconstruction. For `N` coordinates, block width `T` and escape fraction `p` across the `N(T-1)` transitions, the logical bits are

`4N + (T-1)N(3+4p)`.

Against `4NT` independent nibble bits, it wins exactly when `p < 1/4` before address and padding costs. At a 32-key restart, layer 0 uses 981,136 versus 1,048,576 bits over the four windows; layer 14 uses 851,172 bits. This is a lossless finite-alphabet identity for the *already quantized* cache. It does not imply equality to the original floating keys, bit-identical native FP32 scores, or any win on another producer/text distribution.

There is a direct whole-score recurrence: for a fixed query, `s_t = s_{t-1} + q·d_t`; an escape can correct its coordinate by `q_j(c_t-c_{t-1})` rather than expanding a stored int4 array. The recurrence carries score labels across the entire block and never asks for the floating key. But reconstructing an absolute escaped coordinate still needs its previous code, query-dependent scores must be recomputed for every new query, and the dot over all 32 deltas remains. Three-bit extraction, unpredictable escapes, prefix dependencies, block offsets, and 512 query-preparation multiplies/token/layer sit on top of the existing full 1,024-row K-norm producer and two signed-nibble query dots. The logical traffic reduction alone does **not** justify a native route. In particular it is not cheaper arithmetic than expanding three-bit fields to nibble operands in registers.

This result changes the next question. A learned temporal predictor could increase the zero/small-difference mass on *quantized-producer* text, but only if its cache update and random-key consumer cost less than the removed bytes. First price a 32-key restart decoder and score recurrence with variable-length offsets against the existing packed nibble and the static 112-byte mixed three/four-bit cache at occupied contexts. The static cache gives random access and costs no serial temporal reconstruction; this exact delta code must beat that stronger runtime control, not just 128 bytes. The present experiment used CPU, no GPU reservation, no Bonsai executable and no service change.

`measure.py` loads the pinned Qwen3-0.6B original-producer validation captures and the already paid binary K, selected planes and train-fitted nibble steps. Its two receipts under `/path/to/workspace/data/kelana-subbit/key-delta-cache/` retain each group's and window's complete 29-symbol difference histogram, escape counts, rates for restart widths 8/32/256, and source/model/capture/image/parent hashes. Reproduce with:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-delta-cache/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-delta-cache/layer$(printf %02d "$layer").json"
done
```
