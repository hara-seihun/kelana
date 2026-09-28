# Exact elimination of closed factors

`Kelana/ProducerElimination.lean` proves the reduction used by the producer
frontier DP. It imports only `Std` and has no dependency on the producer-domain
implementation.

## Model

After exact integer scaling, write the robust part of a prefix and continuation
as

\[
  \sum_{f\in F} \rho_f\,|s_f+u_f|.
\]

Here `s_f` is the prefix sum for factor `f`, `u_f` is the sum contributed by the
future actions, and `rho_f` is a natural-number price. For the correlated domain
`center + Bz`, use one factor for `center . e` with price `lambda`, and one factor
for each generator row `B_j . e` with price `lambda * r_j`. Duplicate entries in
`F` are allowed. This matters because the Lean model uses a list and makes no
`DecidableEq` assumption on factors.

The formal objective is

\[
  paid(p)+cost(A)+\sum_{f\in F}\rho_f
  |s_f(p)+u_f(A)|.
\]

`Int.natAbs` represents the absolute value. Any rational instance can first use
a common positive denominator. The scaling preserves minimizers.

## Closure identity

Let `C` contain the factors closed at the current stage and let `L` contain the
remaining factors. Closure requires

\[
  \forall a\in A,\ \forall f\in C,\quad contribution(a,f)=0.
\]

Therefore `u_f(A)=0` for every `f` in `C`, and

\[
\begin{aligned}
 &paid(p)+cost(A)+\sum_{f\in F}\rho_f|s_f(p)+u_f(A)|\\
 ={}&\left(paid(p)+\sum_{f\in C}\rho_f|s_f(p)|\right)
   +cost(A)+\sum_{f\in L}\rho_f|s_f(p)+u_f(A)|.
\end{aligned}
\]

Lean theorem `closure_identity` proves this for arbitrary factor and action
types and arbitrary finite factor lists. `penalties_partition` proves the list
partition, including repeated factors. `contributionSum_closed` proves that the
future sum vanishes on a closed factor.

## Frontier equivalence and dominance

Define the reduced paid cost

\[
  paid_C(p)=paid(p)+\sum_{f\in C}\rho_f|s_f(p)|.
\]

Two histories have the same numeric DP key when their live sums agree. They can
share a frontier entry only if they also admit exactly the same legal future
action lists. This legality condition is independent of the numeric proof and
is explicit in `SameLegalFutures`.

If histories `a` and `b` satisfy

\[
 paid_C(a)\le paid_C(b),\qquad
 s_f(a)=s_f(b)\quad(f\in L),
\]

then every common legal continuation has objective at `a` no greater than its
objective at `b`. This is `reduced_dominance_preserves_legal_futures`. The
hypotheses include both facts that pruning needs:

1. `a` and `b` have the same legal future actions.
2. Every legal future action contributes zero to every closed factor.

When the reduced paid costs are equal, the objectives are equal for every legal
continuation. `reduced_equivalence_preserves_legal_futures` proves that stronger
statement. Consequently, a frontier map keyed by all live factor sums may keep
only the least reduced paid cost for each key and legality class. Its width is
controlled by factors that are simultaneously live, not by every factor that
has appeared.

## Finite Bellman step

`finiteMinimum` computes the exact minimum of a finite list of natural-number
costs and returns `none` for an empty menu. `finiteMinimum_eq_some_iff` proves
that a returned value is attained by a menu action and is no greater than every
menu action's cost.

`bellman` applies that minimum to `stageCost action + continuation action`.
`bellman_eq_some_iff` is its exact Bellman characterization. The continuation
may encode all later stages, so this theorem adds no relaxation or independence
assumption.

## Kernel status

The file contains no `sorry` and declares no axioms. Its four exported checks
report only Lean and `Std` foundations such as propositional extensionality,
quotients, and choice for the list minimum theorem.
