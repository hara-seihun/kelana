# Mixed precision for the tied Qwen head and embedding

Qwen3-0.6B's tied 151,936 × 1,024 BF16 head and input embedding account for 26.10% of its unique weights. The [first tied-head study](../tied-head/README.md) found that a K256 direct-response codebook plus 2,560 frequent BF16 rows costs 0.895325 bits per tied weight and gives 4.429 head NLL on 64 fixed held WikiText positions. Its rare input-token rows remain poor. I tried two different ways to spend roughly the same bytes: a signed low-rank residual on every row, and RTN4 precision allocated to head-sensitive rare rows as well as frequently embedded rows.

The low-rank residual loses. The mixed-rate image is a tradeoff, not a clean win. At **0.893824 bits**, it reduces held head KL from 0.917 to 0.811, improves top-token agreement from 50/64 to 56/64, and reduces token-frequency-weighted input-embedding relative RMS from 0.416 to 0.394. But its held NLL **rises** from 4.429 to 4.593. Three of the held gold tokens land in its RTN4 tier. A mixed-rate head image is worth a model-continuation test, but these fixed-input observations do not establish a whole-model improvement.

## Train and validation boundary

This study reuses the pinned Qwen revision `c1899de289a04d12100db370d81485cdf75e47ca`, [actual final normalized input capture](/path/to/workspace/data/kelana-subbit/tied-head/capture.json), and full WikiText-2 raw train and validation token frequencies. Dictionary fitting, row allocation and rare-head temperature/offset use only train weights, train normalized inputs, train next tokens and train corpus token counts. All model weights are known to the quantizer. The **64 validation head positions** and full validation corpus frequencies are held out. The captured BF16 reference NLL is 3.610259. Gold tokens come from the validation next-token stream, not the training row selector.

The scoring replay feeds the *original-model* normalized final inputs into the compressed head. It measures tied input embeddings by decoding selected rows and weighting their squared error by full validation corpus token occurrences; it does not propagate changed embeddings through transformer layers. The candidate scores are FP32 dot/table calculations, not bit-exact BF16 serving scores. Plain scalar RTN2 and RTN4 controls use group-128 symmetric midrise rounding and packed payloads from the first study. They are not reconstruction-aware quantizers.

## Serialized shared images

[`mixed.py`](mixed.py) keeps the previous K256 16-coordinate codebook with its 64 labels and eight FP16 scales per row. It stores the 2,048 most frequent train token rows as exact BF16 with four-byte row IDs. Among the remaining rows, it stores 1,440 ranked by mean absolute train softmax-probability error over 128 real train head inputs and 480 by further train input-token frequency. Those 1,920 rows use group-128 RTN4: two 4-bit signed-midrise values per byte, eight FP16 scales and a four-byte ID per row. The base labels/scales are retained for all rows, including the overridden rows, and paid in full. An additional train-fitted global FP32 temperature and offset apply **only** to the remaining K256 head scores; those two numbers do not alter input embeddings. The array payload is 17,382,916 bytes plus eight head-only bytes, **17,382,924 bytes total**. `mixed256.npz` is the single saved matrix image; `mixed256.json` identifies its source and input hashes. NPZ container overhead is not counted as runtime payload.

For a head input, form 64 × 256 table responses, score all vocabulary rows through their stored labels and scales, then replace 2,048 outputs by exact BF16 dot products and 1,920 by packed RTN4 row dot products. The codebook table requires 262,144 multiply terms and 65,536 transient bytes. The base all-row consumer has 9,723,904 indexed responses. Overrides add 2,097,152 exact BF16 products, 1,966,080 RTN4 products, 983,040 nibble decodes, and 15,360 RTN4 block scales per query. It writes 151,936 FP32 scores. This is substantially more online work than the original K256/2,560-exact image's 2,621,440 override products. No native GPU timing or speed claim exists.

An input embedding decodes **one row** from the same image: exact BF16 for the first tier, RTN4 nibbles and block scales for the second, or 64 K256 labels and eight scales for the remaining rare tier. The tied-storage property is real, but the input-row decoder and the head scoring program have different work. On the validation corpus, exact rows cover 76.04% of token occurrences, RTN4 rows another 4.71%, and the base codebook the remaining 19.25%.

[`fit.py`](fit.py) and [`evaluate.py`](evaluate.py) test another complete representation. A rank-64 signed residual adds one packed bit per basis direction and one FP16 amplitude per row to the earlier K64 codebook. The basis contains 32 residual-weight directions and 32 directions responding to real train final-head inputs. It fits on 12,065 known weight rows, then encodes every row in eight reproducible shards. `signed64.npz` contains all base labels, scales, 64 FP16 basis rows, sign bits and FP16 amplitudes. Each `factor-exactN.npz` contains its corresponding exact-row IDs and original BF16 bits; **both images** together represent a complete tied matrix. The decoder adds `amplitude[row] × sum(sign[row,j] × basis[j,:])` to its codebook row, with an exact override when selected. The head can prepare 64 factor responses per input and accumulate signed, scaled values directly, without forming the residual matrix. This residual removes only about 9–15% of base residual mean squared error by row shard and does not improve the head enough to justify its extra bytes.

## Held result

Every row's logits participate in each NLL and KL. The source image and paid overrides, not NPZ compressed file lengths, set the rate. Input RMS weights rows by validation corpus occurrence count. The rare-only RMS conditions on rows without exact or RTN4 overrides.

| Shared matrix / fixed original-model inputs | Bits/weight | NLL | KL | Top token | Input RMS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original BF16 | 16 | 3.610 | 0 | 64/64 | 0 |
| K256 + 2,560 frequent exact BF16 + rare head correction | 0.895325 | **4.429** | 0.917 | 50/64 | 0.416 |
| K256 + 2,048 exact + 1,920 rare RTN4 + rare head correction | **0.893824** | 4.593 | **0.811** | **56/64** | **0.394** |
| K64 + signed rank-64 residual + 2,816 exact BF16 + correction | 0.882043 | 5.081 | 1.442 | 52/64 | 0.411 |
| Plain group-128 scalar RTN2 | 2.125 | 4.886 | 1.375 | 21/64 | 0.507 |
| Plain group-128 scalar RTN4 | 4.125 | 3.571 | 0.038 | 58/64 | 0.102 |

The mixed image repairs some rare head errors and embeddings but not the long tail. Its validation gold-token NLL is 8.767 on the 22 positions outside its exact tier, compared with 8.606 on the 21 outside the original image's exact tier; these are different subsets, not a matched conditional effect estimate. The base-codebook-only rare input embedding relative RMS is 0.834 in both plans. The output RMS over *all* logits actually grows from 2.096 to 3.602 because calibration and sparse overrides optimize distributional error, not squared logit error. Inference quality must not be inferred from its top-token improvement alone.

A later image worth testing should model the remaining rare rows with more information per important row **without** relying on final-head softmax discrepancy alone: the train head ranking helped KL and top agreement, while held gold-token likelihood did not improve. The signed rank-64 update is a concrete negative for this residual family under this fitting objective, not a lower bound on all factorized tied representations. No head-only image here establishes a whole-model sub-bit model.

## Custody and reproduction

[`results.json`](results.json) is the compact report. [`record.py`](record.py) checks source, model, capture, basis, shard and finished-image hashes against the saved receipts. The images, shard evidence and detailed quality reports live under [`/path/to/workspace/data/kelana-subbit/tied-factors/`](/path/to/workspace/data/kelana-subbit/tied-factors/), outside Git; the pinned source model and original head data stay under `data/kelana-subbit/models/qwen3-0.6b/` and `data/kelana-subbit/tied-head/`. Do not replace the captured validation logits with a newly sampled window when comparing.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=research/quantization-discovery/subbit/tied-factors
OPENBLAS_NUM_THREADS=2 $P "$S/fit.py" train
for n in 0 1 2 3 4 5 6 7; do OPENBLAS_NUM_THREADS=2 $P "$S/fit.py" encode "$n"; done
OPENBLAS_NUM_THREADS=2 $P "$S/evaluate.py" assemble
for n in 2048 2560 2816; do OPENBLAS_NUM_THREADS=2 $P "$S/evaluate.py" assess "$n"; done
OPENBLAS_NUM_THREADS=2 $P "$S/mixed.py" build
OPENBLAS_NUM_THREADS=2 $P "$S/mixed.py" assess
OPENBLAS_NUM_THREADS=2 $P "$S/diagnostics.py"
python3 "$S/record.py"
```

Each encoder shard and replay command is a bounded foreground CPU job. The fit uses the existing pinned weight/capture assets and no new GPU work. The scripts retain SHA256 receipts and independently check selected decoded rows against dense row products.
