# Token difficulty is a conditional value-of-computation problem

The original Qwen pilot supports the project lead's intuition that some stretches are easier to propose than others. It does not support a universal conversion from token entropy to necessary compute. This experiment separates draft uncertainty, missing candidate support, useful branching and the hardware's marginal verification cost.

[measure.py](measure.py) reads the frozen conditional 200-step checkpoint and the already inspected 32 validation plus 32 test greedy trajectories from [the first round](../qwen/README.md). It constructs one nested 64-node prefix tree per context and records outcomes for budgets `0,1,2,4,6,8,12,18,32,64`. Budget zero is plain target decoding. Every progress count includes one target-produced exit/bonus token. The per-context counts at the four existing budgets reproduce the original report in all 256 comparisons.

The first-order correction head only depends on position and predecessor candidate. Its scores are cached by that pair while generating distinct tree prefixes. At 64 nodes this requires 33.41 unique conditional-row evaluations per test context versus 31.59 further requests served from the cache. That reuse applies to the **draft head**, not target states: different histories cannot merge their target KV merely because the cheap head forgets their distinctions. There is no native time claim for this Python memo.

## Measured heterogeneity

The following quartiles use draft root entropy within the fixed 2,048-token shortlist, not full-target entropy. They are descriptive test strata, not learned routing thresholds. Eight contexts occupy each row.

| Increasing draft entropy | Root token correct | Chain tokens | Six-node tree | 18-node tree | 64-node tree |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0.035–1.725 nats | 87.5% | 2.125 | 2.125 | 2.375 | 2.500 |
| 1.844–2.688 | 62.5% | 2.000 | 2.125 | 2.250 | 2.375 |
| 2.819–3.389 | 75.0% | 1.750 | 1.750 | 1.875 | 2.000 |
| 3.618–4.467 | 37.5% | 1.500 | 1.625 | 1.750 | 1.875 |

The chain emits one token in 11 contexts, two in 15, and three in six. Expanding six nodes to 18 improves five of 32 contexts; expanding 18 to 64 improves four. Most contexts do not benefit from either expansion. Even a free selector of any sequence through the per-position top-16 pool is restricted to one token in six contexts, two in thirteen, three in nine, four in two, and five in two. In those six first-position misses, no rearrangement or enlargement of this fixed-pool tree helps at all.

These data distinguish three different actions:

- A concentrated, reliable continuation earns **depth**.
- Several plausible and represented continuations earn **width**.
- A missing correct continuation needs **a different producer or candidate pool**, not more nodes drawn from the same pool.

High entropy alone does not say which action will help. Low entropy can also be confidently wrong, especially under a vocabulary restriction.

## A general allocation rule with explicit assumptions

For a precommitted tree verified by direct target sampling, a node contributes its target prefix-reach probability to expected covered length. If current expected progress is `N` and cycle time is `T`, an optional change with gains `delta_N` and `delta_T` improves that cycle ratio exactly when

```
delta_N > (N/T) * delta_T.
```

For a stable distribution of incoming contexts, maximize the renewal rate `rho = E[progress]/E[time]`. With predicted progress and priced actions, select an action maximizing

```
E[progress | context, action] - rho * time(context, action).
```

This is a value-of-computation rule, not an entropy law. More draft effort can change candidate support, scores, branch structure and future useful work at once. A fully stateful long-horizon policy also needs the value of its resulting continuation state; the frozen-context experiment here does not solve that control problem. Per-node benefit should include probability of reaching the node: improving a suffix beneath an almost-certain rejection is worth very little.

For ordinary chain acceptance, expected progress is `1 + sum_j product_{i<=j} alpha_i`, where each `alpha_i` is conditioned on prior survival. A small improvement early can rescue a long suffix. The alpha values are target/proposal overlap, not token surprisal. Matching a broad distribution can be easy; producing a deterministic but computationally difficult answer can be hard. A forced grammar token removes selection work under its declared constrained distribution, while its state transition can still be expensive. See [forced spans](../forced-spans/README.md).

## Conditional cost experiment

No new GPU profile was taken. The following is a sensitivity experiment, not a speedup measurement. The assumed normalized cycle cost for `b>0` verified candidates is

```
0.2 + max(1, (1+b)/knee)
```

The `0.2` is a stipulated complete draft/selector cost, and one target-token pass costs one. The knee is target rows per cheap pass. A fixed no-draft strategy pays one. A confidence policy that already ran the draft pays 1.2 even if it then chooses zero candidates. The hindsight oracle is granted free advance knowledge and can bypass drafting; it is not executable.

The pilot proposal's prefix masses predict node visits. One scalar exponent is fitted on validation outcomes by Brier loss over its 64 selected nodes. The chosen exponent is .9576; this is a marginal confidence surrogate, not a new coherent sampling distribution. The fixed budget and adaptive rate are selected on validation only. The fixed checkpoint and all policy choices then score the previously inspected test panel. The adaptive policy has no access to test outcomes. The oracle does.

| Hypothetical knee | Validation-selected fixed budget | Fixed test progress/time | Calibrated adaptive | Hindsight oracle |
| --- | ---: | ---: | ---: | ---: |
| 4 | 2 | 1.4844 | 1.4376 | 1.6064 |
| 8 | 6 | 1.5885 | 1.5834 | 1.6667 |
| 16 | 8 | 1.5885 | 1.6146 | 1.7483 |
| 32 | 32 | 1.7259 | 1.7259 | 1.8249 |
| 64 | 64 | 1.7995 | 1.7995 | 1.8801 |

At the knee of 16 the adaptive policy chooses 12 nodes for **every** test context. Its gain is a different fixed budget, not successful difficulty adaptation. At knees 32 and 64 it likewise chooses one large budget everywhere. At smaller knees its changing budgets lose slightly to the validation-selected fixed control.

The lesson is useful: when extra verification work is genuinely free, recognizing difficulty gives little latency advantage from doing less of it. Difficulty should instead determine what extra work to do, such as retrieving new candidates or refining uncertain high-survival branches. Near the hardware knee, marginal costs matter and a calibrated estimate of the benefit of additional work is needed. Predicting that the current draft is uncertain is not the same as predicting that spending more compute will fix it.

At knee 64, the oracle obtains the same 2.1875 test tokens with 9.6875 mean nodes rather than 64, but its progress/time improves only 4.5% under this nearly flat latency curve. Large avoided node counts need not imply large single-user latency gains. They can still matter for energy, aggregate capacity or a different hardware regime.

## Next useful experiments

1. Predict **gain from an action**, not just confidence in the existing token. Collect paired cheap/richer-pool outcomes and learn the improvement conditional on observable context features.
2. Spend width on multiple represented modes and producer compute on missing support. Candidate-pool misses need their own predicted class.
3. Measure the actual verification knee for the intended backend and occupied context. Head work, expert routing and KV reads may have different knees.
4. Keep the cheap head's finite-state reuse while retaining distinct target prefix states. Materialize unique position/predecessor rows once when enough branches reuse them; evaluate sparsely when few do.
5. Reuse an already paid target decision instead of teaching a small draft to rediscover it. [The candidate-repair study](../candidate-repair/README.md) prices that boundary separately.
6. Fit a policy on fresh, broader target continuations before claiming generalization. This 32-context panel is a diagnostic, not a benchmark winner.

## Reproduce and custody

```sh
/path/to/workspace/data/fish-s2-pro/venv/bin/python research/speculative-maps/adaptive/measure.py
```

The source and [results.json](results.json) are kept in Kelana Git. The JSON contains all selected-node masses, binary visits, per-context counts, calibration candidates and scenario outcomes. It records checkpoint and input hashes. The run takes a few seconds on CPU and changes no target weights or service. Full 64-node trees are materialized in the offline study to obtain counterfactual outcomes; a native adaptive implementation must avoid unused construction or charge it explicitly.
