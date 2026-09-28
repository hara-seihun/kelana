# Transfer to fixed trained regions

The eleven-state construction does not transfer exactly to the tested Bonsai regions. Its main failure is lost information, not an expensive output relabeling. Changing the consumer cannot fix those collisions. [A minimal two-bit sideband](SIDEBAND.md) repairs those exact collisions on the three-trit domain, at one additional assembled data instruction when the original packed word cannot stay live. Its trained continuation and runtime cost are still open.

The useful addition is `capacity.py`: a lower bound on approximation error for **any** carrier with a given number of states. It uses output distances, not instruction names, numeric labels, or the earlier producer grammar.

The [generated tables](trained-results/summary.md) contain the measurements. No model, service or inference kernel was changed.

## What was held fixed

We used the trained PTQ1_0 weights from layers 0 and 10, with contextual inputs at token positions 0 and 127 of the existing benchmark document. For each context, three prescribed coordinate triples define separate regions:

```
(2,17,93), (129,167,230), (37,1729,4091).
```

The first two lie within individual 128-wide quantization blocks. The third crosses blocks. All other input coordinates remain fixed.

The CPU reconstructs the normalized, signed, Hadamard-rotated A8 input from the captured residual, using the engine's `1e-6` normalization epsilon. At the region boundary, block scales stay fixed and each selected integer code varies by `-step, 0, +step`. The step is `min(32,127-abs(base_code))`. None of the selected codes is an endpoint, and an unchanged coordinate retains each block's maximum, so all 27 states remain within the same fixed-scale A8 interface.

Every state passes through the trained gate/up projections, SiLU product, signed normalized hidden Hadamard, and the entire trained down projection. We observe all 5120 output coordinates, without adding the unchanged residual. Three versions use no hidden quantizer, the A8 hidden quantizer, or the A4 hidden quantizer. Gate/up input precision stays A8 in all three versions.

This gives twelve input cubes and 36 output tables. The coefficients are trained; the perturbation cubes are prescribed probes, not a claim about the frequency of those inputs in inference. Computation is CPU float64 with the actual HALO trits and FP16 block scales. It is not a bit-exact model of native floating evaluation.

At zero perturbation, the CPU A8 path differs from the captured engine FFN update by relative RMS `9.98e-8` to `9.03e-5`. The larger layer-10 difference remains in the record. The experiment concerns these explicitly evaluated tables, not a newly established native numerical identity.

## What was fitted

For each table we compute:

- The best affine fit using the six consumers of the previous eleven-state carrier.
- The best arbitrary decoder of the same carrier, obtained by averaging within its fibers.
- The best of all 48 input sign/permutation orientations of that family.
- The best arbitrary decoder for each capacity over 666 distinct partitions from the declared ISA-shaped producer grid.
- Linear, quadratic and cubic polynomial fits as structural controls.

All fits receive a free intercept. Coefficients and the best orientation may change with the context and coordinate triple. This is deliberately more generous than a deployable weight-only preparation. A positive fit would still owe its online coefficient-construction cost. There is no held-out quality claim here: every state of each finite cube is enumerated.

Errors use the norm of **output variation about its mean across the cube**. Otherwise the unchanged background would make an observer that discards the perturbation look accurate. The generated table separately reports error against the full update norm.

The six-function subspace lies inside the space of all functions of the carrier. Consequently squared error splits orthogonally:

```
restricted-consumer error
  = unavoidable fiber error + extra error from the restricted consumer.
```

The tests check this decomposition against explicit reconstructed output vectors, independently of the Gram-matrix scoring shortcut.

## The measured answer

Without hidden quantization, the selected family loses 55.3-64.8% of output variation. A completely free decoder of its eleven states does almost exactly the same. With A8 hidden quantization, family error is 58.2-70.7%, versus 57.2-67.6% for the free decoder. Sign/permutation search does not rescue it.

Every computed output table has 27 distinct vectors. Every selected-carrier report includes two concrete colliding inputs and a differing output coordinate. Thus the failure of exact transfer is visible without a polynomial fit or a rank tolerance.

These percentages are **not** full-FFN or model-quality losses. The perturbation's output variation is only about 0.25-1.8% of the full update in the unquantized/A8 cases, and 1.1-5.2% with A4 hidden quantization. A lossy replacement of one small region can therefore have modest full-update error while failing to preserve most of that region's contribution. Errors from replacing many such regions have not been measured and cannot be assumed to cancel.

## A bound without an instruction grammar

Let `y_i` be the required output vectors for `n` reachable inputs. An `m`-state carrier partitions the inputs into at most `m` classes. Even a free decoder minimizes squared error by returning each class mean. For a class `S` of size `r`,

```
SSE(S) = (1/r) sum_{i<j in S} ||y_i-y_j||².
```

If the smallest pair distance squared is `delta²`, every partition obeys

```
SSE >= (n-m)*delta²/2.
```

That already rejects an approximate observer before considering its encoding or instructions. We also implement a stronger relaxation. Let `d_i,1 ... d_i,n-1` be the sorted squared distances from output `i` to the other outputs, and define

```
c_i(r) = (d_i,1 + ... + d_i,r-1)/(2r),   c_i(1)=0.
```

If point `i` belongs to an actual class of size `r_i`, its contribution to the pairwise error is at least `c_i(r_i)`. Also `sum_i 1/r_i` is exactly the class count. Therefore, for every `lambda >= 0`,

```
SSE >= sum_i min_{1<=r<=n} [c_i(r) + lambda/r] - lambda*m.
```

The code maximizes this bound over the breakpoints of the piecewise-linear expression. It drops the requirement that each point's nearest neighbors agree on a common partition. That makes it a lower bound, not an achievable clustering or a program. All quantities are normalized by total centered output energy. Each record retains the maximizing dual parameter.

The implementation is ordinary float64 numerical evaluation of this mathematical bound. Regression tests compare it with every partition of several five-point problems, check a simplex where it is tight, and cover coincident outputs. There is no Lean proof or interval-arithmetic certificate of these trained floating tables.

Across the tested regions, any eleven-state carrier has at least 31.6-55.1% relative RMS error in output variation. More sharply, **even a 26-state carrier has a lower bound of 7.6-13.4%**. Thus reaching 5% relative error in this particular variation metric requires preserving all 27 distinguishable states. This is independent of the tested ISA grammar.

The [exact high-capacity enumeration](high-capacity/README.md) closes the gap at the near-lossless end: the 26-state closest-pair bound is achievable, while 25 states cost 10.69-19.02% output-variation RMS over the 36 trained tables, even with an arbitrary free decoder. Every 25-state optimum merges two disjoint pairs. This is a capacity result on the same computed CPU tables, not a native kernel or a full-model quality claim.

The assumption is that the carrier is the complete input-dependent state available to the continuation. Retaining the original input elsewhere, or another dynamic register, increases that state and can evade the bound. Prepared weights do not, since they are fixed across the inputs.

## What to search next

This does not say to recover trits or hidden channels. The original radix-3 input already retains all 27 states in five bits. An injective relabeling of those states remains free to make subsequent operations cheaper. The failed choice was reducing this trained region to eleven states, not using packed coordinates.

The controls locate another obstacle. Before hidden quantization, a local quadratic fits these small perturbation cubes to roughly `4e-6` to `1.4e-5` relative RMS. With A8 hidden quantization the same fit leaves 22-40% of variation; with A4 it leaves 46-48%. This comparison changes only the hidden quantizer. Smooth local algebra misses the quantization-cell boundaries.

Those cheap-looking polynomial fits are not new kernels: their coefficients depend on the runtime context, and forming them has not been priced. The next representation search should retain all input distinctions and model the quantizer's cells within the same region, rather than first fitting a smooth map and hoping the discontinuities disappear afterward. The capacity screen now lets us reject destructive carriers without spending a GPU run on them.

The [quantized-code separator study](../../ffn/quantized-separators/README.md) evaluates those same 27-state cubes after the hidden quantizer. Two A8 code coordinates exactly identify each state; A4 needs at least three and has a six- or seven-coordinate witness. But every block's floating scale independently identifies the state as well, and all 136 scales vary. The small code witness does not make the max reductions or the downstream output free.

## Reproduction and custody

`trained.py`, `capacity.py` and `summarize_trained.py` live in this directory. The existing dataset owner remains `/path/to/workspace/data/kelana-ffn`; no new external state is created. Results retain source and dataset hashes, every fitted-region metric, collision witnesses and the capacity-bound dual witnesses. Output table hashes allow comparison on rerun; complete tables are regenerated rather than stored, since each context takes about 2.5 seconds on the CPU.

```
make trained
make test
```

The runner uses four BLAS threads and no GPU. NumPy joins the existing Python/SymPy dependencies. `trained-results/summary.md` is generated from the four per-context JSON records. The four cases are separate bounded invocations, so individual cases can also be run with `trained.py --layer 0 --anchor 0`.
