# Indexed composition across a machine-state cut

An exact search can cut a straight-line program in half without cutting the *source network* in half. The cut carries its complete live machine state. Prefixes are functions from reachable inputs to that state; suffixes are functions from that state to the final observation. This is a finite-state meet-in-the-middle search with an inverted index on the prefix functions. Its useful feature is that a suffix can reject nearly every prefix by preimage constraints, without evaluating their Cartesian product.

This differs from the fixed additive-response menus in [the existing quantization mathematics](../../quantization-discovery/MATHEMATICS.md): candidates here are complete instruction compositions, and the state crossing the cut need not be any source tensor. It also differs from a fiber-only carrier search. The actual numeric state labels remain in the index because a following instruction observes those labels. Standard function-semigroup search and meet-in-the-middle are the mathematical ingredients; the result is a concrete way to compose them with an exact approximation budget, not a claim of novelty for either ingredient.

## Exact rule

Let `X` be a finite input set, `S` the complete cut-state set, `Y` the observed output set, and `F:X→Y` the target table. At a cut of a `d`-instruction program, store every distinct prefix map `h:X→S` of shortest length `floor(d/2)`, with one realizing word, and every distinct suffix map `g:S→Y` of shortest length `ceil(d/2)`. For each input `x`, a suffix permits precisely

```
h(x) ∈ g⁻¹(F(x)).
```

Index prefix IDs by `(x,s)` and intersect the postings for the permitted states. An empty intersection rejects *all* those prefixes. A surviving ID supplies an actual executable word `prefix ++ suffix`; check it against the full table. For Hamming error at most `k`, maintain bitsets of prefixes that mismatch at most `j` positions for `j=0..k`. On the next input, intersect the previous `j` set with its matching posting and union it with the previous `j-1` set intersected with the complement. This accounts for a **global**, rather than per-input, distortion budget. Other losses need their own accumulated loss state or an admissible lower bound; independently relaxing each input would not prove a global bound.

Search `d=0,1,...` until a match. This returns a shortest word: any length-`d` word splits at the cut. If either half has a shorter semantically identical word on the declared *full live-state domain*, replacement yields an equivalent whole word shorter than `d`; that word would already have been found. Thus looking only at minimum-length fragment representatives loses no first optimum. The same argument applies to a fixed whole-table error budget. All suffixes must accept the same live states as prefixes produce. If an op has side effects, flags, registers, placement, or static-dependent behavior, include those in `S` or in the interface tag. Restricting a suffix to some inputs without proving producer reachability is unsound.

The prefix search costs at most `O(|G|^⌈d/2⌉ |X|)` simple state evaluations for instruction alphabet `G`, plus suffix preimage/index work and bitset operations. It need not achieve this bound: semantic collisions reduce distinct functions, but weak preimage constraints or wide interfaces can leave many surviving pairs. Index construction uses `|X||H|` bits in the dense implementation here. An approximate loss with a large budget can make every prefix survive, restoring the Cartesian-product problem. Distinct representation charges, shared tables, or reusable consumers require more interface information and a richer costed search.

## Reproducible small search

Run `python3 research/isa-quantization/search-factorization/search.py` from the Kelana root; it needs only Python's standard library and takes under a second here. [`results.json`](results.json) is its output. The finite machine has one four-bit register, all 16 inputs, and six unit-cost operations: add one, xor five, rotate left, xor eight, xor with a one-bit left shift, and mask with seven. Arithmetic wraps at four bits. The target is given as its complete 16-entry output table, not as a mandated sequence of source steps. A fixed random seed supplies an eight-step witness on the fourth trial; a different eight-step word is returned. This is a planted *search workload*, not evidence that naturally trained networks often have such programs.

| Exhaustive contract | Result |
| --- | ---: |
| Exact shortest program for the 16-entry target | 8 instructions |
| Programs of lengths 0 through 8 without semantic deduplication | 2,015,539 |
| Stronger whole-map BFS control, unique transitions evaluated through depth 8 | 283,878 |
| Indexed half-search, unique transitions evaluated through depth 4 | 972 |
| Indexed half-search, exact bitset intersections through the optimum | 1,925 |
| Full prefix/suffix pairs inspected after filtering | 1 |

The work columns are *different units*, not a timing ratio. Each suffix still constructs preimages and posting unions for all 16 inputs, and big-integer intersections have nonconstant cost. The script executes a full whole-map BFS as a separate control, checking both depth optimality and the exact reachable-function counts. It also compares an independent non-deduplicating exhaustive search against the indexed result on a depth-five subproblem. The indexed solution does not require building the 135,205 unique depth-eight maps of the whole-map BFS.

Change one target output, from 10 to 11 at input zero. The changed table has **no exact program of length at most eight** in this grammar. Permitting a single mismatching input gives a shortest program of length eight, with 9,906 bitset intersections and one pair inspected. The exact best Hamming losses at minimum program depths 0 through 8 are `15,12,13,9,10,7,6,4,1`, independently obtained by the whole-map BFS. Thus the search chooses a cheaper executable *nearby map* instead of demanding that each source component be quantized. This is only a finite observed-domain Hamming contract. It does not estimate unseen inference error, model bytes, or native ISA time.

## What must cross a real cut

A static choice shared by both halves cannot be silently chosen twice. For example, if one stored bit `z` selects `h_z(x)=x xor z` and the continuation is `g_z(s)=s xor z`, every legal complete program is the identity. Joining `h_0` with `g_1` falsely invents negation. Carry the identity of `z` across the cut, or join by its tag; charge the stored bit or table once, not once per half. Likewise, two prefix maps with identical observed outputs cannot be merged if the suffix needs different register contents, live routing state, instruction constants, or memory addresses. A shared consumer across several outputs is one joint suffix on the complete state with its sharing cost, not independently minimized output programs whose costs are added.

The search here has no model-specific stored data, no preparatory cost, and no priced encoded input/output boundary. Its exact optimum is within this six-op, one-register grammar only. An arbitrary 16-entry nibble lookup is a legitimate competing representation and costs eight payload bytes plus indexing; this experiment does not price that reader or compare native implementations. Scaling the method needs separators with few *distinct reachable semantic functions*, compact admissible postings, and explicit tags for static dependencies. A broad register file or correlated shared choices can destroy the cut advantage; none of the fixed-menu DP results implies it will persist.
