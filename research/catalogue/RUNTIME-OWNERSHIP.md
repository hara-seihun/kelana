# Runtime research custody

Kelana owns the cross-project scientific catalogue. Bonsai Halo owns executable inference, selected binaries, measurement scripts, raw receipts, service restoration and GPU admission. The Qwen on-demand runtime stays under Bonsai's `tools/qwen-moe/` and `/path/to/workspace/data/qwen-moe/`. SGLang's AWQ patch stays with SGLang; Bonsai's comparison report records the local experiment and upstream submission.

## One classification, one implementation owner

- [Bonsai PLAN](../../../bonsai-halo/PLAN.md) owns engine design and kernel reproduction. [Runtime classifications](runtime.md) own the research conclusions and comparator boundaries.
- [Native speculative comparison](../../../bonsai-halo/docs/speculative-compare.md) owns ordered reduction, DFlash2 versus copy/recycling, and the missing matched DSpark comparison.
- [SGLang AWQ](../../../bonsai-halo/docs/sglang-awq.md) owns the checkpoint fixture, upstream revision, paired kernel timings, numerical error and PR provenance. Its measured win is limited to the named upstream HIP path and tested shapes, not whole-model serving or every competing kernel.
- Bonsai's Qwen phase, MMQ, graph and MTP reports retain source/model hashes, scripts, rejected arms and acceptance receipts. Kelana classifies their findings without copying their tables into another operations guide.
- [Qwen operations](../../../bonsai-halo/docs/qwen-moe.md) and [speedup integration](../../../bonsai-halo/docs/qwen-moe-speedups.md) own the selected runtime and executable commands. [The continuing research lane](../../../bonsai-halo/orchestration/RESEARCH.md) links those owners rather than maintaining a second selected-revision field.
- [Rejected drafted serving](../../../bonsai-halo/docs/serve-drafted-batch.md) retains the incident and recovery instructions. Its negative result is indexed here; its source and evidence are not discarded.

Raw data remain under `/path/to/workspace/data/bonsai2/`, `/path/to/workspace/data/qwen-moe/` and `/path/to/workspace/data/sglang-bonsai/`, with reproduction instructions in their component reports. Catalogue entries link those reports. Match model quality, prompt length, context occupancy, speculative acceptance and timing boundaries before broadening any rank claim.
