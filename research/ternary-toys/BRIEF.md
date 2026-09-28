# Twelve small experiments on low-bit computation

the project lead commissioned this round on September 23, 2026. She suspects there are
more efficient routes than straightforward training and wants a dozen GPT-6
Sol researchers to explore tiny examples that preserve enough of the larger
problem to reveal useful solutions. Please bring your own mathematical
judgment. The assigned intuition is a starting point, not a prescribed method.

## Starting evidence

Read the relevant parts of Kelana's README and `research/ternary/README.md`
and `expanded-training.md` before choosing a toy. Earlier work lives under
`research/quantization-discovery/subbit/`, `research/discovery/`,
`research/argmax-observer/` and `research/moe/`. We want a new discriminating
experiment rather than a renamed existing construction.

Our complete Qwen3-0.6B ternary image is 128,678,649 payload bytes, 1.7271 BPW,
with all 196 body matrices and the shared embedding/head. On the fixed test,
BF16 NLL is 3.6392, a basic scalar four-bit control 4.4513, and our strongest
scale-recovered ternary image 4.6464. The image is
`/path/to/workspace/data/kelana-subbit/ternary/expanded-scale384/`. Raw source and
calibration captures are already documented in that data directory's owner.
Local response improvements repeatedly worsened composed language loss.
Whole-model scale training helped; broad STE code changes lost to a matched
scale-only control. A 256-trit update accepted on a training check panel made
almost no held difference. Straightforward training is not the only route to
investigate.

Bonsai 2 uses ternary weights in signed block-Hadamard coordinates, group-128
FP16 scales and selected high-precision tensors. Its full conversion recipe is
not public. An independent paired WikiText-2/context-2048 evaluation reports
Bonsai PPL 8.6690 versus its original Qwen3.8 BF16 6.5137, a 1.3309 ratio or
.28585 extra nats. That suggests a comparative research landmark, not a
same-model benchmark claim. Applying that loss difference to our toy reference
would give about 3.925 NLL. Its 98.2% benchmark-score retention is not a
perplexity ratio. Source: https://huggingface.co/ProCreations/bonsai-2-27b-gsq-rco-gguf

## What would make a useful result

Please carry one question through an executable tiny experiment, a mathematical
construction or a revealing counterexample. Keep the relationship to the real
problem explicit. A toy can be much smaller than a language model while
retaining anisotropic inputs, residual composition, gates, attention
normalization, recurrent state, tied consumers or conditional routes. You
choose which properties matter for your question and what would falsify the
proposed transfer.

Exact enumeration and small oracles can expose why a practical method loses.
If you find an oracle, distinguish its attainable quality from its online cost
and conversion cost. Include all scales, tables, transformations, side bits and
higher-precision exceptions when a storage comparison matters. A useful
negative names its finite family, not an impossibility for all representations.
Small learned examples are welcome when they illuminate a mechanism, but the
goal is not another expensive model-training sweep.

The desired handoff is a short report, runnable source and compact result data:
what you discovered, the strongest control, which large-model characteristic
the toy preserves, and the next discriminating transfer test. If the intuition
dies, explain what killed it and preserve that result. If a more interesting
question appears, pursue it within your area rather than force the first idea.

## Shared machine and publication

Twelve peers are working together on existing hardware. Favor bounded CPU
experiments with one or two BLAS/PyTorch threads so everyone can make progress.
The GPU has existing model owners; contact the parent before scheduling a
necessary GPU experiment. No new compute is being provisioned.

Take a managed Kelana writer checkout with `agent-workspace`, and keep your
work in the assigned `research/ternary-toys/AREA/` directory. This keeps your
publication independent of the other eleven researchers. You own its README,
source, compact results and any local provenance. Large generated data, if
needed, belongs under `/path/to/workspace/data/kelana-subbit/ternary-toys/AREA/`, linked
from your report. The parent owns the round index and canonical integration,
so send your commit and checkout path rather than edit the shared indexes or
merge separately. Please retain the checkout until the parent confirms custody.
