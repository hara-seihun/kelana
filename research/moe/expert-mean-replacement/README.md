# Can a small per-expert prototype replace one routed computation?

The actual layer-0 Qwen3.6-35B-A3B capture contains eight normalized router scores and eight 2,048-coordinate down outputs per token. A fixed per-expert **mean output** is a compact replacement direction: load 4 KiB rather than execute that expert's gate/up/SwiGLU/down path. This is distinct from omitting the original vector or reweighting the seven survivors. The proposal is conditional on finding an executable error selector and on native dispatch actually avoiding the selected image; neither is assumed.

A train-only mean from 113 real-text tokens was rounded to FP16 and stored for all 256 expert IDs (unseen entries zero). The paid layer-0 prototype bank is **1,048,576 bytes plus a 32-byte coverage mask**. On 126 disjoint held tokens the selection rule picks the *lowest-scored trained* expert and substitutes its stored mean; all 126 have one available. The same selected expert's zero replacement (omission) is the matched control. Sums and errors are evaluated in FP64 using the captured FP32 down outputs and scores.

| Layer-0 complete weighted-sum observation | Train relative RMS | Held relative RMS | Held tokens below 1% / 5% local relative error |
| --- | ---: | ---: | ---: |
| Omit lowest-score trained expert | .103520 | .088760 | 0 / 39 |
| Substitute its paid FP16 mean | .092322 | **.100251** | **0 / 35** |
| Free hindsight choice of *which* trained mean to substitute | .057824 | .079126 | 1 / 41 |

The score rule improves train RMS and 90/113 train tokens against omission, but improves just **32/126 held tokens** and worsens aggregate held RMS. The free hindsight choice needs the missing output to select its expert and is not an online algorithm. Even this stronger selector reaches 1% local error on only one held token. The paid mean image cannot produce a high-fidelity one-expert skip on this capture. Its 5%-eligible score-rule opportunities would save at most 35 × 76,439,552 / (126 × 2,626,187,904) = **0.809%** of conditional complete-model one-read weight bytes if all forty layers behaved like layer 0, with a *free* error certificate and free dispatch. No practical policy has this local certificate; the prototype bank's resident traffic and online lookup/add are not deducted from the optimistic byte number. The full image would cost 41,944,320 bytes plus 1,280 mask bytes over forty layers before addressing, alignment and scheduling.

The result rejects a **constant expert-direction table learned from 113 producer examples**, not a learned input-dependent predictor. The key next question is whether broader producer data can predict the missing output *from the shared input* at a paid rate and whether a complete frozen model retains held language loss. A deeper fixed codebook on these same sparse per-expert observations is not justified by this train/held reversal. The native priority is still unprofiled Q8 and expert-phase diagnosis, not porting this local prototype.

## Reproduce and contract

```sh
OPENBLAS_NUM_THREADS=1 python3 research/moe/expert-mean-replacement/study.py \
  /path/to/workspace/data/qwen-moe/route-capture \
  --out /path/to/workspace/data/qwen-moe/expert-mean-replacement/receipt.json
```

[The raw receipt](/path/to/workspace/data/qwen-moe/expert-mean-replacement/receipt.json) SHA-256 `30a90955af5d1c5fe43578e4adba141f9bff63657655c9dfb1632ac2772bdf83` hashes the source, train/held text and captures, actual paid FP16 bank and coverage mask; it keeps per-threshold counts, expert coverage and selector-rank histograms. The capture's selected GGUF and producer provenance is in [Bonsai's route report](../../../../bonsai-halo/docs/qwen-moe-routes.md). The domain is these finite layer-0 callback-observed tokens and their FP64 recombination, **not** the installed FP32 reduction or a complete-model quality panel. The conditional traffic projection grants all forty layers this layer's behavior, one uncached read of each selected expert image and free selective dispatch. No GPU, serving image or runtime changed.
