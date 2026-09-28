# Spend work on decisions, preserve continuations

The September 23 investigation asks whether one rule can explain speculative trees, unequal token difficulty, forced spans, cheap proposal maps and native representations. A useful rule must price the whole computation and preserve the future, not merely return the right next token.

The working answer is an exact-generation control problem over machine state. Its mathematical parts are familiar: sufficient statistics, Markov quotients, average-reward control and hardware cost models. The research question is whether jointly choosing the representation and the available actions gives a cheaper implementation than optimizing a fixed token-by-token graph.

## What must survive a change of representation?

Let `s` be the current generation state and `K(s, dy ds')` the target kernel for the next emitted symbol and successor state. State includes the model's continuation state, the grammar and tokenizer state, and the specified sampling contract. A candidate encoding `z = phi(s)` supports an exact reusable Markov generator if

```
Law(Y, phi(S') | S=s)
```

is the same for every pair of states with the same `phi(s)`. This is the joint next-output and next-encoded-state condition, not just equality of next-token probabilities. It permits repeated execution without recovering `s`. A cheap transition realizing that law is a separate requirement.

This condition is sufficient for a one-step Markov quotient. It is not a claim that every exact implementation must literally construct this quotient. An implementation can use richer state, different block boundaries, latent randomness or a different generation order. Compare the distribution of the complete required observations in those cases.

Three distinctions matter in the existing experiments:

- Equal sampling distributions do not imply identical outputs under the same random seed. A fixed-randomness replay contract is stronger. The finite-map tests specify the random coupling; the lazy rejection sampler specifies its own exact law and accepted-rank coupling.
- Equality for one finite observed suffix is weaker than equality for all future continuations. A final greedy head only owes an argmax. A reusable decoder also owes the state from which later decisions are made.
- A sufficient encoding can be expensive to construct or consume. Kelana's map search preserves a structural witness first, then prices its realization. Neither a small state count nor a bijective relabeling makes the machine instructions free.

This explains why two draft histories may share a cheap conditional row while their target KV states remain distinct. Our first-order draft head depends on position and predecessor candidate ID. A transformer's target continuation depends on the full preceding history. Sharing the former does not license merging the latter.

It also explains the forced-token boundary. A singleton locally masked token law removes a choice. It does not remove the state update needed before the next choice. [The affine forced-span witness](../forced-spans/README.md) contracts those updates exactly; simply omitting them changes the next-choice law in 94 of 97 states.

## The quantity to optimize

For dispatch, extend the state to include resident weights, cached rows, intermediate encodings, retained target decisions and other reusable machine state. An action can build candidates, refine a score bound, contract a known span, verify a tree or adopt accepted continuation state. Let it emit `L` exact target tokens, take time `T`, and leave state `S'`.

The long-run objective is

```
rho = lim E[total emitted tokens] / E[total elapsed time].
```

Under conditions where an average-reward semi-Markov Bellman equation exists, an optimal rate `rho` and relative continuation value `V` satisfy

```
V(s) = max_a E[L - rho*T + V(S') | s,a].
```

Actions inside this maximization must satisfy the observation contract. A cheaper action that changes the target distribution is a different feasible set, not an exact-decoding improvement.

For trials returning to the same action-independent regeneration-state law, the continuation term cancels. Comparing additional candidate work then reduces to `delta E[L] > rho * delta E[T]`. That is the right local rule for the [allocation study](../adaptive/README.md). Real generation need not return to the same distribution of states after each action. Longer blocks change the next dispatch position; cache reuse can change the price of the next block. The continuation term then matters.

[The executable witness](witnesses.py) makes this failure concrete. Every action emits an exact prefix of the same deterministic `ABCABC...` stream. Costs depend on the phase where a block begins. All three per-phase cost curves are monotone in block length. Choosing the best immediate tokens/time traps the decoder in expensive boundaries and yields `3/23` tokens per cost unit. Another policy pays once to reach a cheap boundary and sustains `1`. Exhaustive enumeration of 27 stationary policies and an exact Bellman potential establish the latter rate. These are stipulated costs, not measurements of a transformer.

A practical learned controller should therefore estimate the benefit of a specific action and what reusable state it leaves. A confidence score alone cannot say whether widening a pool, repairing its first token, increasing depth or doing nothing is the best next move.

## Why spare compute is valuable, and where it stops being free

A useful first approximation to a kernel's time is

```
launch + max(bytes / effective_bandwidth, operations / effective_throughput)
       + uncovered_dependency_cost.
```

This is a cost model to fit, not an identity. Fusion, occupancy, attention, synchronization and cache behavior change its parameters and sometimes its form.

Below the compute knee, additional arithmetic can have almost no marginal elapsed cost. An extra branch can reuse a streamed weight matrix; a wider representation can feed a native shuffle directly; a candidate family can share a conditional row. These are the concrete places where compute can replace bandwidth or serial rounds. Once arithmetic, activation storage or synchronization becomes limiting, extra candidates are no longer cheap.

Shared reads also break independent per-node pricing. Our exact four-node witness gives one candidate probability `2/5` on page A and three candidates probability `1/5` each on page B. Page A costs `1`, page B costs `3/2`, and the budget is `3/2`. Even a greedy selector that updates marginal probability/byte after each choice takes A and covers `2/5`. Buying B once covers `3/5`. There is no target-model measurement hidden in this example. It demonstrates the complementarity that a hardware-aware tree builder must represent.

For equal-price nodes with no such interactions, prefix probability remains a sensible oracle ranking. For shared pages or kernels, optimize groups, not merely independently ranked nodes. A measured cost frontier should include pool construction, transition rows, tree metadata, verifier work, output-head work and state adoption. Counting accepted tokens alone misses most of that bill.

## Token entropy is the wrong unit of computational difficulty

Entropy measures uncertainty under a specified distribution. It does not measure the work required to expose that distribution or to certify a sampled decision.

The executable witness contrasts eight known independent fair bits with one hidden deterministic oracle bit. A supplied random byte already samples the former with zero target queries. The latter has zero conditional output entropy for each fixed oracle, yet an algorithm correct for either hidden oracle assignment must query it. The query interface is part of this example; it proves no lower bound for a white-box neural model with accessible weights.

For a fixed context and fixed model weights, hidden activations are deterministic. Inference does not manufacture Shannon information conditional on those complete inputs. It makes consequences of those inputs computationally available. That is why a literal claim that one model pass delivers a fixed number of future-token bits is too strong.

The useful intuition survives in a narrower form. Once a cheap representation predicts the relevant choices accurately, easy spans can amortize one expensive state read over many outputs. What matters is the information still missing from that representation and the cost of resolving it under the actual machine interface. Low surprisal often correlates with that cost in a trained system; it is not a general law.

[Lazy exact sampling](../lazy-sampling/README.md) gives a sharper example. Two integer weight vectors define exactly the same normalized distribution and entropy. Scaling one vector by eight changes rejection-envelope utilization and produces an eightfold change in counted recurring reads under the same sampler and static envelope. Representation and access method affect cost even when the entire output law is unchanged.

An operational definition of difficulty is the cheapest remaining work that certifies the required observation from the available state. For greedy generation, a certified margin can end the decision. For stochastic generation, the random draw and certified probability bounds determine whether more refinement is needed. For a forced span, there may be no selection work at all but considerable continuation-state work.

## A usable rule for easy and hard stretches

For a single draft chain, let `alpha_j` be the probability that position `j` survives verification conditional on all earlier positions surviving. This conditioning matters. Then

```
A_j = P(first j positions survive) = product_{i=1..j} alpha_i
E[accepted draft positions] = sum_j A_j.
```

Writing `ell_j = -log(alpha_j)` gives `A_j = exp(-sum_{i<=j} ell_i)`. These are survival losses of a specified proposal/verifier pair, not the target's token surprisals. A model can cheaply sample an uncertain token with high agreement, or confidently propose the wrong deterministic token.

This makes the user's easy-span intuition precise for speculative progress. Near-unit survival permits long useful chains. One low-survival position discounts every later candidate. Repairing that position can be worth more than extending the tree after it. The [candidate-repair experiment](../candidate-repair/README.md) and [support-changing actions](../action-value/README.md) exhibit this root bottleneck: later support gains do nothing on paths whose first candidate is missing.

For a precommitted target verification tree, the corresponding oracle quantity is

```
E[visited candidate nodes] = sum_{u in tree} P(target prefix = u).
```

Prefix closure and the exact target-sampling contract are required. A path's probability is the product of conditional token probabilities, so cumulative target surprisal now is the correct ranking coordinate. This is a different construction from the chain's proposal-acceptance coupling. It does not say a tree node's probability is known without computing it, nor that all nodes cost the same.

A cheap action-value predictor can estimate how an action changes these reachable prefix masses. Pricing that gain jointly with shared reads gives a concrete controller objective. Predicting raw token entropy alone leaves out both proposal mismatch and whether the action can repair it.

## A whole-map optimization problem

For a chosen target law, workload and error contract, compare implementations by

```
static storage, preparation work, online bytes, online operations,
critical path, emitted progress, continuation state, allowed error.
```

Then choose along the attainable frontier for the actual hardware. This is a problem definition, not a tractable algorithm for finding the global optimum. It also requires explicit amortization. Compiling every possible continuation into a lookup table merely moves the cost to storage and preparation unless reuse justifies it.

Kelana's contribution to this search is permission to change the intermediate coordinates. The producer need not construct recognizable logits, independent token predictions or unpacked transition matrices if the final consumer can use a cheaper jointly designed state. The required target observation and continuation remain fixed. The [2x2 example](../../toy2/radix64/README.md) is the small exact demonstration of that principle, not evidence that an arbitrary transformer admits the same contraction.

The most promising next measurements are therefore coupled producer/consumer experiments:

1. Train the proposal representation for accepted progress after the already-computed target token, rather than for corpus next-token loss alone.
2. Price a learned conditional selector through native map construction and consumption, including hypothetical rows never visited by the sampled path.
3. Route extra work using its measured marginal gain, including how it changes future cache and dispatch state.
4. Find exact certificates or known-span contractions whose construction is cheaper than the full computation they avoid.

The five parallel third-round experiments cover pieces of this list. None alone establishes an end-to-end decoder speedup. The decisive experiment will put candidate construction, exact verification and continued generation in one timed loop.

## What the coupled runtime added

The [fifth-round loop](../online/COUPLED.md) gives the decision-cost view a sharper test. A canonical-token protocol has three branch decisions across 44 emitted tokens; batching the forced runs reduces target calls to four and yields 9.61x throughput. The same allowed byte strings under a full tokenization-support mask instead require 77 branch decisions across 79 emitted tokens and gain only 1.022x. Both contracts preserve their own observed paths and continuation decisions. They are not the same target law.

If the external consumer only requires a valid record, the canonical protocol may satisfy that task without preserving the byte-masked model's internal token decisions. If the external consumer requires the original distribution of records, changing tokenizations also changes continuation-state mixing and needs a stronger equivalence witness. This is exactly where whole-map reasoning should begin: declare the observation before pricing intermediates.

In unrestricted continued generation, a complementary retrieved edge and training on on-generation states improve throughput, while the learned cost-aware router loses to fixed trees. The mathematical optimization rule does not supply accurate action values for free. Representation, available information, prediction quality and implementation cost all enter the same experiment.

## Reproduction and custody

Run from the Kelana root:

```sh
python3 research/speculative-maps/theory/witnesses.py
```

This standard-library program enumerates both finite optimization witnesses using rational arithmetic and writes [witnesses.json](witnesses.json) with its source hash. It also records the oracle-interface argument. No model, GPU, external data or new service is required. The source and receipts live in Kelana Git, linked from the [speculative-map index](../README.md). The owning investigation is thread `55878d53-abd5-4cde-a82b-2b42014a9ac0`.
