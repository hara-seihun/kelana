# Two outputs from one packed word

The two-bit finite machine computes AND and XOR together in four instructions. Their independent optima cost three and two. Reversing the output registers raises the joint optimum to five. Another pair, scaled AND and OR, costs four together against six separately. Both are exact whole-map results, not GPU timing claims.

The complete input domain is `x = b0 + 2*b1` for `x = 0,1,2,3`. The machine starts with two two-bit registers `(r0,r1) = (x,0)`. Its `full` grammar has 68 named instructions from [`machine.py`](machine.py), additive charges one except multiplication at three, and no memory, branching or lane operations. A `pair-exact` terminal contract reads both registers. No intermediate is prescribed and the initial zero in `r1` is part of the input interface.

For `r0 = b0 AND b1`, `r1 = b0 XOR b1`:

```
sub  r1 r0       # -x modulo 4
shri r1 1        # b0 XOR b1
sub  r0 r1       # x - (b0 XOR b1) modulo 4
shri r0 1        # b0 AND b1
```

For `r0 = 2*(b0 AND b1)`, `r1 = b0 OR b1`:

```
sub  r1 r0
or   r1 r0
add  r0 r1
shri r1 1
```

[`m1-full.cert.json`](results/m1-full.cert.json) carries a forward potential for all 65,536 complete input-to-register-file maps. The independent checker re-derives every instruction table, verifies the potential inequality on every transition, intersects the finite potential with each two-register endpoint mask and replays each witness. This proves the joint minima over **all program lengths** in the declared grammar, not merely a search depth. Backward potentials also prove that an optimal AND/XOR program has at least four instructions and can use only `and`, `shri` and `sub` opcode families. The reversed joint interface costs five because placement is observable, not a free relabeling.

This gives an actual search reduction: for the four-charge AND/XOR boundary, omit the other opcode families without losing an optimum. Native follow-up should first price preparation of the zero scratch register, packed input and output placement at a real pair of consumers. Four abstract instructions do not imply a faster gfx1151 region or an FP32 identity. The comparison only applies to the declared finite machine and its exact integer endpoint.

From the Kelana root, replay with `python3 research/discovery/resource-bounds/finite-machine/check.py research/discovery/resource-bounds/finite-machine/results/m1-full.cert.json`. Regenerate with `python3 research/discovery/resource-bounds/finite-machine/experiments.py --quiet`.
