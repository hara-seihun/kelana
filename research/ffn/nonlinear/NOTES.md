# Paired ternary gate/up networks under the SiLU reflection identity

Working notes for the question: what exactly can be saved in `z_i = SiLU(g_i(x)) * u_i(x)`
followed by a linear consumer, by exploiting the fact that gate and up read the same `x`.

Everything below is real arithmetic. `SiLU(t) - SiLU(-t) = t` is an identity over the reals.
It is not a claim about FP32 rounding on gfx1151, and it is not commuted through the
sign/Hadamard/quantisation stage that follows the hidden vector.

## Setting

One layer, one token. `x` is the post-norm, post-Hadamard, post-quantisation activation
vector, `D = 5120`. Gate and up rows are ternary with one fp16 scale per 128-element block,
so a row acts as the linear functional

    g_i(x) = sum_b s_{i,b} * <G_{i,b}, x_b>,    G_{i,b} in {-1,0,1}^128.

`FF = 17408` hidden units, `z_i = SiLU(g_i) * u_i`, consumer `y_m = sum_i C_{m,i} z_i`
(the down projection; the sign/Hadamard between them is linear and can be absorbed into `C`
for the algebra, though not for the quantisation that follows).

Write `sigma` for the logistic function, `SiLU(t) = t*sigma(t)`.

## The identity and what it forces

    SiLU(t) - SiLU(-t) = t*(sigma(t) + sigma(-t)) = t                       (R)
    SiLU(t) = t/2 + E(t),   E(t) = (t/2)*tanh(t/2) even, E(t) = E(-t)       (E)

(R) says one thing operationally: **a sign flip of a gate row costs one subtraction, not a
second nonlinear evaluation.** If you have `s = SiLU(g)` then `SiLU(-g) = s - g`, and `g` is
already in a register; one subtract per class serves every negated member of it.

### Theorem 1 (class collapse)

Let `S` be a set of hidden units whose gate rows agree up to one whole-row sign:
`G_i = eps_i * G` with `eps_i` in `{+1,-1}`, equal scale vectors. Then for any up rows and
any consumer row `c`,

    sum_{i in S} c_i * SiLU(eps_i * g) * u_i
        = SiLU(g) * <A_S, x>  -  g * <B_S, x>
    A_S = sum_{i in S} c_i U_i           (all members, sign-independent)
    B_S = sum_{i in S, eps_i = -1} c_i U_i

Proof: substitute `SiLU(-g) = SiLU(g) - g` in the negated members and collect. Checked in
Lean over `Int` with `s` an abstract function satisfying (R): `Kelana/GateClass.lean`,
theorem `collapse`. Checked numerically for a 5-member class with unlike up rows and random
consumer coefficients in `paired_ffn.py` section 1.

Three corollaries, in increasing strength of the weight condition required.

**C1 — shared gate (condition on `G` only).** A class of size `k` needs one gate dot product
and one SiLU instead of `k` of each, plus one subtract for the whole class: the two scalars
`s` and `s - g` are all any member needs. The up rows, consumer and hidden dimension are
untouched, so this is output-independent and composes with anything downstream. Saving:
`(k-1)*D` MACs and `k-1` exponentials per class.

**C2 — residue-free class (condition on `G`, `U` and `C`).** If `A_S = 0` *as a row*, i.e.
`sum_{i in S} C_{:,i} (x) U_i = 0` as an outer-product identity over all consumer rows, the
nonlinear path disappears entirely and the class contributes

    - g * <B_S, x>,

a product of two linear forms. No SiLU, and the class' members collapse to `|S_-|` products.
For `|S| = 2` the condition forces `C_{:,j} = -lambda C_{:,i}` and `U_j = lambda^{-1} U_i`.
For `|S| = 3` it admits genuinely different ternary up rows: `U_3 = U_1 + U_2` with disjoint
supports (so `U_3` stays ternary), coefficients `(1, 1, -1)`, signs `(+, -, +)` gives
`A_S = 0` and output `-g*<U_2,x>`. Verified in `paired_ffn.py` section 1.

**C3 — duplicate merge.** Units with identical gate rows (`eps` all `+1`) and proportional
consumer columns `C_{:,j} = lambda C_{:,i}` merge into a single unit with up row
`U_i + lambda U_j`; the hidden dimension drops by one. Lean: `duplicate_merge`.

### Case table

| gate relation | up rows | consumer | what survives |
|---|---|---|---|
| `G_j = G_i` | any | any | 1 dot + 1 SiLU for both units (C1) |
| `G_j = -G_i` | any | any | 1 dot + 1 SiLU + 1 subtract (C1) |
| `G_j = -G_i` | `U_j = U_i` | `C_{:,j} = -C_{:,i}` | `g*u`, no SiLU, one unit (C2) |
| `G_j = G_i` | any | `C_{:,j} = lambda C_{:,i}` | one merged unit (C3) |
| `U_i = ±G_i` | — | any | unit is `±g*SiLU(g)`: one dot instead of two |
| `U_j = ±G_i` (cross) | — | any | one dot feeds both matvecs |
| `G_j = lambda G_i`, `lambda != ±1` | any | any | no saving via this rewrite (Theorem 2) |
| `G_j = G_i` on some 128-blocks, `-G_i` on others | any | any | no saving via this rewrite (not a whole-row sign) |
| `G_j = P G_i`, `P` a permutation | any | any | no saving via this rewrite for a shared `x` |

The per-block case matters in practice because the halo layout is blockwise: a row that is
the negation of another *within each block but not globally* gives
`g_j = sum_b eps_b s_b <G_b, x_b>`, which is not `±g_i`. Measured residual in
`paired_ffn.py` section 3.

The permutation case is not exploitable against a shared `x`: `<P G_i, x> = <G_i, P^T x>`
needs a permuted copy of the activation. It becomes interesting only if the permutations
form a group whose correlation is a fast transform; see "leads not taken".

### Even/odd decomposition, when no exact duplicates exist

(E) splits the whole FFN exactly:

    z = (1/2)*(Gx) ⊙ (Ux)  +  E(Gx) ⊙ (Ux)

the first term a pure quadratic map of `x` (per output, `x^T M_m x / 2` with
`M_m = sum_i C_{m,i} G_i^T U_i`), the second depending on `|g_i|` only.

This is a usable *canonical form* and gives the cheap sign flip, but it is not a generic
saving. `E` has exactly the poles of `SiLU` (`E = SiLU - t/2` and `t/2` is entire), so
Theorem 2 applies to it unchanged (same pole families, same residues, same model (M)):
replacing `SiLU` by `E` does not reduce the transcendental count. What it does buy:

- dedup and pairing only ever need equality **up to sign**, doubling the collision space;
- the quadratic skeleton is available exactly and cheaply if an approximate path is ever
  wanted (`|E(t)| <= |t|/2`, `E(t) -> |t|/2` quickly), which is an approximation question,
  not an exact rewrite.

## Theorem 2 (the limit of this rewrite): the residue invariant

`sigma` has simple poles at `t = i*pi*(2k+1)` with residue 1, so `SiLU` has simple poles
there with residue `i*pi*(2k+1)`. Extend the network to complex `x`. Along the hyperplane
`H_{S,k} = {<G_S,x> = i*pi*(2k+1)}`,

    Res(class S contribution) = i*pi*(2k+1) * <A_S, x>
    A_S = sum_{i: G_i = ±G_S} C_{:,i} U_i

and both signs contribute the *same* residue, because `SiLU(-g) = SiLU(g) - g` and `g` is
entire. This is why a `±` class shares one pole family, and why `A_S` — the coefficient of
the surviving nonlinear term in Theorem 1 — is exactly the residue. Verified numerically
(`paired_ffn.py` section 4): `delta * y` converges to `i*pi*<A_S,x>` as `delta -> 0`.

### What the residue bounds, and under which hypotheses

Three different objects have to be kept apart.

- A **class** `S`: units whose gate functionals are equal up to a single global sign,
  `G_i = eps_i G_S`. This is what Theorem 1 collapses.
- A **pole family** `F_S = {<G_S,x> in i*pi*(2k+1)}`: one class occupies exactly one family.
- A **projective direction** `[G_S]`: several classes can share one. `G` and `2G` are
  different classes with different families (`i*pi(2k+1)` against `i*pi(2k+1)/2`) but the
  same normal direction. Families of two classes on one direction overlap iff their scale
  ratio is a ratio of odd integers.

Declared representation model (M): `y(x) = sum_j p_j(x) * SiLU(l_j(x)) + Q(x)` with `l_j`
affine and nonconstant and `p_j`, `Q` polynomial. The bound below concerns (M) only.

**Bound B (directions).** Terms of (M) have polar normals in `{[l_j]}`, and hyperplanes with
different normals are distinct divisors, so they cannot cancel each other. Hence

    #SiLU terms  >=  #{projective directions carrying at least one uncancelled pole of y}.

A direction carries an uncancelled pole whenever some class `S` on it has `A_S != 0` and no
other class on the same direction cancels it on a shared hyperplane. That cancellation is
possible only when the scale ratio is a ratio of odd integers. For a direction carrying a
single class the hypothesis is just `A_S != 0`.

Counting pole families does not by itself strengthen this to a class-count bound: one
family can contain infinitely many poles of another. We make no such stronger claim.

**Matching.** Theorem 1 realises one SiLU per class with `A_S != 0`. When different class
representatives are nonproportional, each occupies a different direction, and the `±`
collapse attains Bound B in (M). When
a direction carries several scale-distinct classes, the construction still costs one SiLU per
class while Bound B only demands one for the direction; that gap is open and the reflection
identity does not close it. Scaling changes pole locations, and overlaps between the
resulting families require a separate argument.

With all gate functionals pairwise nonproportional and no dead unit, `A_i = C_{:,i} U_i != 0`
for every `i`, and the bound is `FF`: **within model (M), no rewrite reduces the
transcendental count for generic weights**, and the only levers are gate-functional
coincidence up to whole-row sign and residue cancellation, both weight conditions.

The bound says nothing outside (M). It does not constrain arbitrary programs, rewrites built
on other primitives (`exp`, `tanh`, reciprocals, hardware approximations such as
`v_exp_f32`), table- or piecewise-based evaluation, amortisation across tokens, or any
rewrite that is allowed to change the value within the quantiser's tolerance.

## Does the real model have any of this: no

`scan_gate_rows.py` decodes PTQ1_0 blocks straight out of the gguf and classifies layer 0:

```
blk.0.ffn_gate.weight: 17408 rows x 5120 cols, 40 scale blocks
  nonzero trits per row: min 3440 mean 3442.0 max 3463
  all-zero rows: 0        all-zero 128-blocks: 0 / 696320
  exact equal patterns:          17408 distinct rows, 0 classes of size>1
  equal-up-to-sign patterns:     17408 distinct rows, 0 classes of size>1
blk.0.ffn_up.weight: same picture (0 duplicates, 0 dead rows or blocks)
gate/up cross collisions up to sign: 0
units with U_i == ±G_i: 0
sampled 3072 gate rows: max |cos| between distinct rows = 0.5389
```

Median |cos| between distinct gate rows is 0.0125, the 99.99th percentile 0.137, and the
handful of outliers near 0.54 still disagree on about a quarter of their coordinates. Exact
sharing needs 1.0. Near-duplicates are worth nothing: a single flipped trit out of 5120
already leaves a mean absolute error of 0.0121 against a typical `|g|` of 0.56, about 2%
per unit (`paired_ffn.py` section 3), and there is no exact correction term, because the
correction is itself a SiLU evaluated at a different argument.

So: for `PTQ1_0.gguf` as it stands, this line of attack yields nothing. The result is a
weight *condition*, and the weights do not satisfy it.

## What it is worth if the condition is designed in

`paired_ffn.py` section 2 is an executable 4 -> 8 -> 4 network with four `±` classes, all
residue-free, checked against the written network over 64 random inputs (max |diff| 1.4e-14
in float64, which is the reassociation error, not an inexact rewrite):

| form | MAC | exp | mul | add |
|---|---|---|---|---|
| as written | 96 | 8 | 8 | 0 |
| shared gate (C1 only) | 80 | 4 | 8 | 4 |
| bilinear (C2) | 48 | 0 | 4 | 0 |

Offline storage for the bilinear form is 48 trits against 96, because the paired weights are
redundant by construction. A mixed network with three residue-free classes and one ordinary
class still halves the gate matvec and the exponentials.

At Bonsai scale, a `±`-paired FFN (gate rows in opposite pairs, up and down untouched):

- gate matvec `D*FF = 89.1M -> 44.6M` MAC per token per layer; FFN total `267.4M -> 222.8M`
  (-16.7%); `17408 -> 8704` exponentials per layer.
- gate tensor `18.6 MiB -> 9.3 MiB` per layer, 0.58 GiB off the 5.47 GiB file.
- the pair computes `(SiLU(g)*u_+, (SiLU(g)-g)*u_-)`: two independent up directions driven
  by one gate, plus an exactly bilinear channel. It is an architecture change with a
  training cost, not a rewrite of existing weights.

An all-residue-free FFN is `178.3M` MAC with no transcendental at all, at half the hidden
rank — i.e. it is a bilinear network wearing a SwiGLU costume, which is the honest reading
of C2: the condition is strong enough that it removes the nonlinearity rather than
accelerating it.

## Exactness scope

- All identities are over the reals. In FP32 the rewritten order differs in the last ulp;
  no bitwise claim is made, and none was tested on GPU (GPU admission is off).
- The hidden vector is quantised after `SiLU*up`. Two real-equal hidden vectors can land in
  different quantisation bins when a component sits on a bin boundary, so "exact in real
  arithmetic" does not propagate through the quantiser by itself.
- Main's framing (only the 8 abs-max-selecting Hadamard rows per 1024-chunk are locally
  visible) relaxes `A_S = 0` to "`A_S` lands in the locally invisible nullspace within
  certified bin margins". That is a per-token certificate, not a weight condition: checking
  it requires the difference vector that the rewrite was supposed to avoid computing. It is
  their result to develop; nothing here depends on it.

## Leads not taken

- **Dyadic-orbit gate matrices.** If a block of 1024 gate rows were the dyadic shifts
  (index XOR) of one base row, the whole block's dot products would be one Walsh-Hadamard
  correlation: `~11k` ops instead of `1M`. The Hadamard-1024 the kernel already computes is
  half of that transform. This is the only form of the "permuted gate" case that pays, and
  it is a weight-design constraint of the same kind as `±` pairing, on the linear part.
- **Mailman-style block decoding.** A ternary `m x n` matvec costs `O(mn/log_3 n)` signed
  adds with a per-block histogram of `x` over column patterns, with the pattern indices
  being a re-encoding of the same weight bits (no storage blowup, table `3^7 = 2187` per
  block). At `n = 5120` the arithmetic ratio is about 4-5x. This is a linear-part result and
  orthogonal to everything above; it is not what was asked and is not pursued here.

## Files

- `NOTES.md` — this note.
- `paired_ffn.py` — all executable claims: class collapse, the 4->8->4 construction and op
  counts, the breakage cases, the residue convergence, the Bonsai-scale accounting.
  `python3 paired_ffn.py`, runs in under a second, needs numpy only.
- `scan_gate_rows.py` — decodes PTQ1_0 ternary rows from the gguf and classifies one layer.
  `python3 scan_gate_rows.py 0`, about 40 s for layer 0.
- `../../../Kelana/GateClass.lean` — Theorem 1 and its corollaries over `Int` with an
  abstract `s` satisfying (R). `lake build`. The analytic fact that SiLU satisfies (R) is a
  hypothesis there, not a proved lemma: this toolchain has no Mathlib.
