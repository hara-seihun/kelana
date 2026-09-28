# Tensor fidelity: an all-power shared-label hierarchy

The [emission-subspace bound](../emission-subspace/README.md) becomes zero when candidate capacity `C` reaches vocabulary dimension `V`, even if there are more than `C` distinct teacher laws. This study removes that **zero-detection limitation** by an all-power theorem. It never materializes a tensor vocabulary and does not search a ladder of successive powers. A coherence inequality chooses one power directly; exact matrix certificates accept it.

## The hierarchy is an analytic lift, not future independence

For fixed teacher laws `p_s`, fixed candidate laws `q_c`, occupancy `w(s,c)` and total teacher mass `M`, define

```
a_s = sqrt(p_s),       ν_s = Σ_c w(s,c),       π_s = ν_s/M.
```

For every positive integer `k`, imagine `k` iid copies **of each one fixed emission law**. Then

```
KL(p_s^⊗k || q_c^⊗k) = k KL(p_s || q_c).
```

The candidate still has only `C` tensor emission vectors. Applying the previous shared-span theorem to these auxiliary laws gives

```
loss ≥ L_k := −(M/k) log Λ_C(ρ_k),
ρ_k = Σ_s π_s a_s^⊗k (a_s^⊗k)ᵀ.                           (1)
```

This is not an assumption that the candidate keeps the same state for its next `k` autoregressive tokens. The tensor construction is only an inequality applied separately to each conditional law in the original occupancy-weighted loss. That loss equals token-sequence KL for deterministic own-state candidates under the predecessor's contract. Stochastic hidden-state mixture predictors remain outside it.

The nonzero eigenvalues of `ρ_k` are those of its much smaller **source Gram**:

```
G_k(s,t) = sqrt(π_s π_t) <a_s,a_t>^k.                     (2)
```

The occupancy weights stay **outside** the power. Equation (2) follows from tensor inner-product multiplicativity and equality of the nonzero spectra of `AᵀA` and `AAᵀ`. Thus one uses an `S×S` matrix even though the auxiliary vocabulary has dimension `V^k`. Higher powers need not improve the quantitative bound because of the `1/k` factor. The maximum over accepted powers, including `k=1`, remains sound; their sum does not.

[`Kelana/EmissionTensor.lean`](../../../Kelana/EmissionTensor.lean) defines actual Cartesian words and multiplicative rational tensor amplitudes, then proves the tensor dot identity and weighted source-Gram power identity for **every k by induction**. No individual powers or numerical examples stand in for that theorem. Real roots, KL product additivity and spectral variational facts remain the analytic argument above.

## Completeness for marginal zero-error capacity

First merge exactly equal teacher laws and sum their positive occupancies. Let the remaining number be `m`, with all `π_s>0`. Distinct probability laws have strict square-root fidelity `<a_s,a_t><1`. Consequently `G_k` tends to the positive diagonal `diag(π)` as `k→∞`.

If `C<m`, eventually every eigenvalue is positive, so the sum of the largest C is strictly below the trace one. Some finite `L_k` is therefore **strictly positive**. If `C≥m`, an arbitrary encoder can label each distinct law and an arbitrary readout can emit it exactly; every `ρ_k` has rank at most m and the hierarchy is zero. Hence

```
there exists k with L_k>0  iff  C < number of distinct positive-mass teacher laws.
```

This is completeness for the **unpriced marginal fixed-law capacity obstruction**, not a cheap implementation theorem. Legal ISA encoders, paid readout fields, shared consumers and causal history may still prevent exact behavior when `C≥m`. Conversely, a reader that retains other live inputs is not a C-label-only decoder. The theorem does not turn weight-code alphabet size into a bound on the number of complete emission laws.

## A power chosen from the geometry, not by enumeration

Let `κ<1` upper-bound all off-diagonal fidelities, let `W_C` be the sum of the largest C occupancy weights, and set

```
R = max_s Σ_(t≠s) sqrt(π_s π_t).
```

The symmetric off-diagonal matrix `G_k−diag(π)` has absolute row sum at most `R κ^k`. Therefore

```
Λ_C(G_k) ≤ W_C + C R κ^k.
```

For `C<m`, choose a positive integer k satisfying

```
κ^k ≤ (1−W_C)/(2 C R).                                   (3)
```

Then the overlap is at most `(1+W_C)/2<1`, a direct positive KL floor. This also quantitatively proves eventual detection without a convergence-only argument. For equal weights it reduces to `κ^k≤(m−C)/(2C(m−1))`.

[`study.py`](study.py) obtains a conservative integer k directly from rational log enclosures in (3), with one extra integer of safety, then verifies the power inequality. It computes only the first-order control and this one analytically selected power. The power need not maximize the resulting bound; its job is to provide a constructive zero-obstruction certificate. Exponentiation uses interval repeated squaring, so neither tensor size nor a loop through intermediate powers enters acceptance.

## Exact finite certificates and strong controls

The source Gram is reconstructed from exact rational teacher probabilities/weights, enclosing square roots and outward-rounded interval powers. A numerical spectral proposal is accepted using the sibling study's exact **positive-minus-negative Gram plus row-error** checker. It bounds overlap by a rational majorant and divides its enclosed negative logarithm by k. Numerical eigenvalues and eigensolver status are not proof inputs. The simpler coherence/row bound from (3) is retained alongside the sharper accepted matrix certificate.

All cases below have `M=1,C=2`; the first four reuse complete predecessor fixtures. The final two distinguish the new scope from redundant lifting.

| Source family | Directly selected k | First-order floor | Accepted k-power floor |
| --- | ---: | ---: | ---: |
| Four product laws | 14 | .06933646 | .04056080 |
| Six generic four-token laws | 51 | .02869151 | .01313026 |
| Four near-point-mass laws | 2 | .69114719 | .34657159 |
| Two live binary contexts, shared code | 27 | .03406741 | .02037348 |
| Three distinct Bernoulli laws, only two output symbols | **61** | **0** | **.00530533** |
| Four source states but only two distinct laws | no lift needed | **0** | exact marginal assignment exists |

The Bernoulli probabilities are `1/4,1/2,3/4` with equal occupancy. Their exact two-label clustering floor is **.02254805**, so the accepted tensor bound is positive but not optimal. Their first-order subspace bound is identically zero because `C=V=2`. The tensor calculation still uses only a **3×3 source Gram**, not `2^61` coordinates. Ordered Bernoulli DP is the stronger specialized control here; the tensor theorem applies to arbitrary finite vocabularies and capacities.

The other cases deliberately show that lifting is **not a monotone accuracy ladder**. Keep their stronger k=1 certificates. Exactly repeated laws are coalesced before counting capacity, so four source-state names do not manufacture a false four-law obstruction. Complete two-label categorical enumeration is run afterward as an independent finite control; it never chooses the power or seeds a proposal. All finite matrix/loss intervals are in [`results.json`](results.json), and the saved dyadic proposals are in [`certificates.json`](certificates.json).

## Reproduction and limits

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/emission-tensor/study.py propose
python3 research/isa-quantization/emission-tensor/study.py check
lake env lean Kelana/EmissionTensor.lean
```

Both commands finish in seconds. The finite fixtures use 88-bit outward intervals; their distinct-law fidelities separate strictly at this precision. The shared acceptance helper now accepts any enclosed symmetric density, allowing both vocabulary and source-Gram coordinates without a duplicated verifier. The original emission-subspace receipts replay unchanged in value.

The all-k Cartesian Gram identity and rational quadratic majorant have Lean foundations. The real/algebraic interval bridge, nonzero-spectrum correspondence, trace bound, KL/Jensen argument and finite-power completeness theorem remain separately stated mathematical derivations, not a claimed fully formalized language-model result. The hierarchy is an admissible search envelope for explicit fixed-law/shared-label boundaries. No model image, BPW improvement, native speedup or full-model perplexity change follows from these certificates.
