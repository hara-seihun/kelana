# One trit for a softmax state that gets used again

A softmax ignores a common logit offset. That fact only licenses throwing the offset away if the next consumer ignores it too. Here a one-trit state code preserves *all* current probabilities and spends its otherwise unused third label on a future distinction. It halves excess two-step NLL against the pointwise softmax code. Fitting three labels by raw-logit squared error chooses the opposite distinction and loses at the observed objective.

## Finite producer and continuation

Four equally likely states have a current logit gap `m ∈ {-2,2}` and common coordinate `c ∈ {-1.5,1.5}`. The two logits are `z=(c+m/2,c-m/2)`. The first softmax depends only on `m`; its winning class and *both* probabilities are exactly recoverable from the sign of `m` on this support. Feed the same state through `A=diag(1,-1)` before the second softmax. Its logit gap is `D A z=2c`, where `D=(1,-1)`. The first observation has weight .7, the second .3 in expected teacher-distribution NLL. Both binary outcomes are nontrivial and neither stage observes the raw logits directly.

The pointwise quotient fails as a state representation: `D(1,1)=0`, but `DA(1,1)=2`. States with the same `m` and different `c` have identical first distributions and opposite second decisions. More generally, for linear continuation `A`, common shifts are safe to discard only if `A1` lies in the span of `1` on the reachable domain. For several continuations, exact linear observations need the quotient by the intersection of their observation kernels, `⋂ₜ ker(D Aᵗ)`, not merely `ker(D)`. Here `[D; DA]` has rank two.

## One-trit experiment

Enumerate every partition of the four states into two or three labels. For each label, fit its decoded state using the conditional mean of the teacher's Bernoulli probability *at each observed step*. Those two probabilities determine a unique decoded two-logit state because `[D; DA]` is invertible. Score expected excess NLL as weighted Bernoulli KL. Separately fit each partition by ordinary raw-logit squared error and select the squared-error minimum. There is no training/held split: this is the exact finite population and all six three-label partitions are checked.

| One-trit state encoding | Excess NLL, first | Excess NLL, second | Weighted excess NLL | First/second top-1 agreement | Raw-logit MSE |
| --- | ---: | ---: | ---: | ---: | ---: |
| Pointwise softmax, two active labels | 0 | .502282 | .150685 | 1 / .5 | 4.5 |
| Three labels, observed-NLL fit | 0 | .251141 | **.075342** | 1 / .75 | 2.25 |
| Three labels, raw-logit MSE fit | .163907 | 0 | .114735 | .75 / 1 | **1.0** |
| Four labels, exact-state reference | 0 | 0 | 0 | 1 / 1 | 0 |

The observed-NLL optimum merges just one pair with the same `m`, leaving the first softmax exact. Its labels in order `(-2,-1.5), (-2,1.5), (2,-1.5), (2,1.5)` can be `[0,1,2,2]`. An affine threshold encoder realizes this partition: put `u=m/2`, `v=c/1.5`, and classify `2u+v` at thresholds `-2,0`. The three values decoded for `z` are `(-2.5,-.5), (.5,2.5), (1,-1)`. Its current top-1 never changes; the pooled future pair produces a tie and the other two states retain their future decisions. Ties count as one correct out of the two opposed teacher decisions.

The squared-error optimum instead merges a pair with the same `c`, preserving the second distribution while losing a first-step distinction. It has an equally simple affine threshold encoder: classify `2v+u` at `0,2`. The comparison is therefore not between a lookup oracle and a cheap linear rule. The .7/.3 weights, finite margins and common-mode magnitude make raw-logit MSE prefer `c`, while observed NLL prefers `m`. At this rate, any three-label code must merge at least two of the four distinguishable two-step states. Merging a same-`m` pair costs .075342 weighted nats, a same-`c` pair .114735, and a diagonal pair .190077. The oracle's nonzero NLL is not an optimizer failure.

All one-trit arms have the same index rate, `log₂(3)=1.585` bits/state ideally or 1.6 bits/state packed five-to-a-byte. Reserve the same three-entry, two-FP16-logit decoder table, 12 bytes, for each arm, including the pointwise control's unused entry. Both fitted three-label encoders use one integer linear combination and two comparisons, then a two-FP16 table read and `A` before the next softmax. The pointwise control uses a simpler sign check. Exact coding needs four labels, at least two bits/state and a 16-byte FP16 table. The experiment measures information loss, not a throughput or whole-model storage improvement; producer coordinate extraction, packing, table reads and the extra comparison still need pricing in a real kernel.

Run with standard Python and no model or GPU:

```sh
python research/ternary-toys/observed-logits/experiment.py
```

The script writes [results.json](results.json), asserts the cheap affine encoder attains the enumerated optimum, and records each decoded table, partition, NLL, decision agreement and raw-logit MSE. It also checks the four-label zero-distortion reference.

## Transfer test

On captured quantized-producer states, measure the current and downstream softmax probabilities or gold-token losses before deciding which common offsets and margins to collapse. Search same-rate codes against *composed* NLL, alongside pointwise probability fitting and raw-logit MSE, and charge decoder metadata plus native conversion work. First check whether downstream consumers preserve common shifts on the reachable states. If they do, this toy's extra label buys nothing; if they do not, estimate conditional future loss within each proposed code fiber. An NLL improvement that disappears under actual gold labels, residual propagation or full-model inference would falsify transfer. This toy deliberately has two class probabilities and a linear next-state map; it does not claim the measured .075 nat gain on Qwen or a ternary weight-image saving.
