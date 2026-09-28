# Native-format Q3_K gate/up recoding on actual Qwen routes

**The direct Q4_K → Q3_K gate/up recode loses 0.084997 relative RMS on 126 held actual routed layer-0 expert sums.** The same calculation on 113 disjoint train tokens loses 0.089569. The image is real GGML Q3_K, 110 bytes per 256 weights, produced by the selected library's quantizer from the *decoded installed Q4_K* gate/up bank; every expert is recoded and both packed banks are retained in the [data owner](/path/to/workspace/data/qwen-moe/gateup-q3-recode/). Original Q5_K down, the eight actual selected IDs, normalized scores and real post-attention producer inputs are unchanged. The local reference runs those same decoded installed Q4_K/Q5_K weights without recoding. This is a measured rejection of **straight static Q3_K recoding** as an immediate inference image, not a bound on trained three-bit codes or an inference-speed result.

| Layer-0 gate/up image | Bytes across 256 experts | Bytes for eight selected gate/up pairs per layer | Relative routed-sum RMS, train / held |
| --- | ---: | ---: | ---: |
| Installed Q4_K, decoded reference | 301,989,888 | 9,437,184 | 0 / 0 |
| Native Q3_K from decoded Q4_K | 230,686,720 | 7,208,960 | .089569 / .084997 |

The recode removes 71,303,168 bytes from this complete layer bank. If all forty layers had this quality and eight separately read images per layer, the *conditional logical one-read* saving would be 89,128,960 bytes per token, 3.394% of the pinned model's 2,626,187,904-byte stream. It changes neither the eight down-bank reads nor nonexpert and output-head weights. Expert grouping can reduce marginal bytes on prompts; cache transactions and native Q3_K instruction costs are unmeasured. No output benefit may be inferred from this local distortion. A Q3_K packed consumer exists in the reference engine, but whether its arithmetic or layouts beat the current Q4_K expert path needs native measurement **only after** a trained, paid image survives complete-model held language loss. The 0.6B ternary/sub-bit pilots repeatedly improved local error while failing complete-model quality, so local reconstruction must not be the serving selector.

## Observation and limits

Both splits use the pinned actual layer-0 native capture: 113 train and 126 held producer tokens, each with eight observed experts among all 256 and their normalized FP32 router scores. The 256 experts are quantized offline, including IDs absent from either split. For each expert, the installed Q4_K gate/up and Q5_K down matrices are decoded, the Q3_K gate/up matrices are quantized and decoded with `quantize_q3_K`/`dequantize_row_q3_K`, and each split's selected rows run FP32 BLAS gate/up, FP32 sigmoid/SwiGLU and FP32 down. Score-weighted eight-expert sums are accumulated in FP64. Relative RMS is `sqrt(sum_t ||y_Q3(t)-y_Q4(t)||² / sum_t ||y_Q4(t)||²)`. The offline unchanged image differs from recombination of native captured down outputs by 0.01787 train and 0.02011 held RMS: the offline reduction is not the selected GPU's bit contract. This is local layer-0 output quality, not next-token loss, exact FP32 identity, direct packed execution cost, or a forty-layer quality extrapolation. The comparison uses the *installed Q4 image* as the quality reference, not original BF16.

The [receipt](/path/to/workspace/data/qwen-moe/gateup-q3-recode/receipt.json), SHA-256 `0f094c2c824242f973a3aab5bd1c897c975d402c568bb182c8a2cd39b958dd33`, binds the source hash, model, library, inventory, train/held captures, eight complete image shards and output shards, per-token errors and denominator. Q3 image shards total 230,686,720 bytes, without including packaging; the unchanged installed down and nonexpert images remain separate. The work is CPU-only; it did not touch either serving runtime, the GPU or the resident service.

From a registered Kelana writer using the pinned installed runtime, process independent 32-expert intervals and combine:

```sh
for i in 0 1 2 3 4 5 6 7; do
  OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/gateup-q3-recode/measure.py --part "$i"
done
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/gateup-q3-recode/measure.py --combine
```

**Next:** a new Q3_K image must be fitted against actual producer gate/up activations and the *complete routed sum* with broader train and disjoint held text, rather than independently rounding installed Q4 weights. Because train-unseen experts make single-layer calibration fragile, allocate Q3/Q4 per expert with explicit byte budget and then score a complete forty-layer image on held language loss. If that fails, spend native effort on the measured Q8 projection and Q4/Q5 expert consumer rather than another local scalar-fit tweak.
