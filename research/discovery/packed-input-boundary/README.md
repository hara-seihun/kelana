# A five-bit affine address cannot carry three packed trits

The universal wave-gather observer in [whole-map-search](../whole-map-search/README.md) needs an address that distinguishes all 27 input triples before it reads a table lane. Its one-instruction address uses an input already prepared as scaled radix-3; its two-instruction byte route uses signed byte lanes. The `packed2` contract instead puts signed two-bit codes `0,1,3` at bit positions `0,2,4`. Can that six-bit word be compressed into the five lane-selector bits by wiring and XOR alone?

No. Let `S = {a+4b+16c : a,b,c in {0,1,3}}`, a set of 27 words in `F₂⁶`. [`Kelana/PackedInputBoundary.lean`](../../../Kelana/PackedInputBoundary.lean) proves by complete finite reduction that

```
{u xor v : u,v in S, u != v} = F₂⁶ \ {0}.
```

Any bit-affine map `A : F₂⁶ -> F₂⁵` has a nonzero kernel vector `d`: six input dimensions cannot fit injectively into five output dimensions. The checked difference result supplies `u,v in S` with `u xor v = d`, so `A(u)=A(v)`. XOR with a constant changes neither collision. This rejects *every* five-bit affine relabeling, not merely the familiar layout that drops one bit. A sequence of XORs, bit permutations, fixed shifts and ANDs by constant masks remains bit-affine and cannot yield a universal five-bit lane address from `packed2`. It also rejects a prepared arbitrary linear matrix over bits even if its cost is declared free.

The Lean statement has six existential trit indices for each of the 63 nonzero differences. `lake env lean Kelana/PackedInputBoundary.lean` checks it in this repository; no sampled inputs, native floating arithmetic, or GPU measurement enter the proof. The dimension step is elementary linear algebra over `F₂`: six columns in a five-row matrix are dependent. Its scope is an **injective** address for arbitrary 27-state observers. A fixed map with fewer fibers may survive a collision, and a nonlinear address can evade the bound. `whole-map-search` already rules out a different family, one multiply by a constant before the gather. Neither negative rules out a short composition of nonlinear instructions.

This changes the next native search. Do not spend a sweep on more fixed bit permutations or affine XOR masks to close the `packed2` to wave-gather gap. Search a nonlinear mixer that separates the 27 words, then count its data instructions, table materialization, `lgkmcnt` wait, enabled lanes, and register lifetime against the byte and pre-scaled routes. A candidate index must be checked on all 27 inputs *before* the lookup; merely obtaining the right output for one non-injective network is weaker.
