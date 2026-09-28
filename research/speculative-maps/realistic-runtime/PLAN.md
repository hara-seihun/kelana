# Frozen scale-up plan

User request, September 23, 2026: prove the speculative and forced-span ideas in a larger, more realistic context. Freeze the methods before reading target outputs. Negative results and path mismatches remain in the report.

## Primary panel

Use the installed Qwen3-1.7B target with FP32 arithmetic, promoted from its pinned BF16 weights. A newly frozen public workload has 24 cases across code completion, ordinary text continuation and structured-record prompts, with context lengths 256, 1,024 and 2,048 tokens. Run all cases for 64 output tokens with serial decoding and the existing training-corpus/prompt-copy eighteen-node proposal tree. The tokenizer matches Qwen3-0.6B, but its hidden representation does not; do not silently reuse the small target's neural drafter.

Report decode latency and total request latency including prompt prefill, proposal/index preparation separately, emitted token equality and final next-decision equality, per-family and per-context-length results. Use the same indexed train corpus and frozen copy ranking as the previous round. The tree verifier and KV adoption are the existing maintained code. A one-node copy tree dispatches ordinary serial execution.

## Smaller-target controls

On the new manifest's even-indexed cases, run Qwen3-0.6B FP32 serial, the frozen rollout-trained neural eighteen-node tree, and its single-copy-edge graft. These twelve cases are selected by index before any target outputs, not by observed improvement. This tests the method that previously improved on eight short WikiText prompts at longer, mixed-domain prefixes. It is not a new fit.

## Structured output

Use the larger target with a lazy grammar for two to four tool records containing variable-length strings, numbers and enums. The grammar intersects the complete ordinary tokenizer vocabulary with admitted byte continuations; it is not a finite list of complete JSON strings. Compare one-token generation and contraction of genuine singleton runs under that same constraint. Both omit output-head selection at singleton states and update every consumed token into target KV. Record grammar preparation/cache costs and parse emitted JSON. Stop at accepting grammar state; preserve any numerical divergence instead of excluding the case.

A separate canonical-token protocol would change the target law and must be labeled separately if tested. The primary structured comparison must not attribute the prior finite canonical protocol's 9.61x gain to a general byte-constrained JSON decoder.

## Operations

No additional compute or model download is needed. Existing Bonsai admission serializes GPU panels. Divide the fixed case set into bounded foreground stages; checkpoint each completed case so a later timeout never discards completed evidence. Source and receipts are linked from the speculative-map index and its data owner. Publish one combined bundle after the two independent CPU workers finish.
