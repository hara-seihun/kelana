# Train a direct producer on target rollout states

The original direct producer learned from 2,048 target-generated continuations at corpus-prefix boundaries. Continued generation presents hidden states after the target has already emitted tokens. The [capture script](../online/capture_rollouts.py) saved 5,632 such states and their next six greedy tokens from 512 new train-corpus starts, excluding both prior training start sets. It advanced 16 FP32 target steps and retained 11 causal positions per trajectory. Neighboring rows share a trajectory, so the count is not 5,632 independent starts. The capture receipt names its source, corpus, numerical settings and artifact hash.

This experiment starts from the unchanged `direct-s200` model and 4,096-ID vocabulary. Each 64-row batch samples 32 rollout states and 32 original target-generated states with replacement. The mix retains corpus-prefix examples while exposing the model to on-generation states. It uses equal-weight, in-vocabulary cross entropy, the same direct model and static 16-ID pools, with checkpoints after 20, 40, 80 and 160 updates. Out-of-vocabulary targets are ignored for CE but still count as misses in tree coverage. The original checkpoint competes in validation selection. No held test labels select an objective or checkpoint.

Means include the retained first token and one target-produced exit token. Subtract two for newly accepted residual tokens.

| Checkpoint / split | 6 nodes | 18 nodes |
| --- | ---: | ---: |
| Original / validation | 2.4688 | 2.6563 |
| Mixed 160 steps / validation | 2.5000 | 2.7500 |
| Original / test | 2.4688 | 2.5313 |
| Mixed 160 steps / test | 2.4688 | 2.5000 |

Validation selects 160 updates by the sum of 6- and 18-node prefix means, breaking ties by 6-node mean and fewer updates. The held 18-node test mean falls by 0.0313 and the 6-node test mean ties. Thus the rollout distribution change did not establish an improvement on this held initial-prefix fixture.

The parent then ran the selected checkpoint in [continued FP32 generation](../online/COUPLED.md) on eight different prompts. The eighteen-node tree reached 39.51 tokens/s versus its paired serial 30.25, and adding one retrieved edge reached 40.66. All emitted tokens and final next decisions matched serial. The original direct producer reached 36.75 alone and 38.35 with retrieval across two separate panels on those same eight prompts. The initial-prefix diagnostic and continued-generation result differ; both remain part of the result.

The selected checkpoint is `/path/to/workspace/data/kelana-speculative/rollout-producer/direct-mixed-s160.pt`. It loads directly into `direct_producer.Direct` and keeps `backbone(hidden)`, `logits(base, gate, previous)` and `vocabulary`. Inference storage, 572,896 learned FP32 parameters, five 64-by-4,096 projections, and predecessor corrections match the original; training adds no online operation. `results.json` stores all per-context 6/18-node coverage, train/validation/test hashes and the source hash. The [data directory README](/path/to/workspace/data/kelana-speculative/rollout-producer/README.md) owns the capture and experiment artifacts. This CPU script does not run verification or KV adoption; the linked online experiment does.
