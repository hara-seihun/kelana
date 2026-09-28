# Model research desk

This is the central decision map for our model research. Kelana owns the classifications and scientific summaries, including results implemented in Bonsai Halo. Detailed reports, runnable experiments and raw receipts remain with their named owners; this desk links them rather than making another copy.

## The three buckets

- [Promising but not yet](promising.md): a useful construction, local improvement, bound or working baseline whose intended stronger claim has not passed. This includes real local wins that have not beaten a credible state-of-the-art comparator.
- [Better than SOTA on something](better-than-sota.md): a measured best-known result for a named model, device and workload, or a measured win over a named external implementation. Hardware-specific records count: Bonsai 27B batched ternary inference on Radeon 8060S belongs here. Each entry says whether it is a model/device record or a direct external comparison, and states its numerical settings and timing boundary. A toy win or an arbitrary internal speedup alone does not establish a record.
- [Strictly bad under the tested conditions](strictly-bad.md): the tested candidate is dominated, fails quality, fails correctness, or cannot achieve its intended saving within the measured contract. Do not rerun it unchanged. The label applies to the recorded construction, not every possible use of its broad idea.

A mixed family can have entries in more than one bucket. An exact theorem, a cheap CPU toy, a native kernel and an accepted whole-model result are different evidence levels. We keep those distinctions visible. A negative result stays with its experiment and provenance, not in a holding directory.

## Browse by area

- [Model conversion and quantization representations](conversion.md)
- [Sub-bit models, attention and cache representations](subbit.md)
- [Mixture of experts and speculative decoding](moe-speculation.md)
- [Packed computation, proofs and native building blocks](foundations.md)
- [Bonsai and Qwen runtime research](runtime.md)
- [ISA-aware quantization and executable-map search](isa-quantization.md)

[The source inventory](inventory.md) accounts for every Markdown research document under Kelana's `research/` tree and links external runtime acceptance owners. [Machine-readable counts](status.json) show coverage. Supporting instructions and method notes inherit their closest research owner; that is discoverability, not a separate experimental claim.

## Hardware-specific records

[Bonsai's batched ternary generation](runtime.md#runtime-bonsai-batched-ternary-8060s)
reaches roughly 600 aggregate tokens/s at 64 streams on Radeon 8060S. This is
a best-achieved model/device result, with A4 activations and INT8 state explicitly
part of its contract. It belongs in the SOTA bucket alongside, but distinct from,
a direct external-baseline win such as the SGLang AWQ kernel comparison.

## Current model baselines

The [four-bit diagnosis](../quantization-discovery/q4-diagnostic/README.md) is the current complete Qwen3-0.6B scalar baseline. Its calibrated image reaches 44.51 test perplexity at 4.2513 BPW, versus BF16 38.06. The original simple four-bit control's 85.74 perplexity is not a four-bit limit.

The [selected ternary image](../ternary/README.md) remains `expanded-scale384`, 1.7271 BPW and 104.21 test perplexity. Local response repair and higher-rate substitutions did not earn a replacement. The [stock GGUF comparison](../quantization-discovery/q4-diagnostic/STOCK-GGUF.md) measures actual bytes, including separately stored embedding/output tensors, rather than treating a Q4 label as equal storage.

These model outcomes are research baselines, not service deployment instructions. [Bonsai Halo](../../../bonsai-halo/README.md) owns adopted kernels and serving; [Qwen MoE operations](../../../bonsai-halo/docs/qwen-moe.md) own that runtime and its acceptance receipts. Dataset guides remain under `/path/to/workspace/data/`, linked from each experiment. Large weights and immutable measurements are not duplicated into Git.

[Runtime custody](RUNTIME-OWNERSHIP.md) names which reports and procedures stay
with Bonsai and which decisions belong here.

## Keep the map current

The domain JSON files here are the source of truth for classification. Each entry must name its comparison, evidence, limitation, next decision and primary source links. The Markdown bucket pages, domain pages, source inventory and status file are generated. Edit the JSON, then run:

```bash
python3 research/catalogue/catalogue.py build
python3 research/catalogue/catalogue.py check
python3 research/catalogue/catalogue.py list --category promising --query 'router'
```

The check takes seconds. It rejects missing source links, malformed or duplicate entries, stale generated pages and unowned Kelana research documents. Coverage of Kelana's Markdown tree does not prove that every result in an external runtime has its own entry. Review Bonsai's whole-model generation, prompt and serving reports explicitly when updating the runtime domain. Add the experiment's directory to an entry's `source_roots`; use narrower entries when child experiments have different conclusions. Include a newly finished or failed result in the same publication bundle as its evidence. Do not change categories just because a new run has started.

A category changes when its evidence changes. Keep the previous measured result in its source report and explain the new result in the entry. Research questions belong in `next`, not in a claim that the work has already succeeded.
