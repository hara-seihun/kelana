# Temporal narrow-value codes and suffix-mass attention

A temporal difference looks attractive for a half-byte narrow V cache: adjacent tokens often have related activations, and a direct consumer could avoid reconstructing the old cache coordinates. On the frozen paid Qwen3-0.6B V/O image, this particular construction barely reaches static nibble bytes on layer 14 and loses on layer 0. Its suffix scan and escape decoding make it a poor native candidate. The result narrows the next question to learning the value producer *with* a streamable code and the attention consumer, not repacking the frozen nibble labels.

## Complete map

For one GQA group let `c_t` be its 28 signed-nibble value coordinates. Across eight groups the layer carries 224. Restart each block at `b` with `a=c_b`, and store `d_j=c_j-c_{j-1}` for `j>b`. For each observing head and query, let nonnegative integer attention masses `m_t` sum to `M` over all causal keys. On a block ending at `e`, define `S_j=sum_{t=j}^e m_t`. Integer distributivity gives

```
sum_{t=b}^e m_t c_t = a * sum_{t=b}^e m_t + sum_{j=b+1}^e S_j d_j.
```

Both heads share the same stored differences, but have distinct suffix masses. The proof substitutes `c_t=a+sum_{j=b+1}^t d_j` and exchanges the two finite sums. It holds for every signed-nibble history, every integer mass row and every group. The script checks the direct and suffix responses in 224 dimensions, for two independent 4,095-unit heads and blocks of 2, 16, 32 and 256 keys. The decoded value response multiplies each coordinate by the original frozen FP16 step after this integer accumulation, then the original paid O consumes it. This is an exact integer identity for the *same* quantized cache and masses, not bit-identical FP32 attention or an improved model image.

A native consumer would need a backward suffix scan per head per block, one anchor-vector dot with the block mass, and a difference dot per later key. No absolute key code or int4 value vector need be reconstructed. The anchor may instead be carried across blocks if the parser and schedule allow it; this rate panel explicitly charges each block's independently addressable anchor. The 3-bit direct labels are a learned seven-entry signed-difference alphabet, with the eighth symbol escaping to a signed-five-bit difference in `[-15,15]`. This can feed a signed-byte difference dot directly, at the cost of code-to-byte conversion, escape selection and wider probability mass operands. The frozen packed-nibble static cache already has a three-digit direct `dot8` mass consumer. Compare the full issued program, not the number of logical differences.

## Frozen Qwen panel

The code decodes the existing rank-28 paid V image and uses its train-selected per-coordinate FP16 nibble steps and lower endpoints from `value-nibble-joint-fit`. It computes the BF16-rounded right-factor output on eight train and four previously inspected validation windows of 256 tokens. Train windows alone choose either one alphabet per GQA group or one per coordinate. Validation codes are encoded exactly. The 2/3/4-bit grammars and restarts of 16/32/64/128/256 keys are all priced. Each block pays a 112-byte packed anchor, a fixed-width symbol for every remaining coordinate, a five-bit payload per escape, byte alignment and a four-byte block offset. Add 35 bytes per layer for the eight three-bit group alphabets or 980 bytes for 224 coordinate alphabets. The paid V/O factors and FP16 steps are unchanged in both arms. The static reference is 112 logical bytes/token/layer, 128 with its existing group padding.

| Layer | 32-key, 3-bit group bytes/token | 256-key, 3-bit group bytes/token | Best 3-bit coordinate bytes/token at 256 keys | Static nibble |
| --- | ---: | ---: | ---: | ---: |
| 0 | 114.910 | 114.845 | 114.879 | 112 |
| 14 | 112.067 | 111.957 | 111.759 | 112 |

Those temporal rates exclude the new alphabet metadata. Layer 14 at 256-key restarts saves only **44 bytes across all four 256-token held windows** before its 35-byte group alphabet, or nine bytes after it. At 32-key restarts it loses 69 bytes before metadata. The coordinate alphabet's apparent 247-byte saving across four layer-14 windows costs 980 static bytes/layer, so it also loses at 1,024 keys. At layer 0 every 3-bit arm loses even before metadata. Two-bit escapes are too frequent (53–55% at width 32); four-bit symbol rows cost over 115 bytes/token on both layers. The receipt includes every restart, width, alphabet and per-window byte count. Different windows vary sharply, so the nine-byte aggregate edge is not a robust rate advantage.

At 32-key restarts a group 3-bit stream has 222,208 held difference coordinates at each layer. Layer 14 escapes 44,331, or 19.950%; layer 0 escapes 48,987, or 22.046%. Without byte-alignment slack, the exact rate inequality against 112 static bytes/token over four windows is

```
5 E + 8 * (112 + 4) * 32 + 3 * 224 * (1024 - 32) + 280 < 8 * 112 * 1024.
```

It requires `E <= 44,180` before block rounding, 151 fewer than observed on layer 14. The 280-bit term charges the shared layer alphabet once; the actual byte-aligned stream loses more. That is a rate bound for this fixed block/symbol/escape grammar, not an entropy bound on learned value codes. No native timing, quantized-producer NLL or new quality comparison is claimed: the integer map keeps the parent's code image and its known E4M3 quality gap.

## Reproduce and next experiment

```
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$P research/quantization-discovery/subbit/value-delta-suffix/measure.py --layer 0
$P research/quantization-discovery/subbit/value-delta-suffix/measure.py --layer 14
```

Raw per-window rates, learned alphabet tables, source/capture/factor/parent hashes and the integer suffix certificate live in `/path/to/workspace/data/kelana-subbit/value-delta-suffix/layer{00,14}.json`. A useful follow-up would train a low-difference V basis and signed labels against quantized-producer post-O or gold loss, then require a margin larger than the suffix scan, append conversion, escape parser, table reads and anchor dots before writing a gfx1151 reader. Reducing these already frozen labels by another fraction of a byte at 256 keys is not enough.
