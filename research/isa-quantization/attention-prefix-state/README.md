# Normalized current outputs are not the online attention state

A complete attention consumer may need only `pV`, not its probability vector. That does **not** mean its present output is a sufficient state for the next insertion. This study characterizes that distinction for a positive, stationary, queryable-prefix kernel. It permits direct online response programs without retaining individual K/V vectors, and identifies the exact statistic they must preserve under its contract.

## Contract and continuation theorem

Let `T` be a finite insert alphabet, `Q` a set of permitted queries, `k(q,t)>0`, and `v(t)` a finite-dimensional value. A prefix is a nonempty nonnegative weighted histogram `c`; ordinary token streams have integer counts. Define

```
Z_q(c) = sum_t c_t k(q,t),
N_q(c) = sum_t c_t k(q,t) v(t),
y_q(c) = N_q(c) / Z_q(c).
```

Insertion adds a histogram, and a query does not mutate it. All tokens may be appended repeatedly; queries are permitted at each such boundary. This is a **declared stationary positive-kernel grammar**, not the entire Qwen causal/RoPE interface. Query/key weights depending on prefix order, absolute position or candidate history need a larger state/update definition. Zero or masked weights require a query-specific reachable-probe argument. Here values do not depend on the query; the same proof allows fixed `v(q,t)` provided each query's nonconstant values are identified.

For any query with at least two distinct values, prefixes `c,c'` have identical outputs now and after **every** continuation iff

```
Z_q(c)=Z_q(c') and N_q(c)=N_q(c').                     (1)
```

Only the empty continuation and two single-token probes with distinct values are needed for necessity. Current equality gives a common vector `y=N/Z=N'/Z'`. On appending weight `a>0` and value `v`,

```
(N+a v)/(Z+a) - (N'+a v)/(Z'+a)
  = a (Z-Z') (y-v) / ((Z+a)(Z'+a)).                 (2)
```

If `Z != Z'`, equality after every probe would require every legal value to equal `y`, contrary to the two distinct values. Thus `Z=Z'`, and current equality gives `N=N'`. Conversely equal moments remain equal after every additive continuation. A distinguishing value coordinate proves the vector case. Queries whose legal values are all the same have constant output and require **no** prefix moments; including their denominator in a lower bound would be wrong.

`Kelana/AttentionContinuation.lean` supplies the arbitrary-rational scalar algebra: current/probe cross-products imply both moments equal, the probe-list consequence, preservation through arbitrary additive continuations, and the constant-value exception. It does not formalize exponentials, vector lifting or the linear-rank theorem below.

A quantitative form of (2) is also useful. If two prefixes on the same current-output ray are merged to one deterministic state, their updated outputs after a common probe differ by the right side of (2). Any reader from that one state has worst-case norm error at least **half** that separation, by the triangle inequality. This is a future-output bound, not a probability-KL requirement. It vanishes for probes with `v=y`, and may be small for large masses; exact distinguishability alone is not a useful approximation lower bound at every horizon.

## A quantitative all-state-count obstruction, not just exact injectivity

Uniform positive attention over token values0/1 computes their running mean. Let a deterministic candidate have **C total reachable states**, with output determined by its state. All persistent information, including a position counter, control state and stored scale, counts toward C. For every integer `s>=2`, some nonempty word of length at most `(s²+s+1)C` has absolute output error at least

```
(s-1)/(2(s+1)).                                        (3)
```

To prove it, inspect zero-only prefixes at lengths1 through C+1. Two states repeat, at lengths `n` and `n+d` with `1<=n<=C` and `1<=d<=C`. The zero transition repeats that cycle, so every prefix length `n+jd` has the same state. Choose such an `m` with `s²C<=m<(s²+1)C`, and append the **same sC one-tokens** to both prefixes. The candidate's final states and outputs are identical. The teacher outputs are `sC/(n+sC)>=s/(s+1)` and `sC/(m+sC)<=1/(s+1)`, separated by at least `(s-1)/(s+1)`. The triangle inequality proves (3). No transition-table enumeration or chosen readout is needed for this theorem.

Consequently, for every fixed uniform error target below1/2 on words of length at most N, the required deterministic state count is **Omega(N)**, with the explicit constant obtained by selecting an integer s for which (3) exceeds the target. Required fixed-width state bits are at least `log2 N-O(1)`. For example, error strictly below1/6 requires `C>N/7`. On unbounded words the minimax worst-case error of every finite-state deterministic reader is at least1/2, attained by the constant1/2 reader. A free unbounded position counter, randomized expected-error objective, fixed finite distribution or restricted continuation language changes the premise. This is not a practical huge-precision register lower bound for a256-token model run; it rules out treating mass as disposable merely because the present normalized output is small.

`capacity.py` constructs the two distinguishing words for every one of the729 three-state binary transition tables at `s=2`, checking exact rational teacher outputs, common final state and the horizon bound. That finite replay is an illustration of the all-C proof, not its basis. `Kelana/AttentionStateCapacity.lean` proves the full all-C construction for positive C and integer s>=2: unary cycle, repeated prefix, equal state after the common suffix, rational mean gap and disjunctive absolute-error floor for **arbitrary rational state readout**, with both lengths at most `(s²+s+1)C`. Its endpoint bound allows `m<=s²C+C`, which suffices for the same horizon; the ceiling construction in the paper/code gives the strict version. Real readouts and the interpretation of physical state bits are external, not silently supplied by Lean.

## Minimal linear statistic, not a bit-count slogan

Form a matrix `A` with rows `k(q,.)` and `k(q,.) v_j(.)` for each nonconstant query and each value coordinate `j`. Equal `Ac` is precisely equality through every query and continuation. Hence the exact quotient is the reachable image of this **joint numerator/denominator matrix**, not merely the rank of the score or kernel matrix. Its row space is

```
S + sum_j S * v_j,       S = span{ k(q,.) : nonconstant q },
```

where `*` is coordinatewise multiplication. Value co-design can therefore change the required online representation even when score/kernel rank is fixed. If `S` is a pointwise algebra and each `v_j` lies in it, products stay in `S`; if not, numerator closure can enlarge the state. This connects to the existing closure-algebra studies without assuming their binary/XOR source domain here.

Consider a linear additive encoder `Rc`, followed by an arbitrary decoder. For all positive **real-weighted** prefixes, exact continued observation is possible iff `ker R` is contained in `ker A`. Necessity: for any `h` in `ker R`, choose a sufficiently large positive base `b` so both `b` and `b+h` are legal; their encoded states coincide, and (1) gives `Ah=0`. Sufficiency follows by a well-defined linear map from `im R` to `im A`, then ordinary ratio readout. Thus the minimum number of real linear coordinates is **rank A**; a row basis attains it.

The same conclusion holds for unbounded integer-count prefixes when **R has rational entries**: its kernel has a rational basis, and clearing denominators yields integer differences between legal positive histograms. This qualification is essential. With arbitrary exact real coefficients, a scalar `sum c_t alpha_t` with rationally independent `alpha_t` can inject every integer histogram and admit an arbitrary decoder; one formal real is not one machine word. For a bounded integer domain even rational radix packing can inject all states into one large integer. Therefore rank is **not** a lower bound on bits, registers of arbitrary width, or all finite-program encodings.

If existing live metadata already supplies linear statistics `Bc` (for example the token count), it is part of the state. The least additional linear coordinate count becomes `rank([A;B])-rank(B)`, not rank A charged again. All comparisons below pay their counters and stored widths explicitly.

A family-wide contrast shows what approximation can buy. For `m` distinct positive numbers `a_t` and queries `i=0,...,m-1`, the softmax-compatible kernel `k(i,t)=a_t^i=exp(i log a_t)` is a Vandermonde matrix of rank m. With at least two distinct values, every query is nonconstant, so exact rational additive prefix coordinates require m dimensions on the stated domain. A changed positive kernel `k(q,t)=1+q t` with scalar `v=t` instead needs only the three moments `sum c`, `sum c t`, `sum c t²`, however many distinct t are present. This is the familiar linear-attention mechanism, **not a novel attention algorithm**; the contribution here is its exact continuation quotient, joint-value closure criterion and accounting boundary. It does not establish that replacing the exponential gives small error on a trained model.

## Paid finite witness and stronger controls

The runnable witness fixes four token labels with stored values `t=(0,1,2,3)`, two queries `q=(0,1)`, `k(q,t)=1+q t`, and maximum prefix length15. All positive weights and values are small integers; returned values are exact rationals. The full teacher stores eight kernel bytes plus four value bytes and a format tag (**13 bytes**). The moment image stores four token-coordinate bytes, two query-coordinate bytes and a format tag (**7 bytes**). These are actual files consumed by separate readers. Both require their generic reader code, not priced as zero; this experiment does not compile or time it.

The moment program carries `(m0,m1,m2)=(sum c,sum c t,sum c t²)` as three unsigned bytes under this horizon (`m2<=135`), updates by `(1,t,t²)`, and returns

```
(m1+q*m2)/(m0+q*m1).
```

It never reconstructs a sequence of K/V vectors or an attention probability array. A complete four-token histogram control also serves every query exactly. Four separate byte counters would cost four bytes, but that is not the strongest control: **four packed nibbles occupy two bytes**, less than the three-byte moment state. On the reachable length bound, insertion is a single integer addition `packed += 1 << (4*token)` without cross-field carry. The independent replay checks every legal such update. The histogram can also use the same seven-byte coordinate image, computing its kernel from those coordinates rather than storing the larger literal table. Thus fewer linear coordinates do **not** win physical bytes or update work on this instance. A packed two-bit token cache carries four bytes plus a one-byte length at capacity15 and scans its live tokens on each query. A current-output-only code loses continuation: prefixes `(one0,one1)` and twice that prefix share both current outputs, but appending token2 separates query0 outputs by1/5 and query1 outputs by2/9. The worst-case next-output error of any merged state is consequently at least1/10 and1/9 respectively.

There are also genuine exact moment collisions: histograms `(1,0,3,0)` and `(0,3,0,1)` both have moments `(4,6,12)`, and remain observationally identical after every common append. This eliminates distinctions among token labels because no declared continuation uses them. The kernel matrix alone has rank2, but the joint moment matrix has rank3; retaining only two kernel accumulators loses the second-moment numerator. The witness independently compares actual serialized images/states with the full kernel/value reader on **all nonempty histograms up to length15**, and every legal one-token update. No training or held-panel selection is involved.

This tiny source is deliberately structured. The packed histogram already beats the moment layout's live bytes at this horizon. At a general horizon L, independent histogram fields need `4 ceil(log2(L+1))` bits while moment fields need `ceil(log2(L+1))+ceil(log2(3L+1))+ceil(log2(9L+1))`; this changes the eventual description scaling, not the measured finite point. Generic code and operand metadata also matter, and the compact histogram shares the seven-byte source description. The experiment supplies a complete online quotient and a stated finite error obstruction, not a native speedup, a model BPW result, or evidence that real rotary attention has this kernel. A useful approximate program must now choose a cheap kernel/value closure and price its error at the actual continued output, rather than optimize raw Q/K or insist on exact probability preservation.

```sh
python3 research/isa-quantization/attention-prefix-state/witness.py
python3 research/isa-quantization/attention-prefix-state/capacity.py
lake env lean Kelana/AttentionContinuation.lean
lake build Kelana.AttentionStateCapacity
```
