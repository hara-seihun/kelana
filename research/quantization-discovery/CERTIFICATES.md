# Anytime search certificates

`Kelana/QuantizationCertificates.lean` gives branch-and-bound searches a small proof boundary. A search may stop after any bounded amount of work and return a lower bound together with the cost of a feasible incumbent. The candidate type may be infinite. Only the frontier certificate is finite: it stores lists of examined candidates and remaining regions.

## Model

`Problem Candidate` has two fields:

```lean
feasible  : Candidate → Prop
objective : Candidate → Nat
```

The search owns the objective definition. For quantization discovery, it can be the sum of storage, priced online work, and consumer distortion. This module does not assign prices or equate unlike units.

`RegionBounds p Region` supplies:

```lean
contains : Region → Candidate → Prop
lower    : Region → Nat
sound    : ∀ r c, p.feasible c → contains r c → lower r ≤ p.objective c
```

This is the local branch-and-bound obligation. A region bound may come from a relaxation, a dynamic program, exhaustive work inside the region, or a dominance proof. It does not assume the desired global lower bound.

`Frontier p bounds` records finite lists named `explored` and `unresolved`. Its `cover` field proves that every feasible candidate is either in `explored` or belongs to an unresolved region. Candidate finiteness and candidate enumeration are not required.

`Certificate p bounds` adds:

* a feasible `Incumbent p`;
* an advertised `lower`;
* a pointwise proof that each feasible explored candidate costs at least `lower`;
* a proof that each unresolved region's sound lower bound is at least `lower`.

These fields are enough to check a stopped search without replaying its search order.

## Theorems and updates

The main API is:

```lean
Certificate.globalLower
Certificate.globalInterval
Certificate.optimalOfBoundsMeet
Certificate.safePrune
Certificate.improve
Certificate.refine
Certificate.raiseLower
lowerThroughRepresentative
RegionBounds.ofRepresentatives
```

`globalLower` derives `cert.lower ≤ p.objective c` for every feasible candidate by splitting on the frontier cover. `globalInterval` pairs that result with the feasible incumbent. Its endpoints are `cert.lower` and `p.objective cert.incumbent.candidate`.

`optimalOfBoundsMeet` proves the incumbent minimizes the objective when those endpoints agree. `safePrune` proves that a region cannot contain a strictly better feasible candidate when its region lower bound reaches the incumbent cost.

`improve` installs a no-worse feasible incumbent without changing the lower-bound evidence. `refine` replaces one region with newly examined candidates and child regions. The caller proves that those replacements cover every feasible candidate previously in the parent and that each new leaf meets the current floor. `raiseLower` changes the lower endpoint after the caller supplies stronger pointwise and per-region evidence.

## Dominance and simulation cover

A dominance result need not identify a covered candidate with its representative. `lowerThroughRepresentative` transports

```lean
L ≤ objective representative
objective representative ≤ objective candidate
```

into `L ≤ objective candidate`.

`RegionBounds.ofRepresentatives` packages the same argument for every candidate in a region. Its representative function may depend on the candidate. This fits prefix-state dominance: for each completion under a discarded prefix, supply the no-worse completion under its representative prefix. The resulting `RegionBounds.sound` proof lets the ordinary frontier cover account for the entire discarded region. The certificate module therefore needs literal coverage of candidates by regions, but not equality between a candidate and the witness used to bound it.

A pruned region should remain as a bounded leaf in a proof-producing run. The algorithm may stop expanding it, while the certificate keeps the region and its lower-bound proof so that global coverage remains explicit.

## Checker boundary

The module proves no fact about a particular encoding, instruction sequence, hardware price, distortion measure, or dominance relation. Those are dependencies supplied through `Problem.feasible`, `Problem.objective`, `RegionBounds.sound`, and `Frontier.cover`. In particular, a feasible point of a relaxation is not an incumbent unless it is also a feasible `Candidate`.

The module imports `Std` only. Its printed core theorems contain no axioms. It is intentionally not in the aggregate import yet; integration can add it together with the search algorithm and objective definitions.
