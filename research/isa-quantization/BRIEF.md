# ISA-aware quantization as executable-map discovery

the project lead's September 24 direction is to choose quantization decomposition, stored representation and ISA computation together. A scale multiplying independent ternary blocks is an interpretable control, not the answer space. Quantization may deliberately move the target toward a nearby map with a cheaper hardware realization. Neither individual weights nor recognizable intermediate tensors need to exist in that realization.

The programme began in theory and now has combined-search, native-reader and real-producer evidence. Read the current synthesis and [orchestration decisions](ORCHESTRATION.md) before choosing a new construction. The goal remains structural discoveries, useful obstructions and a better complete frontier. A tiny exact example with a useful generalization is more valuable than a large fit with no explanation. You are an independent Sol 6 researcher; your assigned intuition is a starting point, not an algorithm prescription. Follow the mathematics where it leads.

## The object

For a target region F and dynamic input/state x, consider a stored description z and a program O(P(z,E(x))). E and O may be adjacent encoded consumers, not conventional unpacking. Seek useful tradeoffs among behavioral distortion, complete static bytes, dynamic state and native execution cost. Preparation, model-specific instruction constants, tables, exceptional paths, layout and all live consumers are part of that object. An effective BPW divides total paid model bytes by original unique parameter count for comparison; it does not require a code per original parameter.

A semantic construction need not already have a fast lowering to be worth retaining. Record the structural result separately from the realized one. Conversely, an arbitrary free decoder or a huge model-specific lookup table cannot establish an execution or compression gain.

## Comparable-size state-of-the-art is the target

the project lead clarified on September 24, 2026: **“trying to beat Q4's loss with a lower quantization is not the point … you do expect something like a Q2 or whatever to have higher loss than Q4 … the thing we're trying to beat is whatever the state-of-the-art quantization method is at comparable sizes.”**

Compare complete behavioral error against a named strong quantization method at comparable **total effective size**, with matched model, producer/evaluation distribution and observation boundary. Nominal Q2/Q3/Q4 labels do not fix size: include scale/zero fields, dictionaries, indices, code, exceptions, stored preparation and every affected tensor. Keep prepared RAM and execution work as additional frontier axes. Use a nearby rate-distortion frontier rather than demand equal accuracy from fewer bytes, or pad a weaker baseline to manufacture equal size.

A cheaper candidate with worse loss than Q4 is not thereby dominated or rejected. A certificate above Q4's loss proves only that its specified family cannot meet that particular accuracy target. To exclude the family from a size-matched frontier, compare its certified floor with an actually achieved strong control at no greater effective size, and account for execution differences. A standard internal scalar control is useful but is not automatically state of the art; identify the algorithm, implementation and endpoint before making that claim. Local response comparisons do not establish full-model rate-distortion superiority.

## Read the closest existing work

Start with `/path/to/workspace/projects/kelana/DESIGN.md` and the relevant parts of:

- `research/discovery/observer-search/PLAN.md`: whole maps, sufficient observations, simultaneous labels, and why equal fibers do not imply equal native cost.
- `research/toy2/radix64/README.md`: one-dot ternary 2x2 map with a changed endpoint, including its unpaid wire and continuation.
- `research/quantization-discovery/representations/{MAP,SYNTHESIS}.md`: decomposition experiments, strong controls, full-model reversals and the magnitude-placement question.
- `research/discovery/joint-observer/README.md`: search for entire source/consumer function families; trained collisions reject one cheap carrier.
- `research/quantization-discovery/MATHEMATICS.md`: exact response-state search, paid dominance and lower bounds, currently mostly fixed candidate menus.
- `research/discovery/resource-bounds/README.md`: semantic potentials and conditional resource lower bounds without insisting on source intermediates.
- `research/catalogue/README.md`: the current classification map and primary evidence.

Choose further sources by need. Please distinguish a genuinely new construction or extension from an existing result with different notation. A useful reinterpretation should enable a new decision or executable experiment.

## A useful first result

Choose the smallest domain that retains the obstacle you are studying. Possibilities include finite real/rational-weight maps with quantized inputs, a short nonlinear residual region, recurrent state, routed sums or a few register/lane states. You may use real weight or activation snippets already held on this host; no download or GPU work is needed for this round.

Try to establish a concrete proposition, counterexample, reusable search reduction or small Pareto frontier. When proposing an improvement, give the strongest inexpensive conventional control you can fairly fit, not just nearest rounding. Where relevant include an unstructured or perturbed teacher so a planted construction does not answer a prevalence question. Search effort and fit-query cost are worth recording too.

You can return a bounded negative. Say what it excludes and which assumption would need to change. Do not enlarge a failing experiment merely to obtain a win. Exact integer/rational semantics, ideal floating semantics, emitted ISA semantics and elapsed native time are separate evidence levels. A finite-domain theorem need not pretend to certify unseen language-model behavior.

## Custody and coordination

Your task message names a unique write directory under `research/isa-quantization/`. Take your own managed writer from `/path/to/workspace/projects/kelana` using agent-workspace. Please do not edit shared README files or the catalogue; the parent owns integration. The parent also owns `research/isa-quantization/BRIEF.md`, the current synthesis, orchestration record and the parent experiment named in your dispatch.

Leave runnable source and compact results next to a concise README in your directory. If the result is purely mathematical, include a reproducible witness or certificate where useful. Commit in your writer and send the full SHA, writer path, central finding and limits. Retain the writer until the parent confirms canonical custody. Do not publish a separate canonical merge for each experiment; the parent will combine the round.

Use existing CPU resources and one BLAS thread per experiment by default. Keep individual searches under a minute through better formulations and preserve successful artifacts. A specifically dispatched native study may use the coordinated GPU lane through the machine handbook; other researchers remain CPU-only. No new compute or large training runs. Reading and deriving are valid work; a principled impossibility or an unfinished proof reported plainly is preferable to a manufactured optimum.
