# Investigating the decomposition, not just its parameters

the project lead's September 23 question is whether separating weights into a scale and
small scalar codes is a good decomposition at all, for either compression or
execution. Treat that factorization as one control, not the required output.
The goal is useful new constructions and experiments, with the existing work
brought together in Kelana. The parent owns this directory's index and synthesis.

You are an independent researcher. Your assigned direction is an intuition,
not an implementation prescription. Choose a tiny experiment that exposes a
real obstacle and a useful way around it. Real-weight snippets or captured
activations are welcome when a purely planted toy would hide the main issue.
Keep enough of the relevant consumer, input correlations, gates, routes or
boundary representation to make the result informative. An exact finite
negative is a valid result; explain what it excludes and what remains open.

## Starting points

- [Quantization discovery](../README.md) already owns assignment algorithms,
  consumer-aware state reduction, direct sign-orbit response tables, real
  weight codecs and their CPU/GPU divergence. Its [prior-art map](../PRIOR-ART.md)
  includes vector/additive/codebook methods. New packaging is not novelty.
- [Sub-bit research](../subbit/README.md) studies quantized factors, shared
  V/O coordinates, tied consumers and complete-model images. A factor's local
  response improvement can worsen whole-model NLL. Cardinality alone does not
  prove a relabeling or a realizable consumer.
- [Twelve tiny experiments](../../ternary-toys/README.md) include paired
  templates, nonlinear gauges, tied consumers, code interactions, paid rate
  allocation, reachable attention quotients and native packed recurrence.
- [Composed representations](../../composition/README.md),
  [whole-map discovery](../../discovery/README.md), and
  [whole FFN](../../ffn/full-map/README.md) investigate carrying labels through
  computations. Scalar weights and recognizable intermediate matrices need
  not be reconstructed unless a live consumer needs them.
- [Compact scaled FP16](../../ffn/batched/compact-scaled/README.md) already
  constructs scaled native operands through byte selection and removes scale
  epilogues. [MoE](../../moe/README.md) and its linked studies include negative
  real-weight shared-factor and repeated-code results.

Please read the relevant owners before choosing a result to claim. The main
repository README links newer findings too. If useful evidence is outside
Kelana, cite its current owner; the parent is centralizing the map, not copying
large artifacts or creating competing sources of truth.

## What counts as a result

Return source, a concise report and compact measured results in your assigned
subdirectory. State the encoded object and the entire online map. Charge
scales, codebooks, transforms, exceptions, indices, padding and decoding or
preparation. If two consumers share a representation, include both and the
handoff. Show a fair scalar-code/scale control and a stronger alternative when
one obviously applies. Use actual physical bytes for finite comparisons, not
only entropy estimates. Separate conversion effort, storage, access pattern
and measured execution time. There may be several nondominated choices rather
than one optimum. Preserve a structural construction even if the native
lowering is not yet cheap, but name that distinction.

Use held observations or a complete finite domain as appropriate. A planted
witness is useful when labeled as such; a small perturbation or unstructured
control can reveal its limits. Explain the cheapest real-model test that
could falsify transfer. Do not manufacture a whole-model quality or native
speed claim from a proxy. You are welcome to consult papers if helpful;
implementing and interrogating a small mechanism is more useful than another
broad literature list.

## Coordination

Create and heartbeat a managed writer checkout of /path/to/workspace/projects/kelana.
Your assigned subdirectory gives you independent source ownership; parent owns
shared indices and final publication. Commit and send the revision and checkout
path, retaining it until the parent confirms custody. Results will be merged
as one bundle. Use one or two CPU BLAS threads so the other experiments remain
usable. Scientific Python is /path/to/workspace/data/fish-s2-pro/venv/bin/python.
No new compute is needed. A separate researcher owns the paired-repair GPU
experiment; ask the parent before a native GPU panel. CPU native probes are
available on this host. Keep experiments bounded and preserve useful outputs.

If the chosen family loses, report the losing result and its limits. The task
is to learn whether the representation earns its costs, not to force a win.
