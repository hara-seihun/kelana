# Reuse the target's first decision, then draft the residual

The original Qwen3-0.6B pilot loses test continuations before tree width becomes useful. This experiment asks what happens if the first token is the target's own decision, while the existing 200-step conditional drafter spends the same node budget on positions two through six. No checkpoint is retrained and no target weights change. [experiment.py](experiment.py) and the [per-context receipt](/path/to/workspace/data/kelana-speculative/candidate-repair/results.json) own the comparison.

The script scores the complete tied target head from each saved FP16 anchor feature, rounds its output to BF16 as in the original target call, then forces the argmax into a single root. It also evaluates a retained-token handoff arm: the saved target trajectory's first token represents a decision that a real target verifier could pass to the drafter after already computing it. That arm reads a held label as an explicit boundary input, not as a learned prediction or a free deduction from hidden. The remaining positions use the unchanged drafter, fixed position-wise top-16 pools and proposal-scored prefix heap. The baseline uses the pilot's original tree builder. All three trees have exactly 6, 18, 32 or 64 candidate nodes; only the first root differs. The target greedy trajectory scores acceptance; in the retained arm its first token is also supplied as the declared handoff input. A mismatched reconstructed first token fails at depth zero. Counts include the one target exit token, as in the original pilot.

| Held split | BF16-rounded head matches saved first token | Budget | Baseline mean | Forced-root mean | Retained-token mean |
| --- | ---: | ---: | ---: | ---: | ---: |
| Validation, 32 contexts | 32/32 | 6 | 2.2812 | 2.5000 | 2.5000 |
| Validation, 32 contexts | 32/32 | 64 | 2.6562 | 2.8438 | 2.8438 |
| Test, 32 contexts | 32/32 | 6 | 1.9062 | 2.2500 | 2.2500 |
| Test, 32 contexts | 32/32 | 18 | 2.0625 | 2.5000 | 2.5000 |
| Test, 32 contexts | 32/32 | 32 | 2.1250 | 2.5000 | 2.5000 |
| Test, 32 contexts | 32/32 | 64 | 2.1875 | 2.5625 | 2.5625 |

The chain changes from 1.8438 to 2.1875 on test. Saved BF16 hidden values round-trip exactly through FP16; the mismatch in the initial FP32-head analysis was not caused by feature conversion. On test context 16, FP32 output ranks token 1154 above target token 11 by 0.02876, but BF16 output rounds both logits to 14.25 and argmax chooses token 11. BF16-rounded projection and direct retained-token handoff agree with all 64 saved first decisions and produce identical trees here. Across test contexts the forced tree improves at budget 18 without any losses. The baseline still includes some correct first branches, so the gain is from both repairing a missing root and avoiding waste on competing roots. No target tree verifier or adopted KV state is measured.

## The bill

The head has 151,936 by 1,024 BF16 values. Recomputing an exact first argmax from hidden costs about 311 million floating-point operations, counting a multiply-add as two, and streams 311 MB of BF16 weights per context if they are not cached. This CPU reference converts the head to FP32, scores 32 contexts together and rounds output to BF16; it reads a 622 MB FP32 matrix and its batch call took 0.28 seconds for test. The retained-token arm pays none of this *additional* projection only if that first decision already exists at the actual handoff. That is not a per-request inference latency estimate. The pilot's six 2,048-row shortlist projections contain about 12.6 million scored values per context, so a new full-head computation is a substantial extra producer cost. At a serving boundary where the target already computed and retained the next-token argmax or logits, grafting the token needs no *additional* target projection. The cached feature alone does not provide it for free. Check whether a real verifier retains this decision before claiming net benefit.

The conditional checkpoint also embeds its 2,048 frozen target rows; the drafter's trunk, gates, top-16 selection and Python heap remain paid. Tree building took roughly 0.5 seconds for both methods, four budgets and 32 test contexts in this CPU reference. These measurements do not predict tokens per second on a GPU. The comparison is at fixed verified candidate-node counts, not fixed total compute or bandwidth.

## Next experiments

1. Save the target's sampled next token at the actual verifier-to-draft handoff and give that exact token to the draft. Compare full producer plus verifier time against recomputing the target head. The 311 MB streamed-head cost makes this boundary decisive.
2. Preserve the target's actual output dtype and tie behavior when reconstructing the handoff token. Context 16's 0.02876 FP32 margin disappears after BF16 output rounding, and the token switches. Check GPU serving numerics rather than silently using FP32 argmax.
3. Train a residual-only proposer on target-generated continuations, with losses at positions two through six conditioned on the known first token. Corpus teacher forcing currently optimizes a different distribution than these held greedy paths.
4. Condition candidate-pool selection on the known root. The current top-16 pools are frozen before the first branch, so grafting the correct token changes heap priorities but cannot retrieve absent second-position candidates.
5. Compare a context-adaptive shortlist drawn from recent target logits or cached target evidence with the static 2,048 train-frequency vocabulary. Record lookup construction and target evidence costs. Do not mine validation or test labels to build it.
6. Allocate nodes by predicted residual uncertainty rather than a constant 64 per context. The per-context receipt exposes which prefixes remain hard after the first token is fixed; fit a policy on separate training contexts, then measure acceptance against average verified nodes and wall-clock cost.
7. If first logits are unavailable, compare the extra full-head bill with spending equivalent bytes and FLOPs on stronger residual pool retrieval. A target shortlist alone cannot certify a full-vocabulary argmax.

Run with the pinned existing runtime. It uses CPU and takes a few seconds:

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/candidate-repair/experiment.py
```

It reads the unchanged `conditional-s200.pt`, `validation-greedy.pt`, `test-greedy.pt` and pinned target embedding, and writes only `/path/to/workspace/data/kelana-speculative/candidate-repair/`. The JSON records hashes of source, checkpoint and held fixtures, separate reconstructed and retained-token arms, the FP32 mismatch index, individual counts and timed reference steps. The data directory also holds a content-addressed source snapshot.
