# Shared key scores on a quantized upstream producer

The frozen shared three-dot Q/K score does survive a different input producer at Qwen3-0.6B layer 14. Replacing layers 0 through 13 with the paid .62454-BPW binary body and norms changes the input entering layer 14. On four held 256-token validation windows, the original-producer-trained three-dot consumer has causal KL .278158 against .276883 for four dots and .281085 for independent three dots. Its complete attention-plus-original-O relative squared error is .020591 against .020487 for four dots and .020797 for independent three dots. The third dot saves one quarter of the four-dot key-score products without expanding a key into int4 or a floating vector. This is a useful quality transfer, not a native time or complete-model loss result.

| Frozen score map | Dots per GQA pair/key | Held causal KL | Held post-O relative squared error |
| --- | ---: | ---: | ---: |
| Two independent signed-nibble queries | 2 | .286955 | .021585 |
| Independent signed-byte plus signed-nibble | 3 | .281085 | .020797 |
| Shared signed-byte base plus nibble difference | 3 | **.278158** | **.020591** |
| Two signed-byte queries | 4 | .276883 | .020487 |
| Unrounded query against the same signed-nibble K codes | floating control | .276837 | .020485 |

The three-dot image keeps the parent's 128-byte padded signed-nibble K cache per token/layer, paid binary Q/K weights, train-chosen center/steps and per-group base-head choices. Its exact integer key inner products cost 768 signed-nibble coordinate products/key/layer rather than four dots' 1,024. Per token/layer, both prepare 512 key-step-scaled query coordinates; the shared map also subtracts 256 coordinates, and per cached key adds eight base scores to eight difference scores. It still computes the full 1,024 raw K rows for RMSNorm. There is no measured gfx1151 issued-dot, register, occupancy, producer, softmax or full-layer latency. Reducing products by 25% is not a claim of 25% lower inference time.

## Observation and selection

The input is the existing captured BF16 pre-Q hidden state, with the original tied embedding and quantized upstream layers 0 through 13. For every such input, the teacher uses original layer-14 Q and K, original V and O, and all 256 causal keys. The candidates use the *same* original V/O response, the same paid binary layer-14 Q/K images, BF16 group key affine, post-RoPE selected-coordinate signed-nibble codes, coordinate steps and centers. Only query-code preparation differs. The measured post-O response accumulates both observing query heads across all eight GQA groups before comparing to the teacher. Its V projection rounds to BF16, and CPU FP64 score/softmax/output accumulation deliberately does not claim HF FP32 bit identity.

Four train and four validation windows are disjoint WikiText splits, but the parent key image and base-head policy came from earlier original-producer training, and these validation windows have been used by other studies. We held every policy fixed for the table. Reselecting only the eight base heads on the four new train windows worsens held KL from .278158 to .278353, so the transfer is not an artifact of retuning on this tiny producer capture. The four frozen shared-map held KL values are .293617, .255774, .312190 and .251052; each beats the independent three-dot map on the same window. Its per-window post-O errors are .029304, .017163, .026525 and .007772, against four dots' .029235, .017091, .026427 and .007590. Post-O sharing beats independent three dots on three windows, not all four. On the original producer, the same frozen base policy scored .334929 KL against four dots' .332396. The numerical KL comparison across producers is not a matched teacher or input distribution; the within-producer comparisons are.

`measure.py` replays the parent score maps. The receipt at `/path/to/workspace/data/kelana-subbit/shared-query-producer-transfer/layer14.json` includes each group and window, train/held KL, the complete post-O response, both base choices, static costs and SHA-256 of the model, upstream capture/receipt, paid Q/K images, parent key/affine/three-dot receipts and source. CPU only. Reproduce from a Kelana writer checkout:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/shared-query-producer-transfer/measure.py \
  --output /path/to/workspace/data/kelana-subbit/shared-query-producer-transfer/layer14.json
```

The next experiment should fit the Q/K producer, key labels and query consumer against a broader quantized-upstream causal/post-O objective, with fresh model loss. If it still keeps the three-dot quality close to four dots, time a fused two-head native score including query subtraction, dynamic maxima, score additions and append at occupied context. Neither another frozen covariance sweep nor a dot count alone settles that decision.
