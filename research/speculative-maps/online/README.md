# Continued decoding with measured verification and KV adoption

The [coupled follow-up](COUPLED.md) extends this loop with measured allocation, optimized copy proposals, on-generation training and forced-span batching under canonical-token and full byte-language contracts. It retains the initial measurements below and records the broader eight-prompt result separately.

This round runs an actual generation loop on the pinned Qwen3-0.6B target. It measures CPU drafting, host/device transfers, ancestor-mask construction, target body and full output head, branch selection and per-layer KV adoption. The target continues from the adopted state until it has emitted 32 tokens. This replaces isolated prefix-membership scoring with continued generation, but remains a Python/PyTorch research implementation rather than a serving engine.

## What runs

[experiment.py](experiment.py) loads the pinned BF16 checkpoint through the existing pilot. `--dtype float32` promotes those already-rounded weights to FP32; it does not recover unavailable pre-BF16 weights. The FP32 arithmetic target is a distinct numerical target from ordinary BF16 decoding. Draft training remains the existing BF16 target-generated fixture.

After prompt prefill, the target's hidden state and already-computed next token form the handoff. Each draft tree starts with that known token. The CPU producer proposes up to five further positions. A best-first heap selects an ancestor-closed tree using proposal path probability. Tree tokens get logical depth-based position IDs. Their additive attention mask admits the existing committed prefix and each node's ancestors, never siblings. One target call evaluates the tree and its full output logits. Greedy target decisions select a path from the known root. The implementation gathers each layer's KV entries for exactly that path and continues with the selected final hidden state and its next decision.

Every emitted token is consumed by the target. There is no free terminal bonus added to throughput. An end-of-panel partial path commits only the remaining requested tokens; unused verifier work is still timed. Runs use a fixed token count rather than EOS stopping. Initial prompt prefill and the first next-token decision are excluded equally from all arms. CPU drafting uses the existing 4,096-row residual producer or the new [direct producer](../direct-producer/README.md). Draft width remains 16.

Serial decoding uses the same target loader, full head and dynamic cache but its ordinary unmasked one-token SDPA path. It does not pay for a tree mask or KV gather. Timers synchronize the GPU at phase boundaries. They include synchronization overhead and prevent overlap. This is a matched baseline for this implementation, not a comparison against an optimized serving engine.

## Measured continued-generation result

Four fresh 64-token test-corpus prefixes exclude the original pilot's test starts. Each emits 32 tokens, repeated twice with method order rotated between repetitions. The repetitions are not eight independent prompts. [results.json](results.json) aggregates total emitted tokens divided by total elapsed time, not a mean of per-prompt throughput ratios. Large per-cycle receipts and exact source snapshots live in [the data owner](/path/to/workspace/data/kelana-speculative/online/README.md).

FP32 target, residual producer:

| Method | Tokens/s | Speedup over paired serial | Tokens per cycle | Draft ms/cycle | Verifier ms/cycle | Adopt ms/cycle |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Serial | 30.25 | 1.00 | 1.000 | 0.004 | 33.03 | 0.018 |
| Six-token chain | 35.31 | 1.17 | 1.267 | 1.72 | 33.62 | 0.54 |
| Six-node tree | 40.12 | 1.33 | 1.438 | 1.75 | 33.57 | 0.50 |
| 18-node tree | 42.09 | 1.39 | 1.620 | 2.28 | 35.67 | 0.53 |

All generated token IDs and final next-token decisions match serial on all four prompts in both repetitions. Every cycle asserts the committed cache length. Continued matching across many cycles exercises state adoption rather than merely comparing an initial block. Floating-point matching on these prompts is not a proof of equality for every possible context.

The separate larger-tree panel exposes the compute knee:

| Method | Tokens/s | Tokens per cycle | Complete cycle ms | Verifier ms |
| --- | ---: | ---: | ---: | ---: |
| Serial | 29.92 | 1.000 | 33.41 | 33.38 |
| 18-node tree | 41.33 | 1.620 | 39.19 | 36.23 |
| 64-node tree | 29.70 | 1.778 | 59.84 | 55.41 |

The larger tree gains about 9.7% progress per cycle over 18 nodes but costs about 52.7% more cycle time. It loses the speedup. All paths and final decisions again match serial. More compute helps only while its marginal cost is small enough relative to the progress it buys.

The direct producer removes the borrowed 1,024-wide target-head projection. On the same four prompts and two repetitions its 18-node draft phase falls to 1.21 ms, versus the residual panel's 2.28 ms, but progress falls from 1.620 to 1.542 tokens per cycle. Complete throughput is 41.33 tokens/s against its paired serial 30.24, a 1.37x gain. Its six-node tree reaches 38.72 tokens/s. Thus cheaper production preserves most of the benefit but does not beat the residual producer in these panels. The two producer panels ran separately; compare their paired serial ratios rather than treating small absolute timing differences as a controlled producer race.

The GPU wrapper serialized device work on the existing gfx1151 machine. It reported other host work during all panels, and 6% package-power limitation during the larger-tree panel. The retained `fp32-frontier.log` records that panel. No additional compute was provisioned. Python heap scheduling, CPU dispatch, mask creation and full-cache gathering are deliberately still in the bill.

## BF16 numerical boundary

The BF16 panel cannot support a lossless speed claim against ordinary serial decoding. One of two prompts diverges at emitted position 11 in the chain and both trees. A one-node tree also diverges there, so speculative branch selection is not necessary to trigger the difference. Computing the target output head row by row does not repair it.

[numerics.py](numerics.py) isolates the cause at identical teacher-forced histories with no drafter, no branch and no KV gather. It compares ordinary single-token decoding, explicit position IDs only, and explicit position IDs plus the additive attention mask. After consuming reference token 10:

| Path | Greedy next ID | Logit for ID 576 | Logit for ID 3555 |
| --- | ---: | ---: | ---: |
| Ordinary SDPA | 576 | 16.625 | 16.625 |
| Explicit positions only | 576 | 16.625 | 16.625 |
| Explicit additive mask | 3555 | 16.500 | 16.625 |

The explicit-position hidden state matches ordinary decoding exactly. The mask path's maximum absolute hidden-state difference is 0.5. Ordinary BF16 output has a tie and `argmax` chooses the lower ID. The additive-mask execution changes the body result before the output head. This establishes a mask-dependent numerical execution difference, not a change in the legal ancestor relation. The full diagnosis is `numerics.json` under the data owner.

Promoting the target to FP32 removes the observed mismatches in these panels, but changes arithmetic and doubles weight bytes. The 1.39x result is therefore relative to the FP32 target's own serial baseline. It is not a 1.39x improvement over the faster BF16 baseline, and it is not a lossless BF16 decoder. A deployable exact numerical contract needs a reference attention/verifier implementation whose accepted decisions are reproducible across the required shapes, or an explicitly different sampling contract. Near-tie heuristics alone would not prove exactness.

## Reproduce

From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=$PWD/research/speculative-maps/online/experiment.py
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" --contexts 4 --tokens 32 --dtype float32 --repeat 2 --tag fp32
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" --contexts 4 --tokens 32 --dtype float32 --repeat 2 --producer direct --tag fp32-direct
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" --contexts 4 --tokens 32 --dtype float32 --repeat 2 --methods serial,tree18,tree64 --tag fp32-frontier
```

The diagnosis consumes the original `mask-diagnosis.json` reference trajectories:

```sh
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" "$S" --contexts 2 --tokens 24 --methods serial,serial-mask,tree1,tree6 --tag mask-diagnosis
$B --runtime-max 50s --memory-gib 10 --host-reserve-gib 4 --exec "$P" research/speculative-maps/online/numerics.py
python3 research/speculative-maps/online/summarize.py
```

The summarizer also reads the retained `first` and `head-rows` panels; the main script's receipt records each panel's exact arguments. Source snapshots identify revisions before direct-producer support was added. Dataset starts are deterministic for the requested context count. These artifacts belong to the initiating speculative-decoding thread and are reachable through the [research index](../README.md).
