# Larger target and longer public contexts

the project lead requested a larger, more realistic test on September 23, 2026. [PLAN.md](PLAN.md) fixed the primary and smaller-target control panels before their target outputs were read. The [public workload](../realistic-workload/README.md) contains 24 prompts: eight actual TypeScript prefixes, eight WikiText article prefixes and eight JSON/JSON-RPC-style article-record prefixes. Each family has two 256-token, three 1,024-token and three 2,048-token contexts. All request 64 output tokens. These are raw continuation tasks, not a task-quality benchmark or a JSON-schema constraint.

## Primary result

The installed Qwen3-1.7B target has 1,720,574,976 unique parameters, almost three times the first pilot. Its source revision is `70d244cc86ccca08cf5af4e1e306ecf908b1ad5e`. The runner loads pinned BF16 weights and promotes them to FP32 arithmetic, matching the declared numerical target used in previous online rounds. It does not use the 0.6B target's neural drafter, whose hidden coordinates and shape are different.

The proposal is the existing exact-ranked prompt/training-corpus copy search. It supplies up to eight six-token candidate strings after the already-computed target token. The prefix-tree builder spends at most eighteen unique nodes. The target verifies an ancestor-masked tree and adopts only the accepted path's per-layer KV. A proposal with only the known root uses ordinary serial execution. Retrieval gets no later target label, and the index never includes held prose or code sources. Every emitted token is consumed by the target; no free terminal bonus enters throughput.

All 24 copy-tree outputs match all 1,536 serial target token IDs and all 24 final next-token decisions. Across the full fixed panel:

| Method | Decode tokens/s | Tokens/s including prefill | Target calls |
| --- | ---: | ---: | ---: |
| Serial | 11.06 | 8.33 | 1,536 |
| Copy tree, at most 18 nodes | 18.43 | 11.84 | 754 |

That is **1.666x decoding throughput and 1.422x throughput including prefill**. Aggregate rates divide total tokens by total time rather than averaging per-case ratios. The tree emits 2.037 tokens per verifier cycle and verifies 16.48 nodes on average. The complete draft bill is 0.246 seconds across the panel; verifier work is 79.674 seconds and path/cache adoption 3.393 seconds. Serial target work is 138.731 seconds. Initial prompt processing and the first target decision cost about 46 seconds per arm and are included in the second throughput column.

| Family | Cases | Decode speedup | Speedup including prefill |
| --- | ---: | ---: | ---: |
| Code | 8 | 1.619x | 1.377x |
| Prose | 8 | 1.724x | 1.465x |
| JSON-style continuation | 8 | 1.660x | 1.427x |

| Context length | Cases | Decode speedup | Speedup including prefill |
| --- | ---: | ---: | ---: |
| 256 | 6 | 2.087x | 1.996x |
| 1,024 | 9 | 1.633x | 1.422x |
| 2,048 | 9 | 1.528x | 1.280x |

All individual cases improve decode time; the smallest per-case ratio is 1.099x. A paired-case resampling sensitivity calculation gives 2.5/50/97.5 percentiles of 1.497/1.667/1.905 for the aggregate decode ratio. The cases are a fixed workload, not a random sample of all user traffic; this is not a universal performance guarantee or a timing-repeat confidence interval.

These measurements preserve model output, not its usefulness. The target produces repeated phrases or code patterns in some continuations, which makes copying easier. [inspect_outputs.py](inspect_outputs.py) retains every decoded serial continuation and repeated-fourgram statistics in the data owner. Twenty of 24 continuations contain at least one repeated fourgram, including ordinary code syntax and structured keys. None emits a special token within the 64-token window, so the observed gain does not come from continuing past an EOS token. No claim of better factual answers, valid completed programs or instruction-following follows from matching the target.

## Smaller-target controls

Twelve even-indexed manifest cases, four per family, also ran on the pinned Qwen3-0.6B FP32 target. The frozen rollout-trained producer and its one-copy-edge graft were carried over without further fitting. All 768 emitted tokens and all twelve final next-token decisions match serial in both arms.

| Method | Decode tokens/s | Decode speedup | Speedup including prefill |
| --- | ---: | ---: | ---: |
| Serial | 22.88 | 1.000x | 1.000x |
| Frozen learned tree, 18 nodes | 22.21 | 0.971x | 0.987x |
| Same tree with one retrieved edge | 28.78 | 1.258x | 1.200x |

The learned tree alone does not retain the short-prompt pilot's gain. Its code decode ratio is 0.768x, versus 1.132x on prose and 1.104x on JSON-style continuation. The graft gives 1.168x, 1.275x and 1.343x respectively. Cheap complementary candidates transfer better than this small learned producer. The larger target's pure copy tree and the smaller target's learned-plus-copy graft are different proposal methods, not a controlled comparison of model size alone.

## Variable-field JSON conversion

[structured.py](structured.py) runs two instruction-following conversions with two and four tool records. The [lazy grammar](../structured-runtime/README.md) admits all ordinary-token representations of its bounded ASCII JSON language. Fields include variable strings, signed integers and an escaped quotation mark. It does not enumerate a shortlist of complete answers. Each method gets a fresh grammar and fresh caches; lazy support construction remains in generation time.

Both arms produce valid JSON with every requested field value correct. The two-record output has 49 tokens; the four-record output has 98. Serial and contraction match both complete token paths and the final next decisions. There are **zero singleton token decisions on either path**. Both methods make 147 target body calls across the two tasks. The combined decode ratio is 0.996x, with opposite method order between tasks.

This is the important boundary of the earlier 9.61x canonical-protocol result. Known punctuation bytes need not force a token ID when several vocabulary segmentations remain legal. The realistic grammar provides no forced-run savings on these paths. A consumer that explicitly requires canonical tokenization can permit those savings, but that changes the constrained target law.

## Measurement boundaries

[benchmark.py](benchmark.py) uses the maintained [online verifier](../online/experiment.py), extended to return prefill/request timing and accept a target-independent proposal callback. Draft search, host/device transfers, mask construction, target body, full vocabulary head, branch selection and full committed-cache gathering all remain in decode wall time. Synchronization is explicit. The target and tokenizer-index loading happen outside request timing and their preparation is recorded separately. The reusable retrieval index occupies 20.75 MB. This is PyTorch research execution on the existing gfx1151 GPU, not a comparison against a tuned native server.

The six four-case GPU stages alternate method order. Logs retain clocks, host activity and power conditions. The first stage ran during unrelated compilation and had 82% package-power limitation; later stages reported 11–32%. We keep that stage rather than selecting away its evidence. Shared-machine interference and first-call kernel effects belong to the interpretation. The model, methods and complete case list were fixed before those timings. A separate reverse-order repeat of the first four cases reduces package-power limitation to 9%. Its decode ratio is 1.678x versus the original stage's 1.672x, and its request ratio is 1.462x versus 1.464x. All four paths and final decisions match again. The report keeps the original 24-case aggregate; it does not substitute the faster repeat.

Exact mathematical tree attention does not guarantee bitwise equality across floating-point kernel shapes. This panel records actual matching FP32 paths and final next decisions. It does not resolve the previously demonstrated BF16 mask/reduction mismatch or prove all-context equality.

## Reproduction and custody

The source and frozen manifest are in Kelana Git. Per-cycle target token IDs, timings, model/manifest/source hashes and logs live in [/path/to/workspace/data/kelana-speculative/realistic-runtime](/path/to/workspace/data/kelana-speculative/realistic-runtime/README.md). A completed case is checkpointed before the next begins; successful stages replace that temporary progress receipt with the complete stage receipt. No new model, compute or service was provisioned.

From the Kelana root, one primary stage is:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
S=$PWD/research/speculative-maps/realistic-runtime/benchmark.py
M=$PWD/research/speculative-maps/realistic-workload/manifest.json
$B --runtime-max 110s --memory-gib 18 --host-reserve-gib 4 --exec "$P" "$S" --manifest "$M" --offset 0 --count 4 --tag q17-00
```

Repeat offsets 4, 8, 12, 16 and 20. Reverse method order at 4, 12 and 20. The sensitivity repeat uses offset 0, count 4, `--reverse --tag q17-00-repeat`. Each stage is bounded and runs in the foreground through the existing admission wrapper.

For the smaller controls, use `--model qwen3-0.6b --methods serial,tree18,graft18 --stride 2 --count 4`, offsets 0, 8 and 16, and tags `q06-00`, `q06-08`, `q06-16`. Reverse order only at offset 8. These stages use the same wrapper with `--memory-gib 12`. For structured conversion, replace the script with `structured.py --records 2 --tag schema-2`, then `--records 4 --reverse --tag schema-4`, using the 18 GiB wrapper admission.

Run `"$P" research/speculative-maps/realistic-runtime/summarize.py --controls` after the complete panel to regenerate [results.json](results.json), including controls, structured tasks and the separate sensitivity repeat. `inspect_outputs.py` regenerates readable primary outputs. The data owner retains measured source snapshots. The current benchmark additionally records a learned-checkpoint hash in future receipts; the measured control receipts predate that metadata-only addition.

## What this supports

The useful compute/bandwidth trade survives a larger target, longer contexts and a broader fixed workload. Cheap candidate generation lets one weight traversal evaluate many possible continuations, and fewer target cycles repay the extra work. The benefit decreases with longer contexts, where attention and cache costs grow. These are complete runtime savings, not accepted-token counts standing in for speed.

The next step is a production-precision verifier with a declared numerical contract, followed by longer task-quality workloads and a stronger on-generation producer. More branches alone will not fix the code weakness of the learned drafter. Forced-span execution should target explicit consumer protocols, rather than assume that ordinary JSON syntax eliminates neural decisions.
