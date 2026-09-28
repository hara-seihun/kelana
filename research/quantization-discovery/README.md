# Quantization discovery with a work budget

This investigation asks how to discover compressed representations without fixing an integer number of bits per weight, and what can still be certified when search stops. the project lead commissioned the literature review and mathematical investigation on September 21, 2026. The first round develops tractable assignment families, anytime bounds, and consumer-aware state reduction. It does not change Bonsai serving or claim a GPU speedup.

Start decomposition work at [quantization representations and executable decompositions](representations/README.md). Its [existing-work map](representations/MAP.md) brings together the scale-placement, factor, dictionary, whole-map and native-consumer investigations across Kelana. the project lead's September 23 direction asks us to challenge scalar codes plus separate scales as a representation family, not just improve its fit.

[Sub-bit quantization and direct inference](subbit/README.md), commissioned on September 22, owns the detailed Qwen3-0.6B factor and cache studies. [Complete ternary conversion](../ternary/README.md) owns packed whole-model quality and recovery. Discovery and quality/rate/cost scaling are the goal; the exact-domain proofs below are reusable tools, not prerequisites for lossy quantization research.

The [four-bit diagnosis](q4-diagnostic/README.md) separates body and tied embedding/head damage in the Qwen3-0.6B control, then compares calibrated conversion against the actual rounding images. It checks whether the conversion baseline is sound before attributing lost language quality to a lower-bit representation.

Start with the [prior-art review](PRIOR-ART.md), then the [mathematical results](MATHEMATICS.md). The review distinguishes established algorithms from this repository's new constructions and implementation. No literature-novelty claim is attached to a triangle-inequality lemma, dynamic programming, branch-and-bound, or norm duality.

## Exact direct consumption for every input

[DIRECT.md](DIRECT.md) replaces whole-row fiber reconstruction with short packed ternary codes that index response tables built for the current input. Lean proves exact lookup, block composition, a chunk-size work crossover and sign-orbit folding. The [SIMD implementation](SIMD.md) now takes **7.835 µs including fresh table preparation**, versus **13.464 µs** for the AVX-512 VNNI dense control in a rotating paired CPU panel. It is **1.72x faster**, with **2.68% more storage than HALO** for this block. A byte-index variant reaches 3.730 µs but spends 60.71% more storage than HALO. All 655,360 trits round-trip in both formats, all twelve input panels match, and Lean proves signed16 response and prefix bounds. These are single-core integer-block results, not GPU or full-model throughput; no serving runtime changed.

The [gfx1151 follow-up](gpu-direct/README.md) measures a single-query wave-register lookup from the same sign-folded labels on the real 5,120×128 block. It matches all twelve integer input panels but takes 9.299 µs per launch against 3.505 µs for packed two-bit and 3.287 µs for dense int8 controls. The CPU speedup does not transfer to this lowering; the native program and paired samples identify a bounded negative, with no serving change.

## Lossless response-first representation

[FIBER.md](FIBER.md) removes the local guard requirement by storing a useful dot response first and an exact rank within its response class behind it. Generic Lean proofs establish rank/unrank inversion and at most one extra payload bit above fixed ternary capacity. The complete real 5,120-row block shrinks from 143,360 to 140,948 bytes, including scales, probe and header. All 655,360 original trits round-trip. The warm prefix index adds 336 bytes. A matching query touches 20,512 row-data bytes; arbitrary other inputs remain exact through reconstruction from the same image. A first-coordinate perturbation reconstructs only one trit per row. Cold count workspace and dense misses remain expensive; this is not a GPU throughput result.

## Source-aware local enclosure

[ENCLOSURE.md](ENCLOSURE.md) implements the pinned gfx1151 floating-point producer from fixed upstream int8 codes and bounded FP32 scales. It carries shared generators through the actual FMA, SiLU, Hadamard and quantizer operations. A real 128-weight block has a five-byte exact replacement over a certified local input contract, but its literal guard needs 5,440 bytes. This is progress on conditional quantization, not a net storage or deployed inference win.

## Correlated producer follow-up

The [producer-domain investigation](PRODUCER.md) now adds exact affine support with attaining witnesses, safe elimination of completed generator factors, and an integer-replayed robust optimum on the real block. A 160-block chain needs only two states and 638 transitions. A constructed nonzero consumer admits exact 0.375-bit/weight storage across its entire producer domain. On actual Bonsai gate/up integer accumulators, keeping the common input tightens two joint-probe bounds by 27.9% and 41.9%. The fitted hidden-activation Hadamard box still fails all five held-out captures and its robust codec optimum is larger than HALO. These are mathematical and search results, not deployed model compression.

## Where the first round got

1. **Exact equality is not necessary for safe state reduction.** If a cheaper partial representation pays for the worst possible downstream effect of changing its response, it can replace a more expensive one for every common suffix. The directed relation is transitive. For scalar absolute error, we go further: checking only the minimum and maximum attainable suffix responses is necessary and sufficient for dominance. Even equal-cost, unequal-response prefixes can be reduced this way. The suffix set may have arbitrary holes.
2. **The search can stop with a replayable interval.** A feasible representation gives an upper bound; interval, residue and signed min-sum relaxations give lower bounds. The proof record covers every branch, including branches represented by another prefix. A timeout is not reported as optimality.
3. **A stronger accuracy contract can make the optimization easier.** For one linear row over the complete integer input box, worst-case output error is exactly the box radius times the L1 weight error. With independent block choices and additive charges, the globally optimal robust representation is found by choosing each block independently. This is a theorem for arbitrary length, not a finite-input enumeration.
4. **Sub-one-bit storage is easy to demonstrate and easy to misuse.** The real Bonsai block experiment constructs an eight-byte representation of 128 trits, including its FP16 scale. Its error is 25 on three calibration observations, 763 on five held-out observations, and exactly 11,684 on the worst input in the declared integer box. It is not an acceptable model quantization result.

## The finite assignment problem

Block `i` has a finite menu of representations. A choice provides:

- its exact response vector `v_i` on the declared consumer observations;
- its model-dependent storage bits;
- a declared online operation charge;
- a label identifying an executable codec option.

The current integer objective is

```
J = static_bits + sum(bits_i + operation_price * operations_i)
    + error_price * max_j |sum_i v_i[j] - target[j]|.
```

No intermediate weight tensor is required by the abstract solver. The concrete real-weight experiment uses a fixed prefix-free codec whose shared decoder is in [codec.py](codec.py). It has zero, repeated-sign, alternating-sign, and eight-trit literal modes. Model-dependent literal values and the FP16 block scale are counted. The mode lengths differ, so the assignment does not prescribe a fixed integer bit count per weight. The generic shared decoder is not charged as model-dependent storage. Its arithmetic cost is a separate declared objective, not a measured GPU instruction count.

Menus, scales, the observation domain and prices are frozen for each search. This certifies assignment within that family. It does not globally optimize arbitrary learned dictionaries, continuous scales or programs. A model-dependent shared dictionary must be charged once and its usage state must be retained if it changes which suffixes are available. It cannot silently disappear into the shared runtime.

## Mathematics and proof ownership

- [QuantizationDominance.lean](../../Kelana/QuantizationDominance.lean): paid metric dominance, the exact scalar suffix-endpoint characterization, transitivity, suffix replacement, nonexpansive transition preservation, transfer of a lower bound through a dominating cover, and all-size example families. The distance is instantiated for integer scalar responses and the maximum over a finite observation list.
- [QuantizationCertificates.lean](../../Kelana/QuantizationCertificates.lean): global bounds from local region bounds and complete coverage, feasible incumbents, safe pruning, refinement, and optimality when endpoints meet. See [CERTIFICATES.md](CERTIFICATES.md).
- [QuantizationBounds.lean](../../Kelana/QuantizationBounds.lean): interval/residue closure over arbitrary suffix lists, projected error bounds, ceiling division, and the signed min-sum dual. See [BOUNDS.md](BOUNDS.md).
- [BoxQuantization.lean](../../Kelana/BoxQuantization.lean): exact support function of the complete integer box, an explicit worst-case input, and global optimality of independent local minima for additive objectives.

These modules use Lean 4.33.0 and Std, without Mathlib, `sorry`, or custom axioms. Some proofs use Lean's standard `propext`, `Classical.choice` and quotient axioms. The Python search is not a formally verified implementation. The replay checker uses the mathematical rules, shares the integer bound evaluator with the search, and checks the recorded branch cover and dominance witnesses. There is no claim that a generated Python transcript is already a Lean proof term.

## Executable evidence

The complete deterministic run is [experiments.py](experiments.py); its output is [results.json](results.json). It took about four seconds on local GPU host. Individual computations are bounded below one minute.

### Structural families, not success by adding another constant

The Lean statements apply at every family size. The run at 160 choices illustrates the work reduction:

| Family | Raw assignments | Exact response equality | Stronger reduction |
|---|---:|---:|---:|
| Binary choices contributing to the same two response coordinates | `2^160` | 161 maximum live states, 25,760 transitions | Not needed |
| Zero versus a costly two-unit response | `2^160` | 161 maximum live states, 25,760 transitions | Paid metric: **one live state, 320 transitions**, same optimum |
| Equal-cost zero/one responses, target beyond reachable range | `2^160` | 161 maximum live states, 25,760 transitions | Suffix endpoints: **one live state, 320 transitions**, same optimum |

For the second family, after `n` blocks and `k` nonzero choices, response is `2k`, paid cost is `n+5k`, and error price is 2. The all-zero prefix has cost `n` and dominates because `n+4k <= n+5k`. The proof is independent of the target and of `n`.

For the third family, metric dominance retains all 161 states because costs are equal. The exact suffix-aware rule retains only the larger response: every possible completion stays below the target. `scalar_dominance_iff_endpoints` proves the complete two-check test for arbitrary scalar prefixes, prices and bounded suffix sets with attained extrema. This is not an endpoint claim for multidimensional error.

In a parity family with 64 binary choices, every response is even but the target is 65. Ordinary interval bounds need 1,056 expansions to certify the optimum. The interval-plus-residue bound certifies the same optimum at the root, with **zero search expansions**. Both runs still pay preprocessing and 514 feasible-seed evaluations. `parity_family_floor` and `parity_family_attains` cover every even family length.

### A real Bonsai block

The self-contained [instance](instances/bonsai-layer00-block0.json) records 128 trits from row 0, K-block 0 of layer 0's down projection, plus eight captured integer hidden operands. It names the source dataset and byte hashes. No model download or GPU run is needed to replay it.

Three input observations are used for search; five are held out. The 16 eight-trit blocks each have six options, so there are `6^16 = 2,821,109,907,456` assignments. The error price is one and operation price zero in this panel: the reported objective units are bits plus maximum absolute integer-response error, not seconds or a quality benchmark.

| Expanded prefixes | Lower bound | Feasible upper bound | Gap | Search time, approximately |
|---:|---:|---:|---:|---:|
| 0 | 41 | 88 | 47 | 0.005 s |
| 32 | 43 | 88 | 45 | 0.016 s |
| 256 | 44 | 88 | 44 | 0.13 s |
| 2,048 | 46 | 88 | 42 | 1.0 s |

The incumbent has 63 meaningful bits including the scale, or 64 bits as a standalone byte-padded packet. [results.json](results.json) records the packet and its decoder round trip. That is **0.5 stored bits per original weight** for this block. Its calibration error is 25. The code charges 24 abstract arithmetic units, but that term is not priced in this particular objective.

The seed already found the incumbent. Search improved the lower bound, not the candidate. At 2,048 expansions, disabling the signed cost/error dual leaves the lower bound at 37 rather than 46. The unresolved gap is substantial; the report does not manufacture an optimum.

The [12,289-node certificate](certificate-bonsai.json) independently records the search cover, lower-bound leaves, complete witnesses and dominance references. [check_certificate.py](check_certificate.py) replays it without running the search policy. The replayed interval is `[46,88]`.

On the complete input box `[-127,127]^128`, `BoxQuantization.robust_value` supplies a worst-case input directly. The sampled candidate's exact unscaled error is **11,684**. The robust optimum in the declared block-mode family is found by examining **96 options**, not `255^128` inputs or `6^16` assignments: it chooses every literal, costing 272 bits with zero error. Original HALO storage is 224 bits, so that robust answer is worse than the source codec. This gives no real-model compression win. It exposes exactly which statistical assumption made the apparent sub-bit result possible.

All error numbers here are integer sub-dot-product units before the shared block scale and per-token activation scale. They are not residual RMS, logit error, perplexity or full-model quality.

### Checks performed

- 55,689 arithmetic-progression distance cases against explicit enumeration.
- All 6,561 eight-trit patterns round-trip through the codec.
- 193 interrupted/completed search intervals and complete cover replays against exhaustive optima of deterministic small instances, including ten scalar endpoint dominance steps.
- A deliberately corrupted lower endpoint is rejected by the checker.
- Exact and dominance-pruned dynamic programs agree with the exhaustive cases.
- All four new Lean modules compile; their proof sources and `#print axioms` output separate assumptions from conclusions.

## Reproduce

From the repository root:

```sh
lake build Kelana.QuantizationDominance Kelana.QuantizationCertificates \
  Kelana.QuantizationBounds Kelana.BoxQuantization
python3 research/quantization-discovery/experiments.py
python3 research/quantization-discovery/check_certificate.py \
  research/quantization-discovery/instances/bonsai-layer00-block0.json \
  research/quantization-discovery/certificate-bonsai.json
python3 research/quantization-discovery/search.py \
  research/quantization-discovery/instances/bonsai-layer00-block0.json \
  --expansions 2048 --seconds 4
```

`experiments.py --capture` rebuilds the small fixture from `/path/to/workspace/data/kelana-ffn`; normal reproduction uses the committed fixture. The owning [dataset documentation](/path/to/workspace/data/kelana-ffn/README.md) records how those real activations were captured. The report hashes the solver, checker, codec, experiment runner and instance. Timings are evidence for this host and these instances, not complexity theorems.

`--expansions` bounds expanded prefixes, not all CPU instructions. Preprocessing, feasible-seed evaluation, dominance checks, branch generation, certificate output and replay are separately visible. The seconds guard is checked between expansions, after preprocessing. It is not a hard real-time guarantee or an excuse for an unbounded seed routine. The recorded workload completes in seconds; use a foreground process timeout below 60 seconds for new investigations.

## Direction taken in the follow-up

[PRODUCER.md](PRODUCER.md) records the second round. Affine generator domains now have exact support proofs, factor-separator search and signed dual certificates. The source-derived gate/up integer domain is genuinely shared-input. A fitted hidden-domain box is not a producer guarantee, as its held-out failures show.

[ENCLOSURE.md](ENCLOSURE.md) now supplies the outward local evaluator for the nonlinear, dynamically scaled producer. Its upstream code/scale contract is explicit and executable. Extending through the preceding RMS normalization and replacing the large literal guard with a broad, cheap input invariant remain open tasks.

The calibration objective's `[46,88]` gap remains unresolved; the correlated-domain experiment uses a different robust objective and does not close that gap. Its own matching bounds prove a 272-bit optimum, worse than HALO's 224 bits. Native online cost, shared dictionary design and general instruction synthesis remain outside these assignment optimality claims.
