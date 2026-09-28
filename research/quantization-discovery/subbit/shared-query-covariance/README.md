# Correlated key-score fitting does not rescue the frozen shared query

The [joint three-dot query fit](../shared-query-joint-round/README.md) minimizes a diagonal two-head error for each of 32 selected coordinates. The cached key codes are correlated, so I replaced that surrogate with the measured covariance of the *actual packed key codes*. One cyclic coordinate sweep lowers this covariance-weighted score-error surrogate substantially, but barely changes causal attention quality. A second sweep reduces the surrogate further and worsens held KL on both layers. This closes a tempting way to spend more query-preparation work on the frozen Q/K image.

| Frozen Qwen3-0.6B layer | Diagonal joint fit held KL | One correlated sweep | Two correlated sweeps | Four independent dots |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .278049 | .277601 | .277748 | .275431 |
| 14 | .333448 | .333181 | .333225 | .332396 |

These are original-producer, four previously inspected 256-token validation windows, with the same train-selected base head and head weight per GQA group as the parent. The score and key image do not change: two signed-nibble base dots plus one signed-nibble difference dot, 768 logical products/key/layer, 128 cached K bytes/token/layer, the complete paid binary Q/K images and the full raw K-norm producer. This is not model loss or native time. The layer-0 gain after one sweep is .000447 nat, just 17.1% of the diagonal fit's remaining gap to four dots; the layer-14 gain is .000267 nat, 25.4% of its remaining gap.

## Exact conditional update, not an exact global lattice solution

For a GQA group, let `c_t` be its 32 signed-nibble key codes and `a0,a1` the two prepared real queries after key-step multiplication. The existing dynamic scales `d=max|a0|/119` and `e=max|a1-a0|/7` stay fixed for each query. Base integers `u` lie in `[-119,119]`; difference integers `v` lie in `[-7,7]`. With `r0=a0-d*u`, `r1=a1-d*u-e*v`, minimize the finite quadratic surrogate

```
F(u,v) = r0^T C r0 + lambda * r1^T C r1.
```

`C` is a single 32-by-32 matrix per group, fitted on eight separate train windows. For each causal prefix, subtract its mean key code from every key before forming the outer products, then average those outer products over train windows and prefixes. The centering matches softmax's invariance to a constant score per query. A tiny diagonal regularizer makes the measured `C[j,j]` positive; it does not supply teacher labels. Query scores remain the *unmodified* three-dot map.

Holding all coordinates except `j` fixed, write `z_h = (C r_h)_j` and `m=C[j,j]`. The local objective differs by a constant from

```
(a0'[j] - d*u[j])^2 + lambda*(a1'[j] - d*u[j] - e*v[j])^2,
a0'[j] = d*u[j] + z_0/m,
a1'[j] = d*u[j] + e*v[j] + z_1/m.
```

For each of fifteen `v[j]` values, round and clip the continuous best `u[j]`; choose the least local cost. This is an **exact conditional** integer minimizer and cannot increase `F` at any coordinate. With a tie rule that retains the current label, repeated sweeps eventually reach a coordinatewise local minimum on the finite state space. The replay uses ordinary minimum-index tie breaking and runs only two sweeps, not a claim of global optimality. The zero-sweep arm reproduces the parent diagonal selection and held KL at both layers.

Across groups, mean train/held `F` falls 3.5418/3.5632 to 2.9043/2.9229 after one sweep at layer 0, and .9191/.9470 to .7363/.7569 at layer 14. That sweep changes 63,317 and 65,354 held integer labels relative to the diagonal solution, counting base and difference separately. The second sweep cuts held `F` again to 2.8317/.7251 but raises held KL on both layers. Its layer-0 train KL also rises .256661→.256731. The quadratic is not the causal objective.

## Online price and next question

One sweep performs 32 sequential coordinate updates per GQA group and evaluates up to fifteen candidate `(u,v)` pairs at each update, **3,840 candidate fits/token/layer** before covariance products. The losing second sweep doubles that to 7,680; the two 32-entry covariance residual dot products at every update cost 16,384 multiply-adds/sweep/layer across eight groups, plus the same order of work for a maintained-residual vector update if used instead. The replay rebuilds the products, so its CPU elapsed time is not native query-preparation time. A native consumer would also pay storage for eight 32-by-32 covariance matrices, register/lane movement, and the unchanged score and softmax. The [square-root-free diagonal certificate](../shared-query-neighbor/README.md) already finds the diagonal optimum with about 264k–268k scored labels across 262,144 held coordinates; a correlated sweep scores 15 additional pairs for every coordinate for this small KL change. Do not implement this fixed-image covariance fit natively ahead of learning the paid Q/K producer and score consumer against composed loss on fresh quantized-producer text. A changed coordinate or producer, not another frozen-query quadratic, is the useful next question.

`measure.py` writes per-group/window KL, covariance errors, changed-label counts, and hashes of source, model, capture, paid images and parent receipts into `/path/to/workspace/data/kelana-subbit/shared-query-covariance/layer{00,14}.json`. It runs in the installed CPU environment:

```sh
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/shared-query-covariance/measure.py \
  --layer 14 --output /path/to/workspace/data/kelana-subbit/shared-query-covariance/layer14.json
```
