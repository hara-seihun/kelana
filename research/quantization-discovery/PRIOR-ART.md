# Prior art for consumer-aware quantization discovery

## Question and terminology

The investigation asks for a compressed representation that is cheap for a specified consumer to execute, not merely a low-error reconstruction of its input. It also asks for useful answers under a fixed search budget, with a valid lower bound and a realizable upper bound when exact optimization is too expensive.

Several older fields contain parts of this problem. None of their terms should be identified without checking the contract:

- **Fixed-codebook assignment** chooses indices after the reconstruction values, decoder, or trellis have been fixed. **Codebook design** also changes those objects. The first problem can be a shortest path or low-treewidth dynamic program even when joint design remains nonconvex or combinatorial.
- **Entropy** is a distributional lower bound on average lossless description length. It is not automatically the bytes in a model file, a fixed-width index rate, or a random-access representation.
- **Exact consumer equivalence** means that two states give the same result for every allowed continuation. An error ball or an observed small discrepancy is not an equivalence relation. In particular, epsilon-closeness is not transitive.
- **Information-theoretic rate** is commonly an asymptotic expected rate over long iid blocks. A finite executable representation also pays for codebooks, scales, alignment, decoder state, and the instructions and memory traffic used by the consumer.
- **A search certificate** is a pair `L <= OPT <= U` for minimization. A good incumbent without a lower bound is not a certificate.

The closest established algorithmic model is a finite-domain, min-sum factor graph or weighted decision diagram. Code indices are variables, local consumer effects are factors or state transitions, and the path cost includes distortion, representation cost, or both. The useful question is then whether the consumer exposes a small exact separator state, and what certified relaxation remains when it does not.

## Quantization and rate

### Fixed-rate and entropy-constrained quantization

For a fixed reconstruction codebook and a pointwise distortion, ordinary nearest-neighbor assignment is exact: map each source vector to a codeword that minimizes its distortion. The [Linde-Buzo-Gray paper](https://doi.org/10.1109/TCOM.1980.1094577) alternates this assignment with a reproduction update. Each step decreases the training objective under its stated conditions, but the procedure gives a local design, not a global codebook certificate.

Entropy-constrained vector quantization changes the assignment cost. [Chou, Lookabaugh, and Gray](https://doi.org/10.1109/29.17498) minimize a Lagrangian of expected distortion and output entropy. With reproduction values and index probabilities fixed, an input is assigned using distortion plus an ideal length term proportional to `-log p_i`. The algorithm then updates probabilities and reproduction values. The paper proves descent and local optimality properties for this alternating construction. It does not globally solve arbitrary vector-codebook design.

That paper is also unusually clear about the rate distinction. The entropy of a memoryless index is below the expected length of any binary prefix code, while a Shannon code has expected length less than entropy plus one bit per coded index. Longer block or arithmetic codes can approach an entropy rate. They add buffering, variable length, and a coding format. A nominal `b`-bit index array instead costs `b` bits per index regardless of its empirical entropy. For model weights, codebook and scale metadata must be counted separately.

There are globally solvable scalar cases. [Muresan and Effros](https://doi.org/10.1109/TIT.2007.911170) reduce discrete-alphabet scalar quantizer design to histogram segmentation and a shortest path in a directed acyclic graph. They obtain polynomial-time global optima for conventional fixed-rate and entropy-constrained scalar quantizers. The assumptions matter: the source alphabet is ordered, the admissible quantizer cells have the required interval or convexity structure, and the edge cost of a segment can be computed independently. This result does not extend unchanged to unrestricted vector partitions. Indeed, [György and Linder](https://doi.org/10.1109/18.978755) show why regularity of entropy-constrained scalar cells needs hypotheses and can fail for discrete sources.

The relevant lesson is not that quantization is generally easy. It is that exact dynamic programming appears when assignment can be ordered into segments with additive segment costs. Kelana should look for an analogous ordering induced by the consumer, rather than assume a Euclidean Voronoi partition.

### Remote, task-based, and functional source coding

Remote source coding makes the encoder observe a variable correlated with the target rather than the target itself. [Dobrushin and Tsybakov](https://doi.org/10.1109/TIT.1962.1057738), [Wolf and Ziv](https://doi.org/10.1109/TIT.1970.1054469), and [Witsenhausen](https://doi.org/10.1109/TIT.1980.1056251) establish the basic reduction. For memoryless sources and separable expected distortion, replace the target distortion by its conditional expectation given the encoder observation. The indirect problem then becomes a direct rate-distortion problem on the observation. For squared error this exposes the familiar estimation-error decomposition.

This is consumer-aware in a statistical sense, but its guarantee is average and distribution-dependent. It does not identify two concrete machine states as interchangeable, and it does not provide a finite codebook search algorithm. Shannon rate-distortion values are asymptotic limits over block codes, not operational model sizes.

Functional source coding asks the decoder to recover `f(X,Y)`, often with `Y` available only at the decoder. [Orlitsky and Roche](https://doi.org/10.1109/18.915643) give the one-way vanishing-error rate as conditional graph entropy for finite iid sources. Their characteristic graph has an edge between `x` and `x'` when some supported `y` requires the decoder to distinguish them because `f(x,y) != f(x',y)`. An encoder message may identify an independent set containing `X`. [Doshi, Shah, Medard, and Effros](https://dspace.mit.edu/handle/1721.1/67497) relate this to entropy colorings of graph products and extend the construction to selected lossy settings.

This result marks an important boundary:

- With no side information, equal fibers of a deterministic consumer form an equivalence relation, and encoding the fiber label is enough.
- With decoder side information, pairwise compatibility need not be transitive. The right object is a characteristic graph and its independent sets, not a quotient by an equivalence relation.
- Conditional graph entropy is an asymptotic rate under the paper's finite-alphabet, iid, support, one-way communication, and vanishing block-error assumptions. Strict zero-error and one-shot prefix coding have different graph quantities and computational problems. [Witsenhausen's zero-error side-information result](https://doi.org/10.1109/TIT.1976.1055607) uses graph coloring, while [Koulgi et al.](https://web.ece.ucsb.edu/publications/rose/pubs/pub40-T-IT1-03.pdf) distinguish zero-error asymptotic rates and show hardness for an instantaneous code-design problem.

Lossy functional coding is older than the current "semantic compression" vocabulary. [Yamamoto](https://doi.org/10.1109/TIT.1982.1056560) gives a Wyner-Ziv rate-distortion formula when the decoder estimates a function of correlated finite sources using decoder side information. Again, this is a coding theorem with an auxiliary random variable and expected distortion, not a claim that approximate observations induce a safe quotient of finite search states.

Modern task-based quantization makes the objective more concrete. [Shlezinger, Eldar, and Rodrigues](https://arxiv.org/abs/1807.08305) design analog combining, scalar ADCs, and digital estimation for a parameter-recovery task. Their main analytic cases rely on statistical models, quadratic criteria, and hardware restrictions on the quantizer. [Goal-oriented quantization](https://doi.org/10.1109/JSAC.2022.3221976) instead measures degradation in a downstream optimization objective and derives high-resolution designs. Both support optimizing after the consumer. Neither supplies the finite exact assignment and anytime certification sought here.

## Current low-bit weight quantizers

The recent LLM methods are best read as representation families plus heuristic design procedures. Their fast inference formats are directly relevant. Their training or post-training optimizers do not by themselves certify a global assignment optimum.

| Method | Representation and consumer objective | Assignment versus design | What is certified |
| --- | --- | --- | --- |
| [AQLM](https://proceedings.mlr.press/v235/egiazarian24a.html) | A weight vector is a sum of entries from several learned codebooks. Calibration activations weight the layer-output error. Inference performs codebook lookups and accumulation. | It initializes by residual k-means, alternates discrete codes and continuous codebooks, and fine-tunes transformer blocks. The code update is a beam search on a fully connected discrete MRF, as described in the [paper's algorithm section](https://arxiv.org/html/2401.06118#S3.SS2). Beam search is approximate and dropped configurations carry no lower-bound certificate. | A constructed model and measured loss. No global certificate for code assignment or joint codebook design. |
| [QuIP#](https://arxiv.org/html/2402.04396) | Randomized Hadamard transforms make weights and curvature more incoherent. Structured `E8`-derived vector codebooks support lookup-based inference. BlockLDLQ uses a Hessian proxy and adaptive rounding. | The lattice family is prescribed rather than learned as an unrestricted table, but rounding is embedded in sequential BlockLDLQ and followed by fine-tuning. | The paper proves incoherence and error bounds under its assumptions. Those bounds are not an optimality certificate for a particular quantized model. |
| [VPTQ](https://aclanthology.org/2024.emnlp-main.467/) | Vector indices and lookup tables are optimized with a second-order layer-output proxy, with residual and outlier options. | It constructs codebooks with a decomposed initialization, assigns vectors, and propagates or refines errors using channel-independent second-order updates. The codebook is part of the optimization. | A feasible compressed model and empirical quality. No lower bound on the best model in the declared representation family. |
| [QTIP](https://proceedings.neurips.cc/paper_files/paper/2024/file/6de2e84b8da47bb2eb5e2ac96c63d2b0-Paper-Conference.pdf) | A stateful bitshift trellis defines a high-dimensional implicit codebook whose decoder ranges from lookup-only to computed lookup-free forms. | For a fixed trellis and additive per-position distortion, Viterbi finds the optimal path in `O(2^L T)` for `2^L` states and sequence length `T`. The full LLM method also uses incoherence processing and BlockLDLQ, so the local Viterbi statement should not be inflated into a global optimum for the Hessian-weighted model problem. | Exact fixed-trellis assignment for the stated additive metric. No certificate for choosing the trellis family, transforms, or jointly fine-tuned model. |

QTIP is the cleanest direct precedent for "compressed and executable by the consumer." Its decoder state is part of the code, and fixed-code assignment is exact because the distortion decomposes along a finite trellis. This is classical trellis-coded quantization. [Marcellin and Fischer](https://doi.org/10.1109/26.46532) used a Viterbi encoder for a fixed finite-state trellis, motivated by alphabet-constrained rate-distortion theory. [Forney's account of the Viterbi algorithm](https://doi.org/10.1109/PROC.1973.9030) states the exact condition: paths correspond to state sequences and the objective factors into additive branch metrics.

AQLM shows the opposite case. Additive codebooks make inference compact, but interactions among codebook choices produce a dense discrete MRF. Its beam is a practical assignment heuristic, not an exact DP state. The original [additive quantization paper](https://openaccess.thecvf.com/content_cvpr_2014/papers/Babenko_Additive_Quantization_for_2014_CVPR_paper.pdf) likewise separates a useful sum-of-codewords representation from the difficulty of encoding and learning it.

These examples support a strict experimental split:

1. freeze every codebook, scale, transform, decoder transition, and layout;
2. solve or bound assignment to that executable family;
3. only then compare representation families or update their continuous parameters.

Without that split, a statement about an exact assignment solver can be mistaken for a statement about globally optimal quantization.

## Exact dynamic programming over consumer state

### Min-sum variable elimination

Suppose fixed representation choices `z_1,...,z_n` have finite domains and the objective factors as

```text
C(z) = sum_a phi_a(z_scope(a)).
```

Eliminating one variable by pointwise minimization creates a new factor on the uneliminated neighbors. This is the min-sum instance of bucket elimination. [Dechter's bucket-elimination paper](https://ics.uci.edu/~dechter/publications/r76A.pdf) relates it explicitly to nonserial dynamic programming and gives time and space exponential in the induced width of the chosen elimination order. For domain size at most `q` and induced width `w`, the usual table implementation has factors of size on the order of `q^w` and elimination work on the order of `q^(w+1)` per bucket, up to problem-size and arity factors.

The assignment on the current separator is a sufficient state because all eliminated variables affect the future only through factors touching that separator. Nothing requires the state to reconstruct the original weights. It needs to preserve the residual consumer cost function.

This is established machinery for exact consumer-aware assignment when the consumer objective has low treewidth. It also says exactly why AQLM's fully connected code-selection MRF defeats the same method unless extra algebraic structure reduces the effective interaction graph.

### Trellises, residual functions, and weighted decision diagrams

For a sequential consumer with state transition `s' = T_t(s,z)` and additive cost `c_t(s,z)`, Bellman's recurrence is a shortest-path computation in a layered graph. The state is sufficient if every two prefixes mapped to it have the same feasible suffixes and the same suffix cost function, after accounting for any prefix-cost offset. Viterbi and trellis-coded quantization are special cases.

Exact state merging therefore needs more than equal current observations. Two prefixes may have the same observed output today and different responses to a later instruction. The unweighted version is the right-congruence idea behind the [Myhill-Nerode theorem](http://faculty.otterbein.edu/dstucki/COMP3200/RabinScott1959.pdf): prefixes are equivalent when every continuation gives the same acceptance result. In a costed problem, the residual object is a continuation-to-cost function. Cost offsets can be pushed onto arcs before equivalent residuals are merged.

[Hooker's weighted decision-diagram treatment](https://johnhooker.tepper.cmu.edu/DDandDP2.pdf) makes this DP connection precise. For a fixed variable ordering and objective, canonical arc costs permit a unique reduced weighted decision diagram under the paper's representation. This is close to the proposed "consumer sufficient state plus min-plus costs." It already establishes that state-dependent costs and future behavior, rather than raw partial assignments, determine exact reducibility.

Weighted automata provide a broader algebraic language, with shortest-path computation over the tropical semiring `(min,+)`. That language is useful but comes with a warning. Boolean DFA minimization does not transfer wholesale to arbitrary tropical weighted automata. Determinization and equivalence need additional assumptions, and general tropical cases have substantially harder decision problems. Kelana's finite acyclic assignment diagrams avoid many of those pathologies and should state that restriction rather than cite weighted-automata minimization as a black box.

### What is established and what remains specific

The generic theorem is straightforward:

- if a finite consumer state makes transition legality and incremental cost Markovian, layered min-plus DP is exact;
- if a factor-graph separator captures every factor crossing an elimination cut, variable elimination is exact;
- if two prefixes have identical feasible continuation sets and residual costs up to a known offset, an exact weighted diagram can merge them.

The research work lies in deriving a small such state from an actual packed consumer, proving that it is sufficient, and pricing the resulting executable representation. The literature does not make that derivation automatic for GPU instruction maps.

## Certified approximations and anytime search

### A*, branch-and-bound, and mini-buckets

For minimization, an admissible heuristic `h(n)` lower-bounds the best completion of a partial state. Then `f(n)=g(n)+h(n)` lower-bounds every solution through `n`. [A*](https://doi.org/10.1109/TSSC.1968.300136) returns an optimum under its graph and heuristic assumptions. Before termination, if the frontier still covers every unresolved solution, `min f` over that frontier is a global lower bound. Any complete feasible assignment supplies an upper bound.

This yields the basic fixed-work certificate. After any chosen number of expansions,

```text
L = minimum lower bound over all unresolved regions
U = cost of the best feasible assignment found
```

satisfies `L <= OPT <= U`. Search order changes how fast the gap closes, not the validity of the pair. If states are discarded without retaining a valid summary bound, the lower certificate is lost.

[ARA*](https://proceedings.neurips.cc/paper/2003/file/ee8fe9093fbbb687bef15a38facc44d2-Paper.pdf) is a direct anytime precedent. It reuses prior search while decreasing a heuristic inflation factor. The paper also computes an empirical suboptimality ratio from the incumbent goal cost and a lower bound from unweighted frontier values. Its multiplicative statement needs the paper's nonnegative-cost setting and a positive denominator. An additive `U-L` certificate is safer for objectives that may be zero.

Bucket elimination has a width-bounded relaxation. [Dechter and Rish's mini-bucket scheme](https://ics.uci.edu/~dechter/publications/r62a.pdf) partitions an expensive bucket into smaller pieces. For minimization, the resulting functions give lower bounds and admissible heuristics, with an `i`-bound controlling table width. Full bucket elimination is recovered when the bound reaches the induced width. [Kask and Dechter](https://arxiv.org/abs/1301.6708) put these monotone admissible heuristics into best-first and branch-and-bound search. [Marinescu and Dechter](https://www.ijcai.org/Proceedings/05/Papers/1556.pdf) combine mini-bucket heuristics with AND/OR branch-and-bound so that graph decomposition remains visible to search.

This is already a generic answer to "exact when narrow, anytime with certificates when wide." The missing work is a strong problem-specific relaxation. A width parameter alone does not promise a useful gap under a fixed budget.

### Relaxed and restricted decision diagrams

Bounded-width decision diagrams give the cleanest paired bounds. For a minimization problem:

- a **relaxed** diagram over-approximates feasible paths and does not overstate their costs, so its shortest path is a lower bound;
- a **restricted** diagram retains only feasible paths, so its best terminal path is an upper bound.

[Optimization bounds from BDDs](https://www.andrew.cmu.edu/user/vanhoeve/papers/Bounds_from_BDDs.pdf) establishes the relaxed-diagram construction for additively separable objectives. [Bergman, Cire, van Hoeve, and Hooker](https://www.andrew.cmu.edu/user/vanhoeve/papers/discrete_opt_with_DDs.pdf) combine relaxed diagrams, restricted diagrams, and branch-and-bound for general discrete optimization models expressed as dynamic programs. Width is controlled by merging states for a relaxation or dropping states for a restriction.

The validity of a merge is not automatic. [Hooker's node-merger conditions](https://arxiv.org/html/1908.07076) require the merged state to admit every control of each original state and assign no greater immediate cost in the minimization convention. Cost adjustment may be required. A nearest-looking pair of consumer states is not enough.

Refinement can start with a width-one over-approximation and split nodes to remove spurious paths. This is used in limited-width MDD compilation and in [peel-and-bound](https://doi.org/10.4230/LIPIcs.CP.2022.35). The pattern resembles counterexample-guided abstraction refinement. In the original [CEGAR paper](https://doi.org/10.1007/10722167_15), an abstract model may admit a spurious counterexample, which is analyzed to split the abstraction while retaining sound over-approximation. CEGAR is a safety-verification method, not an optimization bound by itself. Relaxed DDs add costs and pair the abstraction with a shortest-path bound.

A useful implementation should maintain all three objects separately:

1. an incumbent representation that can actually execute;
2. an over-approximation that covers every unsearched representation;
3. a refinement or branching map showing that discarded abstract behavior was either infeasible, dominated, or transferred to another covered region.

Ordinary beam search has only the first object. Beam-stack search, DD branch-and-bound, or another backtracking summary is needed for completeness and a retained lower bound.

## Paid Lipschitz dominance and arithmetic residue bounds

### Position of the proposed dominance rule

The current solver has prefixes with accumulated cost `c`, consumer response `r`, and a continuation objective of the form

```text
c + lambda * ||r + suffix - target||_infinity.
```

For prefixes `a` and `b` with the same allowed suffixes, the condition

```text
c_a + lambda * ||r_a - r_b||_infinity <= c_b
```

implies that `a` is no worse than `b` for every shared suffix. This follows directly from the triangle inequality. More generally, if every continuation value `G(r,u)` is uniformly `L`-Lipschitz in `r`, then

```text
c_a + L * d(r_a,r_b) <= c_b
```

is enough to delete `b`. If `d` is a directed hemimetric, symmetry is unnecessary. The triangle inequality also makes this paid-dominance relation transitive.

This is not an equivalence merge. It is one-sided exact pruning, and it needs a completion correspondence when the two prefix states do not have identical suffix sets.

The ingredients have clear precedents:

- [Piyavskii's Lipschitz global-optimization algorithm](https://doi.org/10.1016/0041-5553(72)90115-2) uses cones derived from `|f(x)-f(y)| <= L d(x,y)` to maintain global bounds. The proposed rule uses the same inequality on a known continuation family to discard a prefix, rather than to bound an unknown function over a continuous region.
- Exact resource-constrained shortest-path solvers keep nondominated labels and delete a label when another has no greater cost and no worse resource state. The [exact-solution survey](https://doi.org/10.1002/net.21511) covers these labeling methods. Paid metric slack extends componentwise label dominance: a cheaper prefix may compensate for a worse response state by an upper bound on every future loss.
- In planning and transition systems, a cost-respecting simulation is a dominance relation because every continuation from the dominated state has a no-more-expensive matching continuation. Quantitative simulation replaces Boolean simulation by a directed distance. [Fahrenberg, Thrane, and Larsen](https://arxiv.org/abs/1107.1205) develop trace and branching distances from hemimetrics and prove triangle properties under their assumptions. The solver's rule can be read as paying for such a simulation distance with prefix-cost slack.
- Decision-diagram dominance rules delete a state when another partial path can cover all of its completions at no worse objective. Relaxed DD merger is different: it retains an optimistic union to produce a lower bound. The two operations should have distinct certificates.

The rule is therefore well situated as a metric, cost-compensated dominance test. A contribution would be its proof-carrying use with the actual consumer response and its integration with assignment bounds, not the triangle-inequality lemma in isolation.

### Intervals, affine forms, and congruence

A suffix interval gives a cheap convex enclosure of every reachable consumer response. Projecting the target onto that interval yields a valid norm lower bound. It misses holes. If the same projection is known to lie in an affine lattice `a + g Z`, a residue or gcd calculation can prove that values inside the interval are still unattainable and can raise the lower bound to the nearest reachable residue.

These are established abstract domains:

- interval propagation maintains sound numeric ranges; [Apt and Zoeteweij](https://arxiv.org/abs/cs/0607016) analyze arithmetic constraints on integer intervals and equivalence-preserving propagation rules;
- affine arithmetic tracks shared noise symbols and therefore correlations that ordinary intervals forget; [Comba and Stolfi](https://www.inf.ufrgs.br/~comba/papers/1993/aa-93-09-sibgrapi-paper.pdf) introduced the method for self-validated range computation;
- congruence propagation records arithmetic progressions explicitly. [Berstel and Leconte](https://swt.informatik.uni-freiburg.de/staff/berstel/cstva06.pdf) add congruence domains to a finite-domain constraint solver and use coefficient gcd tests for integer linear constraints.

The solver's projected bound is a small reduced product of geometric and arithmetic facts. Its value is concrete: the interval gives magnitude, the affine form keeps cancellation information, and the residue rules out points that convex bounds admit. To preserve a certificate, each projection must over-approximate every suffix and each residue claim must follow from the transition arithmetic. Combining them by intersection is stronger than taking either bound alone, but only if that intersection is itself represented soundly.

## Producer-domain follow-up

The [correlated-domain implementation](PRODUCER.md) combines the affine-form and variable-elimination ideas above. For a linear consumer over an affine generated domain, its exact absolute-error support is the absolute center projection plus the sum of absolute generator projections weighted by their radii. This is the support-function calculation for a translated zonotope, not a new duality theorem.

Generator incidence supplies factor scopes for quantization assignment. Once no remaining block can change a projected error, that absolute-value term can be charged and removed from state. The resulting live-factor DP is a path-ordered variable-elimination algorithm. Its width depends on the chosen block order and projected numeric ranges; small rank alone does not guarantee a small state space.

The new repository work supplies vector-level Lean proofs, a source-derived paired gate/up instance, executable elimination and integer-replayed signed-L1 dual bounds. It also distinguishes a producer containment proof from a fitted domain: the tested Hadamard box excludes all five held-out captures even though the assignment optimum inside that box is certified.

## Candidate gaps worth testing

These are research opportunities, not literature novelty claims.

1. **Automatic extraction of consumer sufficient state.** Variable elimination, trellises, and weighted DDs assume that the factor scopes or transition state are already known. A tool that starts from a packed instruction-level consumer, derives the smallest useful exact residual state, and emits a proof of sufficiency would connect established theory to Kelana's setting.

2. **A certified assignment layer for executable codebooks.** Current LLM quantizers mostly return one heuristic assignment. For a frozen AQLM, lattice, vector-table, or trellis representation, an exact low-width solver and a width-bounded lower/upper solver would expose how much loss comes from assignment search rather than from the representation family.

3. **Cost-compensated approximate state reduction.** Exact residual equality is often too strict, while epsilon clustering is unsound and nontransitive. Lipschitz-paid dominance, quantitative simulation, and DD relaxations give ingredients for a safe directed reduction. The useful advance would be a joint interface that records the dominating witness, metric error budget, and retained global bound.

4. **Arithmetic-aware consumer lower bounds.** Mini-buckets and relaxed DDs are generic but may be weak on packed integer maps. Combining suffix intervals, affine correlations, and gcd or residue reachability can certify discrete unattainability that convex relaxations miss. The open engineering and mathematical question is which projections stay cheap enough to evaluate at every search state.

5. **Certified joint design.** Exact fixed-code assignment does not certify learned codebooks, transforms, layouts, or decoder programs. One possible architecture is an outer branch-and-bound or abstraction search over a finite executable family, with an exact or bounded assignment oracle inside. Continuous fine-tuning would remain a heuristic unless paired with a valid relaxation.

6. **Operational rate and execution in one objective.** Entropy-constrained quantization prices ideal average index length. LLM formats usually price fixed-width indices and amortized metadata. Kelana additionally cares about decoder instructions, register state, memory layout, and whether the next consumer accepts the labels directly. A solver that reports each of these rather than collapsing them into nominal bits per weight would answer a different and more operational question than classical ECVQ.

7. **One representation for a consumer family.** Functional coding usually fixes one function, while exact automata equivalence fixes a continuation language. A reusable packed representation may need to serve several future consumers with one labeling. The exact state is then the joint residual response to the whole continuation family, and its width may differ sharply from the state for one fixed suffix.

## Direct lookup computation from packed weights

[T-MAC](https://github.com/microsoft/T-MAC), whose repository introduction was read for this follow-up, explicitly targets mixed-precision matrix multiplication without dequantization by using lookup tables. It supports low-bit weight families including BitNet and publishes CPU inference results. That is direct prior art for preparing input-dependent response tables and consuming packed weight indices. Kelana should not present this idea as newly discovered.

The [direct-consumer follow-up](DIRECT.md) compares a base-three ternary implementation against the response-fiber format on the same real block. It proves the exact table semantics, prices table construction as well as lookup, and selects short chunk partitions under explicit payload-bit budgets. Its CPU block measurements do not inherit T-MAC's published model-level speedups.

## Enumerative coding and response-first layout

T. M. Cover's *Enumerative source encoding*, IEEE Transactions on Information Theory 19(1), 73–77, 1973, gives the classical count-and-rank view of lossless source coding. Partitioning ternary rows by a fixed integer dot response and ranking within each class uses that established machinery. The three-way suffix recurrence is exact counting dynamic programming. Dyadic slots and prefix-free descriptions likewise belong to ordinary prefix coding, not a new information-theoretic exemption.

Kelana's [fiber experiment](FIBER.md) supplies the executable consumer layout and its accounting. Largest-first rounded fiber slots make the useful response a readable prefix while retaining the exact original row at fixed width. The generic slot and ternary-rank proofs are in Lean. The implementation reports serialized bytes, the derived prefix index, count workspace, and miss-path work separately. The extension `dot(w,x) = alpha*dot(w,q) + dot(w,x-alpha*q)` lets a structured miss stop reconstruction when its residual suffix ends. The identity is elementary; its value here is the explicit decoding boundary. No literature-novelty claim is attached to these ingredients.

## Bottom line

Exact DP over a consumer-sufficient state and min-plus costs is established in several forms: Viterbi trellises, bucket elimination on low-treewidth factor graphs, nonserial dynamic programming, and weighted decision diagrams. Certified bounded-work search is also established through admissible frontier bounds, mini-bucket heuristics, and paired relaxed and restricted diagrams.

What is not supplied off the shelf is the consumer state and relaxation for packed executable quantization. Recent low-bit methods show useful representation families, but with the notable fixed-trellis exception they use heuristic assignment or joint design and do not report instance-level optimality gaps. The promising Kelana direction is to derive that state from the consumer, use exact DP where its width permits, retain lower and upper bounds when it does not, and count the actual representation and execution costs at the boundary.