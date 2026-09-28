# Response codebooks below one bit per weight

A code labels a short weight vector. For each new activation, the consumer prepares the codeword responses once and accumulates indexed responses across output rows. It does not unpack weights into int4. The numerical map is approximate: these labels are selected for low response error, not exact HALO reproduction.

This first experiment uses the [real Bonsai layer-0 down-projection fixture](../../instances/bonsai-layer00-down-block0.npz), 5,120 rows by 128 ternary coefficients, with eight captured signed-int8 inputs and the original FP16 scale for each row. Its SHA-256 is `70c7180bd822f2a05e2a76e74df657f575caead2da7d526728fbc92831c4bdee`. The dictionaries fit vectors from the first 4,096 rows only. Query indices 0–3 are available for choosing a rate or a calibration metric; indices 4–7 and rows 4,096–5,119 are held out. A further 32–64 random full-range inputs challenge the same held-out rows. Neither this block-level error nor its integer CPU timing is model quality.

## Three ways to spend the labels

A full codebook has `K=2^b` learned vectors of length `d`. The offline encoder chooses one of them for each vector. One dictionary is shared by every position in this 128-coordinate block and every row. For a new query `x`, prepare `T_s[c] = sum_(j<d) x_(sd+j) C_(cj)` for every segment `s`; a row reads its stored `b`-bit label and adds `T_s[label]`. Here coefficients are signed bytes in fixed units of 1/64. The response table holds signed 32-bit integer values, so the table and per-row sum are exact for this codebook. The output divides by 64 and uses the preserved row FP16 scale. This is not the deployed FP32 accumulation order.

Two alternatives address the codebook and preparation costs. `study.py` learns two 16-entry full-vector codebooks and labels each vector by a pair, evaluating two short response tables per segment. `algebraic.py` fits a mean and six learned directions; its 64 codewords are `mean + sum_j sign_j * direction_j`. It stores only seven eight-byte vectors for a length-eight block. Each activation projects seven vectors, then six-add combinations generate the 64 responses. A direct full-codeword dot and the composed-table consumer agree on every tested integer result. The alternating binary-label/least-squares fit reaches a coordinatewise fixed point, not a global optimum.

For a fixed dictionary, choosing the nearest codeword in squared Euclidean distance is globally optimal for each individual vector under that declared objective. For a fixed vector's candidate responses, the `study.py` variable-rate dynamic program gives the minimum **sum of per-segment calibration squared errors** among 4-, 6- and 8-bit labels under 48 label bits per row. Those are deliberately narrow statements. Full-row error includes cross-segment cancellation, and neither theorem says that Lloyd fitting, binary-factor fitting, or the resulting model is globally optimal.

| Codec | Total bits/weight including unchanged scale and dictionary | Held RMS / original RMS | Random-input held RMS | Query-table bytes | Per-row lookups |
| --- | ---: | ---: | ---: | ---: | ---: |
| Full, 16-long, K16 | 0.378 | 0.902 | 0.892 | 512 | 8 |
| Full, 16-long, K256 | 0.675 | 0.747 | 0.750 | 8,192 | 8 |
| Two 16-entry additive, length 16 | 0.631 | 0.757 | 0.754 | 1,024 | 16 |
| Full, 8-long, K16 | 0.627 | 0.743 | 0.750 | 1,024 | 16 |
| Full, 8-long, K64 | 0.881 | **0.604** | 0.610 | 4,096 | 16 |
| Six learned binary directions, length 8 | 0.876 | 0.673 | 0.671 | 4,096 | 16 |
| Full, 4-long, K8 | 0.875 | 0.623 | 0.631 | 1,024 | 32 |

The full length-eight K64 result is the strongest held response fidelity in this paid range. The algebraic codebook loses 0.069 normalized RMS, but cuts dictionary storage from 512 to 56 bytes and preparation from 8,192 integer products to 896 plus at most 6,144 table additions per query. Four-long K8 trades 32 lookups against smaller transient tables. [Full-codebook results](results.json), [short-vector and metric results](short-results.json), and [algebraic results](algebraic-results.json) retain the exact per-case values and source hashes.

The four calibration queries are a trap if treated as the activation distribution. On length-eight K64, assigning labels under 50% empirical covariance cuts training RMS from 0.579 to 0.456, but worsens held RMS from 0.604 to 0.644. At length-sixteen K256 the held error worsens from 0.755 to 0.812. The earlier 0.5-bit Bonsai codec likewise had a calibration error of 25 but an exact full-box error of 11,684. That result and its containment failure are in [the first quantization report](../../README.md) and [producer-domain follow-up](../../PRODUCER.md). With 2,048 separate training inputs on the Qwen fixtures below, the full empirical metric improves validation too. Four captured inputs were not enough; a separate split decides whether calibration transfers.

## A first floating-model check

The pinned [Qwen3-0.6B source](/path/to/workspace/data/kelana-subbit/models/qwen3-0.6b/source.json) is revision `c1899de289a04d12100db370d81485cdf75e47ca`. `float_model.py` fits a separate shared dictionary to each tensor's training rows, preserving an FP16 scale per row and 128 columns. It samples independent held rows from layer-0 and layer-14 down projections and from the tied embedding/head. Codewords are signed bytes with one paid FP32 dictionary unit; exceptionally large centers increase that unit rather than silently wrapping signed bytes. Fixed-rate exceptions store one index byte and one FP16 residual per 128-coordinate block. The table below uses 16 standard-normal input probes and held weight rows, **not model activations, perplexity or generation quality**. Its relative RMS is a useful geometry diagnostic, not a deployment quality metric.

| Tensor | Codec | Total bits/weight on full tensor | Held Gaussian response RMS / original RMS |
| --- | --- | ---: | ---: |
| Down layer 0 | 16-long K64 | 0.503 | 0.829 |
| Down layer 0 | 16-long K256 plus one exception/block | 0.823 | 0.742 |
| Down layer 0 | 8-long K64 | 0.876 | **0.662** |
| Down layer 14 | 8-long K64 | 0.876 | 0.674 |
| Tied embedding/head | 16-long K64 | 0.500 | 0.801 |
| Tied embedding/head | 16-long K256 plus one exception/block | 0.813 | 0.721 |
| Tied embedding/head | 8-long K64 | 0.875 | **0.657** |

[`float-down0.json`](float-down0.json), [`float-down14.json`](float-down14.json) and [`float-head.json`](float-head.json) retain every arm, matrix shape, revision, hashes, row split and exact paid bytes. The one-exception schedule helps but does not close the gap; the 8-long codebook dominates it at similar storage for these Gaussian probes. No exception location or value is free. The fresh FP32 coefficient unit and original BF16 weight tensor are likewise part of the numerical contract.

The model file has 751,632,384 tensor entries, but `lm_head.weight` equals `model.embed_tokens.weight` elementwise. Counting the tied parameter only once gives **596,049,920 unique weights**, of which **155,582,464, or 26.10%,** belong to that shared head/embedding. If the head stays FP16 and every other unique weight reaches 0.875 bits, the all-unique-parameter average is still **4.82 bits**, not sub-bit. This study reports tensor rates; it does not pretend to have compressed every other tensor or to have established a whole-model rate.

## Actual Qwen inputs and the competing quantizer

The [pinned WikiText fixture](/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/manifest.json) has 2,048 train and 1,024 validation inputs for each of sixteen Qwen modules, captured from the unquantized BF16 producer on separate 256-token windows. `real_inputs.py` transfers dictionaries fitted on 75% of weight rows to the other 25%; its sixteen validation RMS values have median 0.558 and range 0.268–0.645 at train-selected rates below 0.9 bits. This is a **dictionary-transfer diagnostic**, not a fair handicap for model-specific quantization: the actual model makes all weight rows available.

`all_rows.py` fits dictionaries on **all known weight rows**, encodes and scores every output row, and selects its best arm under 0.9 bits from training inputs alone. Validation inputs are held out. Each arm checks actual packed labels, prepared response tables, FP16 scales and its paid correction against an independent dense matrix product. The fixed-width label image is implemented in [`wire.py`](wire.py); [`test_wire.py`](test_wire.py) covers all bit widths and exception addresses past byte 255. Optional corrections are a train-input mean output bias at two bytes per row, one signed FP16 residual and byte index per 128 weights, or an FP16 low-rank cross-row residual whose two matrices and runtime dot products are charged. The affine map need not recover the original weights; it must approximate the requested output response.

The strong matched control is the [pinned NanoQuant ADMM-only comparator](../binary-factors/README.md). It fits **all** rows too, uses the same train/validation inputs, and reports squared response error from its serialized signs and FP16 scales. Its initialization does not include the published method's later reconstruction tuning. The codebook entries below are validation RMS **squared** to match that control; all rates include labels, dictionary, FP16 row-block scales, the FP16 correction and any stored bias.

| Matrix | Response-codebook arm selected on train | Codebook BPW | Validation squared error | NanoQuant BPW | NanoQuant validation squared error |
| --- | --- | ---: | ---: | ---: | ---: |
| Layer 0 q_proj | 16-long K256, full input covariance, rank-10 residual + bias | 0.891 | 0.08588 | 0.773 | **0.07368** |
| Layer 14 down_proj | 8-long K64, full input covariance + bias | 0.882 | 0.37527 | 0.771 | **0.31712** |
| Layer 27 q_proj | 16-long K256, full input covariance, rank-10 residual + bias | 0.891 | 0.12619 | 0.773 | **0.08859** |

[`all-layer00-self_attn_q_proj.json`](all-layer00-self_attn_q_proj.json), [`all-layer14-mlp_down_proj.json`](all-layer14-mlp_down_proj.json) and [`all-layer27-self_attn_q_proj.json`](all-layer27-self_attn_q_proj.json) retain every tested arm and the source/fixture identities. The [NanoQuant payload and error records](../binary-factor-points.json) supply the comparator. This bounded family loses at **higher** rate on all three. A mere locality or lookup optimization cannot repair its rate-quality deficit.

There is still a useful design signal. On all-row layer-0 q_proj, a length-16 K256 codebook plus bias starts at 0.656 bits and 0.383 validation RMS; adding a rank-10 cross-row response correction reaches 0.293 RMS at 0.891 bits. A grouped, activation-covariance-trained dictionary (`joint.py`) reaches 0.362 RMS in the held-row transfer experiment, only slightly better than one shared dictionary. On layer 14 down, rank-10 correction reaches 0.656 RMS at 0.849 bits, worse than the shorter-vector arm's 0.613 RMS. The correction is not a free new table: rank `r` costs `2r*(rows+columns)` FP16 bytes, `r` input dot products per query and `r` multiply-adds per output row. [`lowrank-*.json`](lowrank-layer00-self_attn_q_proj.json) and [`joint-*.json`](joint-layer00-self_attn_q_proj.json) retain those held-row probes separately from the fair all-row result.

These are **isolated projection responses** in FP32 arithmetic. They do not establish BF16 execution semantics, final logits, perplexity or whole-model rate. The parent programme has an independent full-model reference pilot; this study does not substitute these ratios for it. A better next construction would share an input-conditioned first stage across projections, or apply response labels to a factorized residual where the [binary-factor control](../binary-factors/README.md) already captures cross-row structure. Test a complete module continuation and tied-head quality before kernel work. The current codebook arm does not earn a gfx1151 implementation.

## Actual storage and execution budget

For `R=5120, C=128, d=8, b=6`, labels occupy `R*C*b/d = 61,440` bytes after six-bit packing. The shared dictionary is `64*8 = 512` bytes, and the unchanged FP16 scale is 10,240 bytes: 72,192 bytes, or 0.88125 bits per original weight. HALO uses 143,360 bytes for the same block including scale, 1.75 bits per original weight. The 4,096-byte response table is temporary **per query**, not free static storage. Extending to a layer requires a stated dictionary-sharing policy and row-scale recipe; adding a codebook per small row group can erase the nominal sub-bit rate. Source labels, dictionary, scales, input transfer, table build, lookups, output and any FP boundary all belong in the cost.

A gfx1151 program would stage the 4 KiB response table in LDS or distribute it through waves. It must construct 8,192 coefficient products or the algebraic alternative's 896 products plus additions for each new query, then perform 81,920 indexed loads and accumulations for this block. At the previously measured 242 GB/s streaming rate, the saved 71,168 static bytes represent only **0.294 µs** at a bandwidth roof. A table launch, divergent LDS addresses and dependency chain can easily spend that budget. The [native gfx1151 control](../../gpu-direct/README.md) takes 3.505 µs for a two-bit 5,120-by-128 integer block; a different exact sign-orbit table program takes 9.299 µs despite fewer bytes. These are comparison points, not timings for this lossy codebook.

For the all-row layer-0 q-projection winner, the 2,048×1,024 matrix stores 131,072 packed label bytes, 32,768 block-scale bytes, 4,100 dictionary bytes, 61,440 rank-10 factor bytes and 4,096 output-bias bytes: **233,476 bytes, or 0.89064 bits/weight**. A new input needs 64×256 FP32 response entries, **65,536 transient bytes**, and 262,144 codeword/input products before 131,072 row lookups, ten input-factor dot products and ten corrections per row. A whole table staged per workgroup could exceed a useful LDS residency budget; tiling, scratch reuse and query-batch sharing need a real program. The comparable NanoQuant .773-bit q-projection payload is 202,752 factor-and-scale bytes and has a different two-stage online work map. Neither method has a gfx1151 timing at this Qwen boundary.

The installed Ryzen AI MAX+ 395 has AVX-512 VNNI and VBMI. Its 64-entry byte permute can index a byte response, but a signed 32-bit response needs four byte planes and recomposition, or vector gathers. Packing six-bit labels also costs shifts and masks. The paired native integer-block panel compares a scalar table consumer with a dense decoded-coefficient VNNI control **on precisely the same approximate codeword matrix**, so quantization quality cannot explain its speed difference. All 40,960 outputs from eight captured queries match an independent NumPy integer oracle in both arms. Nine rotated rounds of 256 iterations give medians of **4.665 µs dense VNNI**, **14.559 µs compact with prepared table**, and **14.869 µs compact with fresh table**. The dense arm stores 655,360 coefficient bytes plus 20,480 precomputed row-sum bytes; the compact arm stores 61,440 labels plus 512 dictionary bytes and prepares a 4,096-byte table. Both omit the identical row scales. These cache-resident CPU times reject this scalar gather lowering, not the representation or a future vectorized consumer. [Raw samples and identities](native-results.json) retain source, binary, compiler and exact input hashes; [`native.zst`](native.zst) retains the measured executable. The CPU crossover requires a consumer that removes at least 10.2 µs from packed indexing at this 5,120-row boundary, or a workload whose avoided memory traffic is much larger than this block's cache-resident VNNI stream.

## Reproduce

Run each foreground command from this directory, on the recorded host. NumPy's BLAS uses one thread so individual runs finish in seconds:

```sh
OPENBLAS_NUM_THREADS=1 python3 study.py
OPENBLAS_NUM_THREADS=1 python3 short.py
OPENBLAS_NUM_THREADS=1 python3 algebraic.py
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python float_model.py down0
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python float_model.py down14
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python float_model.py head
OPENBLAS_NUM_THREADS=1 python3 test_wire.py
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python real_inputs.py layer00-self_attn_q_proj.npz
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python joint.py layer14-mlp_down_proj.npz
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python lowrank.py layer27-self_attn_q_proj.npz
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python all_rows.py layer00-self_attn_q_proj.npz
OPENBLAS_NUM_THREADS=1 python3 native_fixture.py build
c++ -O3 -std=c++20 -mavx512vnni -mavx512bw -mavx512f native.cpp -o build/native
build/native build > build/raw.json
python3 record_native.py
```

`build/` is disposable. The committed JSON records include hashes of the fixture, source, retained native executable and generated input files. No GPU, model download or serving code is touched.
