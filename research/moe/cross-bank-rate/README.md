# Disjoint expert-bank recoding on actual routed producers

Can two native packed-format changes share the layer-0 rate budget without compounded routed-sum error? **Yes at a small local rate point, but the errors do not cancel.** With 16 Q3_K gate/up experts and 32 Q4_K down experts (distinct IDs), the frozen train-selected image loses **.007387 held routed-sum RMS**, versus .009186 for 32 Q3 gate/up experts alone at a similar conditional complete one-read saving (.411754% versus .424232%). A down-only 64-expert recode instead loses .006928 at .399277%. This is a new measured *local* rate/quality comparison, not a whole-model quality or GPU speedup. At the more ambitious 32 Q3 plus 64 Q4 down point, .823508% conditional traffic reduction costs .020779 held RMS. The practical next question is broad producer-calibrated complete-image language loss, not assuming cancellations rescue untrained codes.

| Q3 gate/up experts | Q4 down experts | Selection | Layer-0 gate/up+down bytes | Held RMS | Conditional whole one-read saving |
| ---: | ---: | --- | ---: | ---: | ---: |
| 0 | 32 | train-seen, down-first | 482,344,960 | .002915 | .199638% |
| 0 | 64 | train-seen, down-first | 478,150,656 | .006928 | .399277% |
| 32 | 0 | train-seen, gate-first | 477,626,368 | .009186 | .424232% |
| 16 | 32 | gate-first | 477,888,512 | .007387 | .411754% |
| 16 | 32 | down-first | 477,888,512 | .013435 | .411754% |
| 32 | 32 | gate-first | 473,432,064 | .011197 | .623870% |
| 32 | 64 | gate-first | 469,237,760 | .020779 | .823508% |
| 0 | 128 | down-first | 469,762,048 | .024745 | .798554% |

The same-budget selection order matters: at 16+32, gate-first .007387 versus down-first .013435 held. Neither is the optimal fixed-bank selector. For the disjoint chosen expert sets, held cosine between the complete Q3 and Q4 error fields is .0003 at 16+32 and .0040 at 32+32 (gate-first). These results reject large helpful cancellation on **these particular allocations**, not all joint recodes or trained expert codes. Across the saved panel, 32+128 gate-first loses .039902 RMS at 1.222785% conditional bytes. The model has not been run with these images.

## Why disjointness is essential

On a selected expert `e`, let `G4,U4,D5` denote decoded installed images; `G3,U3` and `D4` are frozen native-format recodes. We allocate at most one recode to any expert. Thus its output is **either** `D5 SwiGLU(G3 x,U3 x)` **or** `D4 SwiGLU(G4 x,U4 x)` **or** the original `D5 SwiGLU(G4 x,U4 x)`. The score-weighted complete routed response is the reference plus the selected per-expert response deltas, exactly as a real-arithmetic statement under the declared offline FP32 BLAS/SwiGLU products and FP64 routed reduction. For overlapping bank changes, the omitted interaction `(D4-D5)(SwiGLU(G3x,U3x)-SwiGLU(G4x,U4x))` would invalidate this sum. We do **not** use that approximation or count an unverified overlapping image as measured.

The earlier down-allocation deltas used captured native post-SwiGLU hiddens, whereas the gate/up study recomputes offline `G4,U4` hiddens. They are not automatically the same producer: even the two reference output norms differ by about .000691 relatively. We use the older native deltas only to *select* IDs on 113 training tokens. For every selected Q4 down expert we regenerate the exact same paid train-weighted packed recode and recompute its delta on the offline Q4 gate/up hidden, on both train and 126 held tokens. Replaying its packed recode on native hiddens reproduces the parent saved deltas with zero reported relative difference. The final sum and denominator use the offline Q4 reference throughout. The eligible choices are the 169 train-seen experts; 35 held experts have no train observation. Every allocated expert pays its image bytes whether or not a route touches it. Q3 saves 278,528 bytes per expert relative to Q4 gate/up, and down Q4 saves 131,072 relative to Q5. The forty-layer percentages assume the layer-0 allocation transfers independently to every layer and eight selected images read once; they are **not** measured DRAM traffic or net mixed-dispatch cost.

[The selection receipt](/path/to/workspace/data/qwen-moe/cross-bank-rate/receipt.json) records every frozen ID, source/input hashes, both response-proxy panels and baseline norms. [The final response receipt](/path/to/workspace/data/qwen-moe/cross-bank-rate/exact-receipt.json) SHA-256 `85c6bb09d2351dd1ad18dd16c787e2ac8c72b3e29870a558b43127aef629dd1e` hashes the four regenerated response shards and sources, and retains every exact split result and error cosine. The four shard JSONs check recode replay against their original parent deltas; their `.npz` arrays retain the per-expert offline products. Inputs are pinned installed GGUF, actual layer-0 producer/router captures and frozen prior Q3 image/delta shards. This is a local decoded CPU map, not native FP32 bit identity, complete-model held language loss, original BF16 fidelity or deployed mixed-format time. No GPU, service or runtime changed.

Reproduce in a Kelana writer checkout with `OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4`:

```sh
python3 research/moe/cross-bank-rate/experiment.py
for first in 0 64 128 192; do python3 research/moe/cross-bank-rate/verify.py --first "$first" --last "$((first+64))"; done
python3 research/moe/cross-bank-rate/summarize.py
```

**Next:** gather broad quantized-producer routes across the full forty layers and freeze a paid image on new training text before held language-loss comparison. Only if a complete image beats its matched quality/rate controls should a mixed-format native reader be timed. Independently, the installed ordinary Q8 and expert device phases remain larger engine targets.
