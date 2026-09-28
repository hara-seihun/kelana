# Exact symmetries in a joint quantizer and program search

A representation can be renamed for free in a search only when the renaming transports **the quantizer, every available machine instruction, every live output port and their charges**. Equal fibers alone do not pass this test. Here a two-lane bit permutation does, and an exact numeric-state key gives a further no-worse-completion rule. The [search](search.py) exhausts a tiny example; [results](results.json) record the counts and frontiers.

This is a finite-machine structural result, not a claim about gfx1151 or a model's quality. It extends the [observer-search warning](../../discovery/observer-search/PLAN.md) about fiber keys into a priced joint search. The min-plus response-state reduction in [quantization mathematics](../../quantization-discovery/MATHEMATICS.md) already handles identical additive suffix states. Here the suffix is a machine program with representation-dependent transitions, so the key must include the exact reachable machine words. The group action itself is standard equivariant search, not a new mathematical theorem.

## A safe quotient

Let `X` be the declared producer-reachable input set. An object consists of a quantizer `E:X→S`, a program `P` of legal transitions on `S`, and an output observer `D_o:S→Y`. It has a static charge `b(E)`, an online charge `c(P)`, and endpoint loss `L(D_o P E,F)` against a fixed teacher `F`. The same argument applies to any loss of the complete endpoint map, including vector or distribution losses.

Suppose a bijection `g:S→S` acts on the allowed quantizers with `E^g=g E`, on each legal instruction `a` with a legal instruction `a^g=g a g⁻¹` of the same charge, and on each allowed observer with `D_o^g=D_o g⁻¹` of the same charge. The transformation must also transport model-specific constants, live registers and preparation charges if they exist. Then

```
D_o^g a_n^g ... a_1^g E^g = D_o a_n ... a_1 E
```

pointwise on `X`. Static charge, dynamic charge and endpoint loss agree, so keeping one representative per group orbit preserves the entire Pareto frontier, not merely its best scalarized objective. This is a statement about the *declared* machine grammar and cost model. An arbitrary permutation of numeric labels need not conjugate any ISA instruction to another legal, equally priced instruction.

For a partial program, write its exact reachable-state signature as `s=(s(x))_{x∈X}`, including every live register, lane and producer state that a continuation can read. At the same program stage and with the same allowed suffixes, `(s,b,c)` dominates `(s',b',c')` if `s'=g s` for an allowed cost-preserving automorphism and `b≤b'`, `c≤c'`. To complete `s`, conjugate any suffix of `s'` by `g⁻¹` and transport its observer. Induction over the suffix gives an identical final map at no greater static or online charge. A stage with fewer instructions also dominates a later identical state under an *at-most* instruction budget, provided its costs are no greater. For a prescribed exact length, different remaining lengths must stay in the key. The same rule works for a vector of paid resources with componentwise inequalities.

This is a constructive no-worse-completion relation. In a search with shared codebooks, scales, liveness or consumer restrictions, those facts belong in the state and in the group action; a response vector by itself is not enough. Approximate agreement is not used as a hash key. For example, `0000`, `0001`, `0011` as four-input outputs have consecutive Hamming distances one, but the first and last have distance two. Thresholding at one cannot define a transitive quotient. A paid directed error bound can instead justify dominance if it covers *every* legal continuation and its charge, as in the quantization mathematics note.

## Finite experiment

Take `X={00,01,10,11}` and two bit lanes. A quantizer chooses for each lane one of `0`, input bit `x0`, input bit `x1`; there are `3²=9` ordered choices, including lossy and injective maps. Its illustrative static charge is the number of nonzero feature references, `0..2`. A sparse list of active `(lane,feature)` records would use two payload bits per reference plus a common header. The producer's two input bits and any actual wiring cost are outside this toy charge and must be added for a native comparison. No scalar weight alphabet is assumed.

There are six unit-charge bit instructions: `xor_i` flips lane `i`, `mix_i` replaces lane `i` with its XOR with the other lane, and `meet_i` replaces it with its AND with the other lane. All other bits remain intact. Programs have at most three instructions. The observer selects either output lane at zero toy charge. Swapping the two lanes transforms every quantizer, instruction `kind_i→kind_(1-i)`, and output port `i→1-i`. This is a genuine grammar automorphism. The endpoint Boolean teacher is unchanged.

| Enumerated quantity | Count |
| --- | ---: |
| Labeled quantizer/program/port objects, depths 0 through 3 | 4,662 |
| Orbits under simultaneous lane swap | 2,331 |
| Live exact numeric state keys after charged dominance, by depth | 6, 15, 27, 35 |
| Total live numeric labels across depths, before choosing a port | 83 |

Each object has a distinct partner under swap because the output port changes. The last two rows count partial semantic states, not complete programs, so `83` is not a runtime speedup factor over `4,662`. The search independently computes frontiers from raw enumeration, one representative per orbit, and exact-state dynamic programming. It compares all three for **all 16** Boolean teacher maps on `X`. The script's assertions are exhaustive for this declared domain and grammar.

The reported triples are `(active feature references, instructions, mismatched inputs)`:

| Teacher in input order `00,01,10,11` | Nondominated triples |
| --- | --- |
| parity `0,1,1,0` | `(0,0,2)`, `(2,1,0)` |
| conjunction `0,0,0,1` | `(0,0,1)`, `(2,1,0)` |
| disjunction `0,1,1,1` | `(0,0,3)`, `(0,1,1)`, `(1,0,1)` |

Parity's exact point uses both input features and one `mix` instruction. Conjunction's uses one `meet`. Under this three-instruction budget, disjunction is not exact in the grammar. A conventional direct four-bit truth table plus an indexed lookup realizes **every** teacher exactly, including disjunction; charge its table, address formation, lookup, and access pattern before making any execution claim. Fixed two-feature quantization with the same one-instruction parity/AND programs is also an exact control. There is no claimed advantage over either baseline.

## Why the conditions matter

`E(x)=(x0,0)` and `E'(x)=(0,x0)` have identical input fibers. If the observer is forced to read lane 0, the first needs zero instructions to output `x0`, while the second needs `mix_0` to copy `x0` across at cost one. Treating the swapped quantizers as equivalent would underprice the second. Our quotient works because it swaps the **chosen output port too**; it fails if lane 0 is a fixed physical boundary or if lane-specific instructions/ports have unequal prices.

Even injective equal-fiber carriers can have different continuation costs: `E(x)=(x0,x1)` outputs `x0` at lane 0 without work, whereas `(¬x0,x1)` needs `xor_0` first. The second carrier is a legal intermediate machine state, even though it is not one of the nine initial quantizers. Injectivity says nothing about the cheapest next instruction.

The script models exact Boolean operations on four inputs. It does not prove these costs for packed model data, machine bytes, instruction throughput, or unseen inputs. To use the reduction on a larger packed region, first enumerate or prove automorphisms of its *priced* instruction and boundary grammar; then hash complete reachable machine states modulo only those automorphisms. Approximation remains a terminal objective or a separately proved directed dominance rule, not an equality relation.

Run from the Kelana root with `python3 research/isa-quantization/search-symmetries/search.py`. Python's standard library is the only dependency. Output is deterministic and matches `results.json`.
