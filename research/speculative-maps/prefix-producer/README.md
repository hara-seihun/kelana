# Prefix-focused direct producer

This CPU experiment fine-tunes the direct candidate-ID producer for early residual tokens. The original model gives each of the five residual positions equal cross-entropy weight. Here the `front` loss weights them 6, 3, 1, 0.5, 0.25 and the `gentle` loss weights them 3, 2, 1, 1, 1. Both start from the original validation-selected `direct-s200` checkpoint, train on its 2,048 target-generated rows, and keep its 4,096-ID vocabulary. Checkpoints are saved after 20, 40 and 80 updates. No target head is borrowed.

The tree experiment also tries a fixed reward per additional draft edge. A reward of zero recovers the original path-log-probability heap order; a positive reward spends more of the 6- or 18-node budget on deeper branches. Validation selects jointly among the original model and six fine-tuned checkpoints at rewards 0 through 5. The sum of validation means at 6 and 18 nodes selects `gentle-s80.pt` with reward 1.0. Ties prefer 6-node coverage, less reward, then fewer updates. Test is read only after selection.

Means include the known first target token and one target-produced exit token. Subtract two to get newly accepted residual tokens.

| Model / split | 6 nodes | 18 nodes |
| --- | ---: | ---: |
| Original direct / validation | 2.4688 | 2.6563 |
| Selected / validation | 2.6250 | 2.7188 |
| Residual static / validation | 2.7188 | 2.8438 |
| Original direct / test | 2.4688 | 2.5313 |
| Selected / test | 2.4688 | 2.5000 |
| Residual static / test | 2.4063 | 2.5313 |

The validation gain does not survive on test. The selected producer ties the original at 6 nodes and loses 0.0313 at 18 nodes. It does not establish an online improvement. The validation grid is large relative to 32 contexts, so selecting a policy on this split can overfit. The online verifier should retain the original producer unless a larger independent split or generation panel demonstrates a gain.

`Direct.backbone(hidden)` returns the five static ID logit rows and predecessor gates. `Direct.logits(base, gate, previous)` returns a conditioned 4,096-ID row. This checkpoint uses the same API and state dictionary as the original. `proposed(model, hidden, retained_first_id, depth_reward=1.0)` returns ordered draft prefixes for the selected policy; `depth_reward=0` uses the original ranking through 18 nodes. The budget includes the known first-token tree root. The output head remains 64 by 4,096, with 572,896 learned FP32 parameters, 32 KiB of vocabulary IDs and no frozen target head. The reward adds one scalar operation per generated heap edge, but the same five static 64-by-4,096 projections and 16-token pools dominate proposal work. These are operation counts, not latency measurements. No verifier or KV adoption was run here.

## Root-conditioned position states

The retained first token contains information that the original position trunk cannot use: `Direct.backbone(hidden)` does not receive the root, only the subsequent conditional row does. `RootConditioned` starts from that same direct checkpoint and adds a 16-to-320 projection of its existing predecessor code to the five 64-wide position states before the ID head and gate. The projection starts at zero, so the initial producer exactly matches the original. `backbone_with_root(hidden, root_id)` returns the position bases and gates; `logits(base, gate, previous)` and the vocabulary remain unchanged. At inference this adds 5,120 scalar products per context and no extra target-head rows. It adds 5,120 learned weights to the original 572,896, for 578,016 total. This is deliberately a cheap way to share the known root with every predicted position.

Fine-tuning uses equal-weight in-vocabulary CE on the same 2,048 training rows, with checkpoints after 20, 40, 80 and 120 updates. The original checkpoint is included in the validation selection. The original wins: validation means at 6/18 nodes are 2.4688/2.6563, versus 2.4688/2.6250 at the best root checkpoint, step 20. The unchanged original is therefore selected, and its test means remain 2.4688/2.5313. This arm did not establish useful root-conditioned suffix survival. No root-trained checkpoint should replace the direct producer on these fixtures. The root checkpoint results remain available for a future larger held split.

The script writes checkpoints, JSON receipts with per-context values and hashes, and source copies under `/path/to/workspace/data/kelana-speculative/prefix-producer/`. That directory owns the artifact custody and its README records the commands. Input fixtures and residual/reference checkpoints remain under their existing owners.
