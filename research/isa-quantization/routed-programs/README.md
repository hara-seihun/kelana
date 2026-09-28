# Fold a routed nonlinear sum into conditional coefficients

A routed sum need not store an independently readable program for each expert. If routing partitions the input into cells where each selected ReLU gate keeps its sign, the *sum on a cell* is a polynomial, even when the experts are nonlinear across the full input domain. Store those conditional coefficients and evaluate one polynomial after routing. The input coordinate and route predicate are retained; no individual expert output crosses this boundary.

This is a route-restricted operator construction, not a shared linear output basis or a dictionary of equal expert bytes. The closest existing [routed-sums experiment](../../ternary-toys/routed-sums/README.md) jointly fits ternary expert codes under quantized-producer routes, but still evaluates every selected expert. [Exact-route rank](../../moe/exact-route-rank/README.md) excludes a narrow common *linear* down basis for unrestricted hidden vectors, not this conditional nonlinear map. [Code sharing](../../moe/code-sharing/README.md) finds little unchanged-byte reuse in real banks; this construction needs no unchanged bytes. The present example is constructed, not evidence that real Qwen routes have the needed sign-stable cells.

## Conditional folding rule

Let a route cell `C_r` select experts `S_r` with fixed rational scores `alpha_{r,e}`. Suppose expert `e` has output `d_e ReLU(g_e x+b_e)(u_e x+c_e)`, and `g_e x+b_e` is either nonnegative throughout `C_r` or nonpositive throughout `C_r`. Define `sigma_{r,e}` as one or zero accordingly. Then on that cell the whole output is

```
F_r(x) = A_r x² + B_r x + C_r
A_r = sum_e alpha_{r,e} d_e sigma_{r,e} g_e u_e
B_r = sum_e alpha_{r,e} d_e sigma_{r,e} (g_e c_e + b_e u_e)
C_r = sum_e alpha_{r,e} d_e sigma_{r,e} b_e c_e.
```

This is a polynomial identity, so it also holds off the sampled integer points as long as the gate signs and route remain fixed. A polynomial branch can replace the expert evaluations without decoding their intermediate values. Affine route scores instead raise the degree to at most three. A gate changing sign *within* a cell requires another cell or a different program. For vector inputs the quadratic coefficient is a matrix; storing it can cost more than the original experts. Neither byte nor instruction advantage follows from this identity alone.

## Exact fifteen-input witness and paid controls

The input is one signed integer `x` in `[-7,7]`. The router selects `(1,2)` for `x<0` and `(0,1)` otherwise, with normalized scores `1/2,1/2`. All three experts share down gain `d=2`, so the final sum is `expert_i(x)+expert_j(x)` with `expert(g,b,u,c)=ReLU(g*x+b)*(u*x+c)`. The three four-byte signed coefficient tuples are `(1,8,3,-2)`, `(2,1,-1,3)`, and `(-1,8,2,1)`. Their individual gate signs are constant on the cells where they are selected. Expert 1 vanishes on the negative cell but contributes on the nonnegative cell.

The complete sum is `-2*x²+15*x+8` for `x<0`, and `x²+27*x-13` otherwise. All six coefficients fit signed bytes. An implementation can select three coefficients using the route predicate, square `x` once, and use two integer multiply-adds; a compare and three selects are also online work. On this domain the result fits signed 32 bits, as do all intermediate products and Horner evaluations. The table of fifteen signed 16-bit outputs alone costs 30 bytes, without addressing or routing, so it is not the comparison that makes the result look good.

The accounting counts *model-specific* constants even when embedded in instructions. Router metadata is one threshold byte plus four expert-ID bytes in all arms, including the folded arm although it no longer needs IDs for this output. The source needs twelve expert coefficient bytes and one shared down-gain byte, totaling **18 bytes with router**. The folded program needs six coefficient bytes, totaling **11 bytes with router**. No output lookup, hidden scale, or per-input prepared table is free. The 2-bit-trit control stores twelve trits in three bytes. One shared signed-byte magnitude for all experts, the same down gain and router cost **10 bytes**. Allowing a different magnitude for each expert costs **12 bytes**. Both controls search magnitude 1 through 8 and *jointly* fit the complete routed sum, not separate expert reconstructions; the 12-byte control attains squared error 620 on all fifteen inputs, while the 10-byte control has error 2164. The folded program is exact at eleven bytes. An independently fitted three-scale control has error 3871. These are integer response sums of squares, not language-model loss. The exhaustive joint search exploits that, conditional on shared expert 1's code, experts 0 and 2 optimize independently on their disjoint route cells; it does not approximate the `8*81` possibilities per expert.

There is no unstructured prevalence claim. Of 500 seeded random three-expert teachers with each coefficient drawn uniformly from `[-8,8]`, 86 have exactly quadratic responses on both finite route cells and 85 also have signed-byte coefficients. The first failure has a gate breakpoint within the negative cell: its seven responses there are `-120,-102,-84,-66,-48,-30,-30`, not a quadratic sequence. Finite-point polynomial coincidences in this census do not certify stable signs between points. The construction is appealing only if routing and activation geometry produce these cells cheaply and often enough.

`experiment.py` recomputes the witness, checks every response, enumerates both joint trit controls, and generates the fixed-seed counterpanel. `results.json` records coefficients, all fifteen responses, selected code tuples, errors and the first counterexample. Run from the Kelana root:

```sh
OPENBLAS_NUM_THREADS=1 python3 research/isa-quantization/routed-programs/experiment.py > research/isa-quantization/routed-programs/results.json
```

This establishes exact integer semantics on the stated domain and an algebraic extension within the fixed-sign cells. It does not establish an emitted ISA program, timing, a real MoE rate advantage, quantized-producer route stability, or the behavior of a downstream consumer needing individual expert outputs. For real transfer, inspect the actual quantized router's cells and selected gate signs, price coefficient growth with vector dimension, then compare complete routed outputs against independently and jointly fitted packed expert controls on held text.
