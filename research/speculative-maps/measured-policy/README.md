# Measured-cost tree allocation after a retained target token

The target has already computed the first token. The CPU producer sees its hidden state and that token; the tree spends 6, 18 or 64 candidate slots including this known root. A serial action skips the tree. `policy.py` offers best-first proposal mass, a deeper-priority tree and a wider-priority tree at the same node budget. Every tree is ancestor-closed. The producer scores the full 4,096-token row and considers the static top 16 candidates at each position, just as the online experiment does. Its first corrected row's top-16 probability mass, top-one and top-two masses, and entropy are the only routing inputs. These are proposal probabilities, not target confidence or held labels.

`experiment.py` pairs the actions on the existing 32 validation and 32 test greedy captures. It fits a ridge estimate of progress minus the validation-best rate times cost, and selects only from root features. For the cost curve it reads the FP32 online cycle receipts: serial, 6, 18 and 64 nodes for residual, and serial, 6 and 18 for direct. It interpolates target verification and KV adoption by node count, and CPU production by distinct corrected rows. The direct 64-node verifier price comes from the residual panel running the same target; its CPU draft price extrapolates from measured direct rows. It charges a corrected first row even when selecting serial, plus a CPU-measured median for root softmax, ranking and entropy. Fixed actions do not pay for routing features, and fixed serial does not run the producer. Once an action is chosen, runtime constructs only that tree. Offline counterfactual trees do not become free runtime features. The study's prefix masses and depth counts are diagnostics; the selector never constructs alternative trees to see them.

| Producer | Validation-best fixed | Test fixed predicted tokens/s | Test routed predicted tokens/s | Test hindsight predicted tokens/s |
| --- | --- | ---: | ---: | ---: |
| Residual | 18-node breadth | 39.310 | 38.181 | 42.949 |
| Direct | 6-node depth | 42.667 | 43.242 | 44.802 |

For residual, routing loses 1.13 predicted tokens/s, or 2.9%, against fixed breadth. Validation breadth at 18 nodes helps three contexts and harms one against best-first mass, but the test panel has no changed 18-node outcomes from breadth at all. The fitted route chooses depth for 16 test contexts; it saves CPU rows yet loses accepted tokens. The direct route improves 0.57 predicted tokens/s, or 1.3%, choosing serial five times, six-node trees fifteen times and 18-node trees twelve times. That is a small diagnostic result on an inspected panel, not a backend speed claim. Hindsight knows the target outcomes and is not implementable. The 64-node target verifier costs about 55.4 ms, compared with about 36 ms for 18; extra reachable-prefix mass usually cannot pay for the larger verifier.

These are CPU-captured BF16 target trajectories priced with FP32 online receipts, not continued-generation FP32 results. Numerically different target paths and subsequent context distributions can change acceptance. The test32 traces were already inspected in prior studies. The fixed six-node depth tree also differs from the online panel's mass-first `tree6`, so its predicted rate is not observed online throughput. The mass-first producer matches `online.draft` node tokens, parent links and corrected-row counts at budgets 6, 18 and 64 on four saved contexts.

## Continued-generation result

The [coupled online follow-up](../online/COUPLED.md) tests the direct policy on eight FP32 prompts, 32 tokens each. Routing reaches 35.10 tokens/s versus fixed six-node depth 35.98, fixed eighteen-node mass 36.59 and serial 30.22. All paths and next decisions match serial. The offline positive prediction does not survive the paid continued-generation loop, so adaptive dispatch is not adopted as the preferred policy.

## Use with the online verifier

```python
from pathlib import Path
from policy import load_policy, online_draft

policy = load_policy(Path('research/speculative-maps/measured-policy/direct-results.json'))
action, tokens, parents, depths, corrected_rows = online_draft(
    producer, hidden, pending, lookup, policy)
if action.budget == 0:
    # Ordinary unmasked one-token SDPA, as in online/experiment.py's serial arm.
    ...
else:
    # Feed tokens, parents and depths to mask_and_positions and the target verifier.
    ...
```

The returned root token is the target's pending decision. `online_draft` computes the root correction once and reuses it in the chosen tree; its serial action still pays the producer and root features. The selected coefficients and cost details are in `direct-results.json` and `residual-results.json`. Load the matching producer's receipt. The online caller remains responsible for the usual ancestor mask, full output head and per-layer KV adoption.

To regenerate both receipts on the CPU:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$P research/speculative-maps/measured-policy/experiment.py residual
$P research/speculative-maps/measured-policy/experiment.py direct
```

The result files record each context's action progress, selected shape, prefix mass, distinct corrected rows and predicted cost, alongside checkpoint, capture, online-panel and source hashes. The CPU captures and online timing receipts remain under `/path/to/workspace/data/kelana-speculative`.
