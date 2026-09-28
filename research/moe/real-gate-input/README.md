# Actual-route common input codes through the GGUF expert sum

The existing native grouped-expert path prepares an input code once per token for gate and up. This experiment asks what an even smaller *shared* code does to the composed routed output on the pinned Qwen3.6-35B-A3B GGUF, before changing that path. It uses the selected layer-0 runtime's actual 113 train and 126 held token captures. Every token has its actual 2048-dimensional normalized producer input, eight IDs and scores. The study decodes all observed experts from the full 256-expert Q4_K gate/up and Q5_K down banks, rather than substituting the first sixteen official BF16 experts.

The finite code family uses signed group-32 integer codes, one FP16-rounded scale per group and nearest-even rounding. One 2048-coordinate code is reused by both projections and all eight selected experts. The three arms are Q4 at max and .75-max clipping, and Q8 at max clipping. The reader recomputes the FP32 gate/up products, SwiGLU, down products and an FP64 score-weighted sum. The reference repeats that offline map without input coding. Thus this measures a *local approximation*, not native bit equality or complete-model language loss. Native captured output differs from the offline reference by .01787/.02011 RMS on train/held, and the uncoded offline SwiGLU hidden differs from the captured hidden by .01590/.01893. Native Q8_1 input coding and device operation order are not this CPU map.

| Shared input code | Paid bytes/token for one code | Train routed-sum relative RMS | Held routed-sum relative RMS |
| --- | ---: | ---: | ---: |
| Q4 max | 1,152 | .09887 | .09349 |
| Q4 .75 max | 1,152 | .17320 | .17225 |
| Q8 max | 2,176 | .00565 | .00543 |
| Free per-token best Q4 clip | 1,152 plus unpaid choice | .09887 | .09349 |

The train-selected Q4 clip is max. Even a hindsight selector allowed to inspect each token's **complete uncoded routed output** chooses max for every one of the 113 train and 126 held tokens. For this two-clip family, the oracle's SSE is exactly the sum of the smaller of the two per-token SSEs. No selector restricted to these clips improves its local held output. This does not bound a learned code, a different group size or the complete network's observer. Its uncharged selection work makes the oracle favorable to Q4.

The rate saving alone is tiny. Q4 rather than matched Q8 saves 1,024 bytes per token at this shared-code boundary. If all forty layers had the same opportunity, that is 40,960 bytes, **0.00156%** of the modeled 2,626,187,904-byte one-read whole-model weight stream. Even assuming a separate copy to every expert slot, the upper saving is 327,680 bytes, **0.0125%**. The eight Q4_K gate/up images alone are 9,437,184 bytes per layer, so a direct Q4 operand may still reduce *dot work* or register pressure, but input-buffer traffic cannot explain a whole-model gain. Native Q8_1's scale/metadata layout differs from this matched code; the byte comparison is a conditional storage bound, not a native allocation measurement.

This closes max-versus-.75 scalar clipping on the observed real routes, and says not to port Q4 merely to save the shared input buffer. The next worthwhile representation is a jointly trained gate/up **weight-and-input** code whose packed consumer skips weight traffic or operand work, with held complete-model loss at its paid image rate. The earlier 1.727-BPW ternary pilot improved local objectives yet remained far behind BF16 on full-model loss; this routed-sum RMS alone cannot select a model image. The independent exact-engine Q8 phase and DRAM-byte question remains open. No GPU, installed runtime or service changed here.

The CPU receipts are [`train.json`](/path/to/workspace/data/qwen-moe/real-gate-input/train.json) and [`held.json`](/path/to/workspace/data/qwen-moe/real-gate-input/held.json). Each records source, inventory, capture-array, decoder-library and complete model hashes, plus the three arm SSEs and the oracle. Reproduce from the Kelana root with the selected GGUF installed:

```sh
for split in train held; do
  OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/real-gate-input/study.py \
    --split "$split" --output "/path/to/workspace/data/qwen-moe/real-gate-input/$split.json"
done
```
