# A saved matching dual is an all-cardinality rate certificate

The numerical witnesses were proposed for 32 disjoint input pairs. Their mathematical validity is not restricted to that cardinality. This is useful for the project lead's comparable-size objective: retain an error/resource function rather than treating one Q4 accuracy point as a universal threshold. It requires **no new fit, mode sweep or larger matching search**.

## The same witness bounds every number of pairs

The [full-covariance theorem](README.md) verifies every edge inequality

```
u_i + u_j + c <= pair_cost(i,j) / N,       u_i <= 0,
```

with a globally shared dual penalty P. Any matching containing m edges therefore gives

```
relative squared error >= L(m) := max(0, sum_i u_i + m*c - P/N).
```

The number 32 occurs only in the cardinality term. The PSD minorant, all pair cones, vertex-price signs and penalties stay unchanged. The `matching_charge` and `certified_disjoint_pair_floor` theorems in [`Kelana/PairCovarianceAssembly.lean`](../../../Kelana/PairCovarianceAssembly.lean) already use arbitrary `edges.length`; there is no 32-specific combinatorial premise.

Consequently the saved witnesses give, simultaneously for all integer `0<=m<=64`,

```
L_linear(m) = max(0, f_linear_32 + (m-32) * 230512366743 / 2^50),
L_affine(m) = max(0, f_affine_32 + (m-32) * 207445161319 / 2^50).
```

`f_linear_32` and `f_affine_32` are the exact rational floors in the respective [linear receipt](verified.json) and [centered affine receipt](../affine-pair-covariance/verified.json). Approximate slope/intercept forms are

```
linear: max(0, -.0007985519643410331 + .00020473610961513344*m),
affine: max(0, -.0007078533863451972 + .00018424831555474697*m).
```

Use the rational receipt and dyadic slope for a strict decision, not these displayed decimals. No spectral/optimizer statement at other cardinalities is needed: the already accepted edge inequalities prove the entire line. Several independently accepted witnesses could be combined by maximum, never by summing global error floors.

## One explicit payable reader family

To relate cardinality to bytes, declare rather than infer a representation. Consider a fixed 128-input/128-output reader with m disjoint pairs, `r=128-m` live carriers, b-bit affine scalar output codes (`1<=b<=4`), FP16 ratio per pair, and optional FP16 128-output intercept `a in {0,1}`:

* flat packed output codes: `128*r*b/8 = 16*b*(128-m)` bytes;
* one FP16 scale and origin per output row: 512 bytes;
* all pair endpoints and singleton source indices: 128 uint8 bytes;
* FP16 ratios: `2m` bytes;
* output intercept, when present: `256a` bytes;
* two self-description bytes: pair cardinality and bit-width/intercept flags.

The complete instance description in this declared grammar is

```
B(m,b,a) = 16*b*(128-m) + 640 + 2m + 256a + 2.
```

Flat cross-row bitpacking avoids uncharged row-alignment padding when r*b is not byte-aligned. Shapes and generic reader code are fixed for the comparison; changed generic code, prepared matrices/tables, input/output arrays and real native work belong in their own ledger. At `m=32,b=4`, these self-describing descriptions are 6,850/7,106 bytes, **two bytes more** than the earlier fixed-shape/fixed-cardinality 6,848/7,104-byte images. This report does not retroactively add bytes to their distinct fixed grammar or pretend a variable-cardinality reader has free parameters.

For a fixed b and a, write `B0=2048b+642+256a`. A budget B permits only

```
m >= ceil((B0-B)/(16b-2)),  clipped to the interval 0..64.
```

If the required m exceeds 64, that declared grammar has no image within B. The accepted slopes are positive, so the corresponding L(m_min) is a universal lower bound on response error for every budget-feasible image **within that fixed b/a reader family**. This is a source-independent size implication plus the source-specific error certificate, not an inference-speed estimate.

The online scalar ledger is `128*(128-m)` output coefficient contributions, m input multiplications and m input additions, plus `128a` output additions. These unlike operations are not added into a claimed native speedup. Changing m also changes intermediate residency, code loads and preparation.

## Why this is not yet a joint quantization frontier oracle

The covariance floor grants an **unrestricted real** output readout. It therefore ignores b-bit output-grid distortion even though B pays for the grid. If the search may freely lower b, a cheap m=0 output matrix can fit the byte budget while the relaxed real readout returns error zero. Minimizing these envelopes over b can thus be vacuous. One cannot cure that by substituting the observed error of a selected b-bit fit as a universal floor.

A useful joint bound must retain enough of the **paid output-code constraints** along with input covariance, just as the earlier projection/grid bounds did in their finite grammar. This is the next mathematical dependency, not a request to enumerate larger m. Meanwhile each saved line remains valid for a named fixed-cardinality/bit-width family and any achieved comparable-size control. The [exact QuIP budget comparison](../quip-e8p-local/BUDGET.md) now excludes matching an actual 6,178-byte structured image's ideal captured-train error for every budget-feasible Q4-readout pair count (with shared generic reader assets). Q3/lower readouts remain unsettled. The [paid-grid sidecar](../paid-grid-floor/README.md) adds a sound unmatched-coordinate code charge at m=32, but its .0000009378994 increment does not settle the distinct 6,848-byte [matched-rate comparison](../matched-rate-frontier/README.md).

These are captured-train error bounds with the original full response norm. They do not become held-state, complete-attention, SOTA or native-work claims by being plotted against bytes. The affine 7,104-byte comparison is already a valid captured-train-error statement against one local equal-byte control; the 6,848-byte point and the broader execution frontier remain separate questions.
