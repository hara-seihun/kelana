# Per-expert paid Q3_K/Q4_K allocation on real routed sums

The coarse 32-expert shard result was not a bound on finer image allocation. Reusing **the same frozen Q3_K recode**, choosing 32 individual experts rather than one contiguous 32-expert shard cuts held layer-0 routed-sum RMS from **.024878 to .009186** at exactly the same paid bank rate: 293,076,992 bytes for the layer-0 gate/up pair bank, versus 301,989,888 all Q4_K. Under the conditional forty-layer one-read model this would save **.424232%** of complete weight bytes. The finer granularity crosses a 1% *local* relative-RMS threshold on these 126 held tokens; it does not establish a complete-model language-quality threshold or native speedup.

| Individual Q3_K experts | Train-seen-only train RMS | Train-seen-only held RMS | Held-seen greedy hindsight RMS | Conditional whole one-read bytes saved |
| ---: | ---: | ---: | ---: | ---: |
| 1 | .000396 | .000481 | .000414 | .013257% |
| 2 | .000735 | .000645 | .000596 | .026514% |
| 4 | .001193 | .004125 | .000929 | .053029% |
| 8 | .002114 | .004993 | .001611 | .106058% |
| 16 | .003765 | .006740 | .002997 | .212116% |
| 32 | .006505 | .009186 | .005520 | .424232% |
| 64 | .015134 | .020940 | .011815 | .848463% |
| 128 | .045122 | .049072 | .033195 | 1.696927% |

The held-seen column is a **greedy feasible hindsight selection**, not an optimal lower bound. It asks how much this frozen family might gain from better coverage and an allocation objective, not what any train-only selector can guarantee. At 32 experts the hindsight .005520 versus train-choice .009186 gap is substantial; at 64 experts the same contrast is .011815 versus .020940. Fine allocation advances local quality over the coarse shard, but paying roughly .85% of hypothetical whole-model one-read bytes already exceeds 2% local error with these fixed codes. No model image or runtime has changed.

## Observation and selection contract

The producer input, selected eight IDs, normalized router scores and Q5_K down matrices are the actual installed-GGUF layer-0 capture. For each expert `e`, the saved Q3_K gate/up bytes are read from the [existing straight-recode image](../gateup-q3-recode/README.md). Both Q3_K and installed Q4_K are decoded, followed by FP32 CPU gate/up products, SwiGLU and down products. Their score-weighted difference `d_e(t)` is stored per captured token. Its sum over each 32-expert shard reproduces the predecessor's FP64 partial-output delta to at most **2.55e-8 relative norm**; the full 256-expert sum reproduces its .089569/.084997 train/held relative RMS within 2e-6 after FP32 slot-delta storage.

For a fixed set `S` the observed local FP64 error is `||sum_{e in S} d_e||² / ||complete Q4_K routed sum||²`. Its Gram matrix includes cross-expert cancellations; greedy selection recomputes every candidate's complete-sum squared-error increment. The train-only selection is **restricted to experts selected at least once on train**. This is a necessary honest support rule for this capture: 169 of 256 experts appear in train, 188 in held, only 153 in both and 35 held experts never occur in train. An unrestricted training greedy would take unseen experts at zero train error: its first 32 selected experts have **zero train error** and .006409 held RMS, a misleading numerical-ID tie rather than a transferable fitted allocation. Likewise, an unrestricted held greedy has zero error for its first 64 choices solely by selecting held-unseen experts. Both controls are retained in the receipt so that no one mistakes a zero for an image-quality discovery. The train-seen policy excludes 87 experts from consideration rather than assigning them free Q3.

One paired gate/up Q3_K image is 901,120 bytes per expert; Q4_K is 1,179,648. Every Q3 choice pays 901,120 bytes even if that expert is absent from a captured route. At 32 choices the saved bank bytes are 8,912,896 per layer; extrapolating eight distinct selected expert-image reads at each of forty layers gives 11,141,120 conditional bytes/token saved against a 2,626,187,904-byte one-read complete-model comparator. This is **not** physical DRAM, a measurement of 39 other layers, or a net image-rate including mixed-reader dispatch metadata. At all 256 choices the recode's 3.393853% conditional byte saving incurs .084997 held local RMS. The unchanged native runtime groups experts already; per-expert mixed-format dispatch and image layout must be paid before a kernel port.

This is a better *local* quality/rate frontier than fixed-shard selection, not an accepted serving representation. The earlier 1.727-BPW ternary complete-image pilot and paid residuals showed that even improvements in held local response can reverse in whole-model language loss. Next capture broader quantized producers across layers, freeze a complete mixed image under a genuine storage budget, and measure disjoint complete-model language loss **before** a mixed Q3/Q4 native reader. For an engine-only independent question, the installed ordinary Q8 and expert device phases remain materially larger than this conditional .424% byte prize.

## Custody and replay

[The receipt](/path/to/workspace/data/qwen-moe/q3-expert-allocation/receipt.json) SHA-256 `b22762cb16f65cc1fea45fe4100e145cc201e83d819382035a70d24cd1e02df1` hashes source, parent recode receipt, eight Q3 image shards, eight parent outputs, library and captured inputs/scores, plus every per-expert delta shard. Saved `.npz` files preserve 256 individual complete-output deltas for new allocation objectives without rereading the model. Recompute without GPU or service interruption:

```sh
cd /path/to/workspace/projects/kelana
for i in 0 1 2 3 4 5 6 7; do OPENBLAS_NUM_THREADS=4 python3 research/moe/q3-expert-allocation/experiment.py --part "$i"; done
OPENBLAS_NUM_THREADS=4 python3 research/moe/q3-expert-allocation/experiment.py
```
