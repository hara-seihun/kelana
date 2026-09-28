# One paid balanced-and-centered positive prefix reader

**The exact-source coordinate change helps, but the complete V/O endpoint still loses decisively.** This is the one predeclared follow-up to the [paid reciprocal BF16 Q/K gamma balance](../qwen-balanced-gamma/README.md): keep the original committed 64×128 FP16 Gaussian feature table, seed, 64-feature map, online log-stabilized 64×129 value/denominator moment state, source Q/K/V/O and 8 train +4 inspected-held 256-token causal windows. Read the source-balanced gamma image **as a replacement for the original 512 gamma bytes**, then take the single train-uniform-causal-pair balanced centroid already computed in that study and round it **once** to a paid 256-byte FP16 key-center image. No feature table fitting, rank/seed/precision selection, held-selected update or second reader is attempted.

The inspected-held two-head GQA post-O relative squared error improves from the frozen original uncentered positive reader **1.53503** and singly centered reader **1.69048** to **1.09345**. Head0/head1 attention KL falls from the singly centered reader's **137.244/188.419** to **5.520/10.078**. Nonetheless, the primary **complete projected V/O endpoint** remains dramatically worse than the named [KIVI 4-bit G32/R32 causal cache](../kivi-causal-cache/README.md), **.000155355** at 52,400 B causal peak (46,592 B after final flush), and worse than previously paid whole-vector Q4 **.92367** at 34,816 B or Q6 **.65695** at 51,200 B. This says this one finite positive-feature program is not competitive on the measured consumer; it is not a family impossibility, full-model quality, native speed or asymptotic cache verdict.

## Exact producer and actual paid fields

The original [primary positive reader](../qwen-positive-kernel/README.md) supplies the Qwen3-0.6B layer-0 first two Q heads, shared K/V, original O columns, K/Q norm/RoPE implementation, fixture SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`, and original 64×128 FP16 generic Gaussian table SHA256 `c79b3d345a0bfc6a1b2e4a6e8f04246e5b7750e885ae17f3eb36ad66d53d86f5`. The full BF16 checkpoint SHA256 is `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`. The [balanced-gamma study](../qwen-balanced-gamma/README.md) owns its **actual** independent BF16 source image SHA256 `c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865`: 128 Qgamma and 128 Kgamma fields, **512 B replacing 512 B** original fields. It proved on all these captures that complete source scores, probabilities and both head/GQA outputs are bitwise unchanged in the canonical CPU replay. Its train-only FP64 balanced centroid SHA256 `15ecf7b5a73b3cfe80ebcc08ab4f6ba286e852bff02ef180bf8b71622043a5b0` is a diagnostic preparation artifact, *not* the inference operand here.

[`center.py`](center.py) checks that saved train-only centroid and rounds it once to [`balanced-center-f16.bin`](balanced-center-f16.bin), exactly **256 per-model bytes**, SHA256 `3e9fa69a8942b762f0cd041e6a70bfa0c7833957f0d960a6032b0775058cd6a2` (maximum absolute rounding `.00195162`). [`center_reader.py`](center_reader.py) independently hashes and parses every FP16 field; the balanced gamma independent reader is imported from its owning source study. No center, gamma exponent choice, feature codebook or other model-specific field is inferred from inspected held data. This center is subtracted from the *scaled post-Knorm/RoPE* key at insertion, and those source K features then update the same per-feature FP32 log maximum, denominator and V numerator. The two Q heads use the unchanged source-balanced Qgamma, same table and same prefix state; source original O projection completes the consumer.

| At 256-token two-head GQA group | Bytes | Placement |
| --- | ---: | --- |
| Original two-Q/K/V/O/normalization static group **including** Q/K gamma | 1,573,376 | Common, 512 B gamma **replaced** within this allocation |
| 64×128 FP16 Gaussian table | 16,384 | Generic fixed table billed once for standalone reader |
| 128×FP16 balanced key centroid | **256** | Additional model-specific read-only field |
| 64×128 FP32 value moment numerator | 32,768 | Live prefix |
| 64 FP32 denominators +64 FP32 per-feature log maxima | 512 | Live prefix |
| **Table + center + live prefix** | **49,920** | Static/live axes combined solely for near-rate comparison |

The common 2-byte position counter is omitted equally; it is needed for RoPE and causal insertion. Prefix state is constant in sequence length, unlike K/V cache. The center also adds 128 key-coordinate subtractions at each insertion; gamma replacement adds **no** extra online multiply because source RMSNorm already multiplies gamma. Feature-table dot products, 256 exponentials per two-head token (64 key-decay +64 key-current +128 query weights), numerator rescaling, query readout, source projections/normalization/RoPE, original O projection, packed-control unpacking and code size/registers remain distinct work axes. No native lowering or latency was measured. A full decoded K/V matrix is **not** retained by the inference prefix reader; acceptance transient matrices and dense probability checks are separate from its 33,280-B live state.

## All-window complete response and stronger controls

[`measure.py`](measure.py) pins the [unaltered primary source reader](../qwen-positive-kernel/measure.py) SHA256 `a9e5ee5de5666759964bc93a619a1c78038eff072f18c81c0f55636c3b953c86` and changes only its **Q/K gamma source** to the independently decoded replacement image and its **single shared key feature call** to subtract the independently decoded FP16 center. It asserts the first feature call is K, the next two Q; the original 64-feature table, query key/product math, per-feature log maxima, prefix moment update, original source Q/K/V/O, model/capture identity and observer remain unchanged. The same balanced-gamma source teacher is bitwise the original teacher on all capture windows. Each new window's streaming prefix matches a separately materialized finite-kernel dense probability/V reader within `1.2e−6` absolute maximum; the dense arrays exist only in the acceptance replay. `aggregate.py` requires every original train and held window and SHA-pins three **unchanged** source result files, without rerunning prior fits/readers: primary uncentered/Q4/Q6 (`e99a8f...`), prior centered (`17571c2...`), and [KIVI causal control](../kivi-causal-cache/results.json) (`77a97c4...`). It sums O squared numerators/denominators before division, and averages attention KL over queries.

| Panel | Complete program | Table+center+live or peak cache | Head0 KL | Head1 KL | Head0 post-O | Head1 post-O | **Two-head post-O** |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| train | Unbalanced/uncentered rank64 | 49,664 B | 754.639 | 1265.955 | 2.08054 | 1.42317 | 1.52692 |
| train | Unbalanced/centered rank64 | 49,920 B | 117.821 | 162.824 | 3.09160 | 1.69275 | 1.84791 |
| train | **Balanced/centered rank64** | **49,920 B** | **4.663** | **9.161** | 1.02761 | 1.10938 | **1.09512** |
| train | KIVI 4/4 G32 R32 | 52,400 B peak | .003694 | .001090 | .001103 | .0000409 | **.000136612** |
| inspected held | Unbalanced/uncentered rank64 | 49,664 B | 851.196 | 1359.356 | 1.95922 | 1.44101 | 1.53503 |
| inspected held | Unbalanced/centered rank64 | 49,920 B | 137.244 | 188.419 | 2.48401 | 1.56411 | 1.69048 |
| inspected held | **Balanced/centered rank64** | **49,920 B** | **5.520** | **10.078** | 1.07081 | 1.09894 | **1.09345** |
| inspected held | whole-vector affine K/V Q6 | 51,200 B | 1.44198 | 1.70317 | 1.15447 | .59772 | .65695 |
| inspected held | whole-vector affine K/V Q4 | 34,816 B | 1.67075 | 4.06605 | .62296 | .96938 | .92367 |
| inspected held | **KIVI 4/4 G32 R32** | **52,400 B peak /46,592 B final** | **.004131** | **.001197** | **.001162** | **.0000392** | **.000155355** |

KIVI uses causal per-channel K, per-token-group V and a 32-token BF16 recent buffer, with original source Q/K/V/O and all its field/cache bytes paid; it is a named asymmetric-cache CPU adaptation, not a SOTA full-model claim. At the reported peak it uses 2,480 B more than the positive reader's combined state+table (4.97%), but **its final cache is smaller**. Different token lengths and executable work can change cost ordering; the strong result here is the *same-window* complete O behavior, not dominance over every horizon. The balance/center improves finite-feature output relative to the particular earlier two positive readers, while even KIVI's original score KL/O fidelity remain orders of magnitude better. Continued contexts beyond the twelve reset source windows, whole-model task quality and ISA realization are untested. No second center/seed/rank is being selected after this result.

## Reproduction

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/qwen-balanced-feature-reader/center.py
for i in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/qwen-balanced-feature-reader/measure.py train "$i"; done
for i in 0 1 2 3; do $PY research/isa-quantization/qwen-balanced-feature-reader/measure.py held "$i"; done
$PY research/isa-quantization/qwen-balanced-feature-reader/aggregate.py
```

Each CPU command is under a minute. The final aggregation assumes the parent-integrated primary, prior-centered and KIVI result owners are present in their sibling directories; while they are in separate publication custody, it can instead be invoked with the exact prior-centered and KIVI `results.json` paths as its two arguments (both SHA-pinned). No GPU, new capture, K/V fitter or native speed benchmark is used.
