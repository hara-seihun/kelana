# Score the softmax that consumes the program

A local output RMS can rank ISA-map approximations backwards. There is a useful middle ground between that score and a full model run: when the next consumer is softmax, its reference probabilities give an exact sparse-edit score and a bounded dense-edit score. Neither certifies a later recurrent state or an individual rare gold token.

## One softmax boundary

Fix reference logits `z`, `p=softmax(z)`, candidate logits `z+d`, and `q=softmax(z+d)`. All quantities below refer to the same input and the **complete** logit error after any fused program. Define `A(d)=log(sum_i p_i exp(d_i))` and `m=sum_i p_i d_i`. Direct normalization gives

```
KL(p||q)                 = A(d) - m
NLL_q(y) - NLL_p(y)      = A(d) - d_y
E_{y~p}[NLL_q(y)-NLL_p(y)] = KL(p||q).
```

This is a log-partition identity, not a local approximation. A common logit shift disappears exactly, even if its coordinate MSE is large. If `d` differs from one common shift on only `k` vocabulary entries, subtract that shift and evaluate `A(d)=log1p(sum_{edited i} p_i expm1(d_i))`. Given the reference probabilities for those entries, scoring each candidate takes `O(k)` arithmetic and no candidate full-vocabulary softmax. Obtaining and retaining the reference normalization still costs a full softmax per calibration input. A dense error costs `O(V)` per input; the formula does not make it free.

For a dense edit, let `v=Var_p(d)` and `r=max_i d_i-min_i d_i`. Then

```
v (r-1+exp(-r))/r² <= KL(p||q)
                    <= v (exp(r)-1-r)/r²,
KL(p||q)             <= r²/8.
```

At `r=0` the first two expressions have their continuous value `v/2=0`. To see the bounds, put `p_t(i)=p_i exp(t d_i)/sum_j p_j exp(t d_j)`. Differentiating the log partition twice gives `KL=integral_0^1 (1-t) Var_{p_t}(d) dt`. For every `i`, `exp(-tr) <= p_t(i)/p_i <= exp(tr)`. Variance is the minimum over centers `a` of `sum_i p_i(d_i-a)^2`, so `exp(-tr)v <= Var_{p_t}(d) <= exp(tr)v`. Integrate. The last bound is Hoeffding's lemma for a variable of range `r`. Use the smaller upper bound. This certifies teacher-distribution KL at this softmax boundary for any edit size, while `v/2` alone is only its second-order term.

A practical candidate filter can compute `v`, `r` and the upper bound on a fixed panel of complete logits. Sparse nominees can instead use the exact `O(k)` expression. This is a certificate for those inputs only. It scores an executable program's *observed* logits, not its separately reconstructed weights, and says nothing about model bytes or instruction cost. Do not prune a nominee solely by a lower bound unless the acceptance objective is the same teacher KL.

## Three finite witnesses

Run `python research/isa-quantization/observation-loss/witness.py` from the repository root. It prints [`results.json`](results.json) using only the Python standard library. The script checks the stated numeric inequalities in less than a second. Its binary logits are small witnesses, not a frequency study.

* At `p=(.99,.01)`, a common shift `d=(.8,.8)` has coordinate MSE `.64` and KL `0`. The alternative `d=(0,1)` has MSE `.5`, but KL `.00703686`. MSE prefers the wrong program even at one softmax boundary. The consumer variance gives `0` versus `.0099`; its certified KL interval for the second program is `[.00364201,.00711099]`.
* For `z=(0,-20)`, make the rare second token the gold label and change only its logit by `-10`. The teacher KL is `1.85505e-8`, but that gold token's NLL rises by almost `10`. With a `+10` change instead, half the reference Fisher variance is `1.03058e-7`, while exact teacher KL is about `4.54e-5`: a tiny rare-token Fisher score alone also misses a large finite edit. The exact sparse expression sees both. Gold NLL and teacher KL optimize different expectations; this is the same distinction seen in the [tied-head softmax study](../../quantization-discovery/subbit/tied-softmax/README.md).
* At step one of a two-step generator, both systems emit logits `(0,0)`, so one-step KL is zero. The teacher advances its scalar state to `0`, and the candidate advances to `1e-6`. A next-step logit consumer with gain `1e7` emits `(0,0)` for the teacher and `(10,0)` for the candidate. The conditional KL is `4.306898`. Smaller first-step state errors and arbitrarily large later KL follow by rescaling the gain. This shows why scoring only the current softmax cannot certify a future state. It is distinct from the [near-critical recurrence example](../../ternary-toys/recurrent-stability/README.md): here the omitted continuation is explicit, not an observed frequency of unstable weights.

## What a sequence guarantee actually needs

For autoregressive distributions over `T` tokens, the chain rule is exact:

```
KL(P_teacher(Y_1:T) || P_candidate(Y_1:T))
  = sum_t E_{h~P_teacher(Y_<t)} KL(p_teacher(.|h) || p_candidate(.|h)).
```

The candidate conditional must recompute its own internal state on the **same token history** `h`; comparing both policies at the teacher's hidden state is insufficient. A uniform conditional upper bound `epsilon_t` on every allowed teacher history yields a sequence bound `sum_t epsilon_t`. A finite teacher-forced panel gives only a panel expectation, not a worst-case history bound. If the objective is gold-token NLL on held text, use the exact `A(d)-d_y` instead of substituting teacher KL. For a future-state proposal, either score the actual continuation on each selected history or derive a bound on the continuation map and its reachable states. No one-step curvature metric supplies that bound for free.

The structural contribution here is an inexpensive *consumer-specific* score with explicit failure modes. It does not propose a quantization format, claim native speed, or establish held language-model quality. The source's [representation map](../../quantization-discovery/representations/MAP.md) records several full-model reversals that a softmax-panel score alone cannot settle.
