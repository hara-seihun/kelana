# Paid Q3_K/Q4_K bank selection on Qwen's routed output

The direct layer-0 Q3_K gate/up image loses **.084997 held relative RMS** on the complete weighted eight-expert sum. Keeping selected experts in Q4_K can trade bytes for that local error, but **even the best one-of-eight 32-expert Q3_K bank chosen with hindsight loses .023045 held RMS**. Four train-selected Q3_K banks save a conditional **1.696927%** of the forty-layer complete one-read stream and lose **.055581 held RMS**, versus the impossible held-choice oracle's .050570. This is a bounded negative for *fixed 32-expert bank allocation of these already recoded images*, not for finer per-expert allocation, trained codes, or language quality.

| Q3_K shards (32 experts each) | Train-selected shard IDs | Train / held routed-sum RMS | Held-choice oracle RMS | Conditional one-read saving |
| ---: | --- | ---: | ---: | ---: |
| 0 | none | 0 / 0 | 0 | 0% |
| 1 | 0 | .024975 / .024878 | .023045 | .424232% |
| 2 | 0,6 | .036443 / .033926 | .033926 | .848463% |
| 3 | 0,5,6 | .048468 / .046532 | .042499 | 1.272695% |
| 4 | 0,1,5,6 | .058159 / .055581 | .050570 | 1.696927% |
| 5 | 0,1,5,6,7 | .066478 / .062043 | .058864 | 2.121158% |
| 6 | 0,1,2,5,6,7 | .074062 / .071587 | .067094 | 2.545390% |
| 7 | 0,1,2,3,5,6,7 | .081147 / .075958 | .075958 | 2.969621% |
| 8 | all | .089569 / .084997 | .084997 | 3.393853% |

## Whole-map calculation and bound

For shard `i`, the [original recode](../gateup-q3-recode/README.md) saved its complete score-weighted output on each of 113 train and 126 held actual producer tokens, both at decoded installed Q4_K and at native-format Q3_K gate/up. Original Q5_K down, eight IDs, router scores and nonlinear SwiGLU are held fixed. Its delta `d_i(t)` includes **all** routed experts within that 32-expert bank, including their actual interactions with the shared input and score. Selecting static shard set `S` changes the complete routed sum by `sum_{i in S} d_i(t)`. Thus its exact FP64 offline squared-error objective is `1_S^T G 1_S`, where `G_ij=sum_t <d_i(t),d_j(t)>`. The script enumerates every subset of all eight shards (256 masks), minimizes the train objective at each count with lexicographic ties, and only then scores held. A second exhaustive held minimization is an unavailable hindsight lower bound on held error **within this fixed-image/shard grammar**. It does not optimize model loss.

A Q3_K gate/up pair costs 901,120 bytes per expert; Q4_K costs 1,179,648. Each selected shard pays the former image for 32 experts in place of the latter, whether a captured route uses that shard or not. The full 256-expert gate/up bank costs 230,686,720 bytes in Q3_K against 301,989,888 in Q4_K; a four-shard mixed layer pays 266,338,304 bytes, plus unchanged down and nonexpert images. The final column grants eight independent expert-image reads per layer across forty layers and charges the saving against 2,626,187,904 one-read whole-model bytes per token. It is conditional logical traffic, **not** an observed DRAM-byte saving, kernel speed or complete-model speedup. A native mixed-format reader would require format dispatch and may pay extra launches; neither that cost nor full-model held next-token loss was measured. The CPU reduction is FP64 over FP32 BLAS/SwiGLU products, not bit-identical native FP32.

The one-bank held oracle already exceeds a 1% local error target by more than 2x; the three-bank held oracle is .042499 while the four-bank oracle exceeds 5%. This ceiling is genuinely about coarsely allocated *straight recodes*: it does not imply a lower bound for trained Q3_K or per-expert allocation, and local RMS cannot be converted into language loss. The train and held shard sets differ at one, three, four, five and six shards, so broad producer calibration and a frozen complete-model quality panel are necessary before any paid image is selected. The independent gate-versus-up asymmetric study tests a different bank axis. Neither result supports a native port on local quality alone.

## Evidence and replay

[The receipt](/path/to/workspace/data/qwen-moe/q3-group-allocation/receipt.json), SHA-256 `d9fa0f4eff28c1bf88ba9fb763f92d7a4c5cfbb0be48f5072d4f6ce4c0bf6cb7`, records the parent receipt, model, source and eight actual Q3_K image/output shard hashes, paid bytes, all selections, train/held denominators and per-shard errors. Recompute on CPU without a GPU reservation:

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=4 python3 research/moe/q3-group-allocation/experiment.py
```

No selected image, Qwen executable or Bonsai service changed. The next quality experiment should fit Q3_K codes on broader actual quantized-producer routes and assess a **complete forty-layer mixed image** on disjoint next-token text. A finer selector over the same 113 train tokens would mostly tune the observed local objective, not establish serving quality. Independently, the expensive nonexpert Q8 phase calls for ordinary native timing and physical-transaction diagnosis, not another synthetic code-reuse proposal.
