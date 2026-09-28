# A small Qwen target and a learned transition-map consumer

This first round establishes a fast real-model experiment for the project lead's speculative-decoding research. The target is the existing unmodified Qwen3-0.6B checkpoint, revision `c1899de289a04d12100db370d81485cdf75e47ca`, with 596,049,920 unique parameters. The draft has 593,920 active learned parameters without correction and 663,616 with correction. A six-token proposal can be expanded into a prefix tree and its local conditional distributions can be consumed as packed finite maps.

This is a proposal-quality experiment and an exact finite-map construction. It installs no serving code and measures no speculative inference speedup. [results.json](results.json) contains per-context outcomes, data and checkpoint hashes, capture starts, training curves and the transition-map receipt. Large artifacts belong to [/path/to/workspace/data/kelana-speculative](/path/to/workspace/data/kelana-speculative/README.md).

## What runs

[pilot.py](pilot.py) owns capture, fitting and tree evaluation. It uses the already installed PyTorch/Transformers environment and the existing GPU reservation wrapper. It does not download another model, provision compute or change the target weights.

The train split has 128 separate 128-token WikiText windows. Positions 16 through 121 yield 13,568 causal anchor features and their next six corpus tokens. A separate 32-window validation split yields 3,392 anchors. Features are the target's final normalized 1,024-vector, computed by the original BF16 model and saved in FP16. The source text hashes and nonoverlapping window starts are recorded. Future hidden states are never supplied to the draft.

Each draft maps the anchor feature through `1024 -> 256 -> 6*128`, predicts a 1,024-dimensional correction to the anchor at each position, and scores it against a frozen subset of the target's tied output rows. Its vocabulary is the 2,048 most frequent tokens in the train labels. The output rows are shared target information, not learned draft parameters: 2,097,152 values, stored as FP32 in this reference implementation. The serialized draft checkpoint therefore includes about 8 MiB of borrowed target rows in addition to learned parameters. A compact parameter count does not make this head free.

The conditional arm learns a shared 32-dimensional token code and a context gate. Its transition score is

```
base_i[b] + dot(code[a] * tanh(gate_i), code[b]) / sqrt(32)
```

The same code is consumed as the predecessor state and as the successor scorer. The independent arm has the same trunk initialization and training minibatches; its correction code and gate are unused. This is a small conventional learned-code baseline, not a claim to have invented a new drafter architecture or a jointly optimized ISA program.

Training uses teacher-forced **corpus** labels, not target-generated continuations or target distribution matching. Cross entropy excludes labels outside the train-selected vocabulary; those exclusions are reported, not credited as successful predictions. Held validation vocabulary coverage is only 69.53%. The two runs use 200 and 1,000 AdamW steps at batch 64, learning rate .002, with fixed seeds. Longer training overfits: validation in-shortlist NLL worsens from 5.795 to 6.391 for independent and 5.713 to 6.043 for conditional. Neither run changes the target model.

The recorded optimizer-loop durations are .65/.76 seconds for the 200-step arms and 2.01/2.42 seconds for the 1,000-step arms, excluding imports, loading and held evaluation. Target feature capture takes 4.36 seconds for train and 1.14 for validation after loading. These are research turnaround receipts, not controlled kernel benchmarks. The wrappers record other host activity.

## Real target continuation results

For each of 32 validation and 32 test prefixes, the original target generates a fixed six-token greedy trajectory from a 64-token corpus context. Training never sees the test text or those generated labels. There is no EOS stopping within this fixed-horizon diagnostic.

The draft produces a chain or a tree with 6, 18, 32 or 64 nodes. Each position first keeps its top 16 backbone candidates. Branch-conditioned scores use the actual predecessor token and normalize over the full 2,048-token draft vocabulary. A heap chooses the highest-probability available prefixes, retaining ancestors. This is the optimum within the available candidate tree under the **proposal's** path probabilities, not an oracle target tree. The chain greedily selects a candidate at each position; it is not an optimal chain search.

A tree accepts exactly the initial target trajectory contained in it. The reported count adds one target-produced exit/bonus token, so its maximum is seven. The target trajectories provide exact greedy prefix membership for this diagnostic, but no target tree-attention kernel or continuation KV-cache adoption is exercised.

### Test, 32 contexts, 200 training steps

| Draft | Six-position chain | Six-node tree | 18-node tree | 32-node tree | 64-node tree |
| --- | ---: | ---: | ---: | ---: | ---: |
| Independent | 1.6875 | 1.7500 | 2.0313 | 2.0625 | 2.0625 |
| Conditional | 1.8438 | 1.9063 | 2.0625 | 2.1250 | 2.1875 |

These are mean tokens including bonus, not tokens/second. The conditional 64-node tree gains 18.6% over its own chain, and 29.6% over the independent chain, while verifying up to 64 rather than six candidate positions. Validation counts for the 64-node tree are 2.6563 for both arms, compared with chains 2.0625/2.0313. The 1,000-step test trees reach only 1.9688/2.0313, so more optimization of this small training set is not the next useful action. Both checkpoints and all outcomes remain in custody; the smaller run is the better observed point, not a hidden test-selected replacement.

The first diagnostic identifies what limits growth. Even a free oracle choosing among every position's top-16 pool could reach only 2.2500/2.4063 test tokens for the independent/conditional 200-step arms. An oracle over the entire 2,048-token vocabulary reaches 4.1875. Increasing the tree budget cannot repair absent candidates. The dominant next question is target-aligned candidate generation, not a much larger heap.

## Consuming the learned head as a packed map

[transition_bridge.py](transition_bridge.py) turns the 200-step conditional head's actual test-context predictions into the [finite experiment's](../finite/README.md) maps.

It scores only adjacent top-16 candidate pairs using the learned codes, without constructing vocabulary-sized corrected logits. The resulting pair scores equal the corresponding entries of the full corrected score tensor on this panel, with maximum observed difference zero. Each row is then normalized over those 16 candidates and discretized onto 256 probability units by cumulative rounding. This explicitly defines a **different**, truncated finite-grid proposal; it is not described as the original full-vocabulary softmax.

One independent eight-bit uniform per position determines a function from predecessor candidate label to successor candidate label. All hypothetical predecessors at that position share the draw. First-position rows coincide because the anchor is already known. Each 16-state function occupies one 64-bit word, so six functions occupy 48 bytes per random stream. Candidate token IDs and the conditional table are separate: the reference uses 384 bytes of int32 token IDs and 3,072 bytes of uint16 cumulative tables per context. The physical NPZ uses its recorded array dtypes and headers; these payload counts are the stated minimal layouts, not file size claims.

Across 32 actual target contexts and 32 random streams each, serial sampling, serial packed prefix composition and balanced packed prefix composition agree on all 1,024 paths. This connects a learned neural producer to an exact packed consumer. Constructing the candidate pools, pair scores, cumulative tables and full maps still costs work. There is no native timing or end-to-end sampling-speed result for this learned bridge.

## Next experiment

Keep this small target. Use target-generated training continuations and a candidate objective that rewards surviving prefixes, with a wider or adaptive vocabulary that does not impose the current coverage ceiling. Compare against the present arms at fixed tree budgets and report the producer cost as well as coverage. Expand independent text before increasing training steps. For native map consumers, compare the complete table/map construction plus use; the finite CPU work shows that a larger byte encoding can be cheaper to compose than a compact nibble encoding.

A larger-model transfer becomes worthwhile after this pilot improves candidate coverage or lowers measured complete draft cost. An online verifier must separately establish target numerical behavior and continued state correctness. Greedy target matching here does not establish lossless stochastic target sampling.

## Reproduce

From the Kelana root, using only existing machine resources:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=$PWD/research/speculative-maps/qwen
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S/pilot.py" capture --split train --windows 128
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S/pilot.py" capture --split validation --windows 32
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S/pilot.py" capture --split validation --windows 32 --greedy
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S/pilot.py" capture --split test --windows 32 --greedy
for steps in 200 1000; do
  for arm in independent conditional; do
    $B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S/pilot.py" fit --arm "$arm" --steps "$steps" --gpu
  done
  "$P" "$S/pilot.py" evaluate --steps "$steps"
done
"$P" "$S/transition_bridge.py"
python3 "$S/summarize.py"
```

Captures and fits are reusable stage artifacts. Changing the producer or tokenizer requires new captures; changing only map representation does not require another target run. The source snapshots and hashed receipts in the data owner preserve this round independently of future edits.
