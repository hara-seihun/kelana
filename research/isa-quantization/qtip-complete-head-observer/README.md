# Frozen official QTIP 3-bit images through the complete Q head

Both [QTIP source-H images](../qtip-full-row-3inst/README.md) were fixed before this study and replayed against the exact same 8×256-token train and 4×256-token inspected-held source windows as the [complete QuIP/scalar observer](../quip-complete-head-observer/README.md). Neither codebook, scale, sign nor trellis state was refitted or selected using the consumer. The stronger natural HYB `L16/K3/V2/Q9`, with upstream's **mandatory kernel tile permutation**, has SHA256 `d06984e4407020db073d9eed087f570315a04fb119c36d96489335f0c5cfd222`, **53,394 B**. Table-free 3INST `L16/K3/V1`, SHA256 `ee55370b26fb39baf0eab0fc4a43ff90ec247d494dfd48dd6e390887aa75f565`, is **49,298 B**. The HYB image supersedes the initially generated *unpermuted*, non-upstream HYB experiment; that earlier digest/score is not an official-fit comparator. Source, exact byte ledger, Viterbi parity and limits are documented with the image owner.

| Panel | Frozen Q image | Image bytes | BF16-rounded raw Q rel sq | Normalized Q rel sq | Attention KL | Head-0 post-O rel sq | GQA-pair post-O rel sq |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| train | QTIP HYB | 53,394 | .02489076 | .04933860 | .02787487 | .02586437 | .00230617 |
| train | QTIP 3INST | 49,298 | .02586830 | .05095867 | .02871865 | .02488485 | .00221883 |
| held | QTIP HYB | 53,394 | .03033812 | .05957940 | .04149888 | .04339551 | .00445657 |
| held | QTIP 3INST | 49,298 | .03109017 | .06217103 | .04472285 | .05242349 | .00538371 |
| held | [QuIP root H](../quip-complete-head-observer/README.md) | 50,322 | .01310947 | .02141683 | .02416825 | .02784225 | .00285930 |
| held | [scalar H](../quip-complete-head-observer/README.md) | 50,320 | .01462970 | .01812619 | .01821224 | .02185195 | .00224412 |

All original K head0, V head0, peer Q head1, Q/K RMSNorm gammas, two-head O columns, and producer captures are unchanged. The common existing affected-group BF16 fields are **1,311,232 B** in every arm, making paid affected-group state **1,364,626 B HYB / 1,360,530 B 3INST** before unchanged generic programs or KV cache. This is not an additional allocation claim. The decoded replacement Q spans every one of 1,024 input coordinates and all 128 head-0 outputs. The original fixture Q equals the checkpoint head elementwise. Projected Q/K/V are BF16-rounded and the same original BF16 RMSNorm, RoPE, causal softmax, V mixing and O projection are observed using the canonical CPU FP32/Torch consumer. The common GQA peer contributes its unchanged O output to the pair denominator, rather than silently being dropped. Attention KL is mean over query positions; Q/O squared-error ratios sum numerators and denominators across windows. Full per-window counts and finite-edit score-variance bounds are retained in [`results.json`](results.json) and `train-*.json` / `held-*.json`.

The fitted first QTIP arm used upstream's no-FT trellis stage, not its optional whole-block fine-tuning, and the numerical consumer is the same CPU approximation as the QuIP study, not native BF16 GPU inference. A **local** loss after this complete head does not rule out a whole-model QTIP rate-distortion advantage, especially with finetuning. No native throughput, decoder-code footprint or full-model NLL was measured. At these frozen observed points QTIP HYB has smaller held head-0 attention KL and O error than its 3INST arm, while their train post-O ranking crosses; neither beats the tested QuIP/scalar held downstream outcomes. This statement does not assign global dominance across differing static sizes and execution work.

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for i in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/qtip-complete-head-observer/measure.py train "$i"; done
for i in 0 1 2 3; do $PY research/isa-quantization/qtip-complete-head-observer/measure.py held "$i"; done
$PY research/isa-quantization/qtip-complete-head-observer/aggregate.py
```

Every 256-token measurement is CPU-only and finishes in seconds. `measure.py` imports the image owner's independent compressed reader and the canonical attention-consumer `head`, `normalized` and `compare` functions; no fitting code is loaded. `aggregate.py` checks every source-row window and image hash before combining them. The source fixture and model checkpoint path/revision are recorded by the canonical observer; no second checkpoint was downloaded.
