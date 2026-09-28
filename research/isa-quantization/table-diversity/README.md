# Table diversity on a model-derived nonlinear consumer

**Decision:** Reject the square-cell producer for this local Qwen family. Its native hot-table result does not transfer: a fixed eight-cell square response loses to the fixed **uniform** eight-cell table on 982/1,024 model-derived tiles at exactly the same table bytes, and to the searched affine producer on 990. More importantly, a direct eight-coefficient scalar polynomial stores **16 bytes per tile** and reaches .00374 aggregate relative RMS, against .20928 for the 64-byte square table. The 256-byte direct table reaches .00205 and remains an accuracy point, but is **not an obvious rate/accuracy winner** once a strong source-independent arithmetic control participates. Neither polynomial execution speed nor full-model quality was measured; do not launch a larger square-table GPU timing for this region.

## Complete local response and producer domain

Use the actual BF16 Qwen3-0.6B layer-0 gate, up and down matrices, all **3,072 hidden channels**, and the captured teacher-produced input vectors at train positions 320/384 and validation positions 576/640. Keep all but two input coordinates fixed at one captured anchor. The sixteen varied coordinates are selected by highest standard deviation over the *first 1,024 training inputs*; each coordinate's second varied input is the next coordinate in this ordered list. For an anchor `a`, coordinate pair `(k,h)`, code `x=0..31`, and four live `t` values `{-1.5,-.5,.5,1.5}`:

```
input = a + 2*std[k]*(x-15.5)/15.5 * e_k + .5*std[h]*t * e_h
F_o(x,t) = sum_{j=0}^{3071} down[o,j] * SiLU((gate*input)[j]) * (up*input)[j]
```

Observe original down outputs `o=0..15`. This is a **complete nonlinear MLP response over these 16 outputs and the declared two-coordinate domain**; no intermediate gate/up tensors are required of any candidate. It is not a complete 1,024-output MLP or a prevalence estimate for actual 5-bit activation traffic: the 32×4 grid is a designed perturbation around four actual input states, not an observed producer histogram. The remaining input coordinates and down outputs are intentionally outside the replacement region. If four anchor-specific maps were actually deployed, obtaining the anchor identity and the 5-bit x/t codes from upstream would have to be paid; here they are identical input contracts for every arm, not a free full-model encoder.

Each `(anchor,k,output)` is a tile: 4×16×16 = **1,024 independent model-specific response descriptions**. Relative RMS divides each tile's squared error on all 128 `(x,t)` states by that tile's centered response energy; aggregate combines all tile errors and energies before taking a square root. Each eight/32-cell table fits the best degree-two `t` response at every cell and rounds three labels to FP16; each aligned row pays two padding bytes, for 64/256 bytes per tile. The `t` least-squares residual is paid by both. The searched affine family is the 797 distinct partitions from the prior study, selected **separately per tile**; its chosen `(a,b,s)` is not a shared free immediate. Uniform uses `x>>2`, square `(x*x)>>7`, and direct uses `x`. An equally sized 32×4 *literal output* table instead stores one FP16 response for each `(x,t)` pair, with a two-bit `t` code. It does not need to preserve polynomial coefficients or execute the quadratic consumer. The `t` code exists only on this finite four-value domain.

Two conventional scalar arithmetic controls fit complete response directly, not source gate/up weights. Their shared basis uses normalized `z=(x-15.5)/15.5` and the live `t`. The 8-field version stores FP16 coefficients of `1,t,t²,z,zt,zt²,z²,z³` (16 bytes/tile). The 15-field version stores all `z^a t^b`, `0≤a≤4, 0≤b≤2` (30 bytes/tile). They evaluate the polynomial from their stored FP16 coefficients; there is no lookup table. Fitting is all-grid FP64 least squares, followed by FP16 rounding **before** error scoring. This favors no lookup geometry but requires more online arithmetic than a direct fetch. All arms consume the same x/t values and produce the same scalar output.

## Measured description/error frontier

[`results.json`](results.json) contains the source hashes, selected coordinates, all scores and template statistics. Values below are aggregate relative RMS; the results file also gives per-tile median and 90th percentile.

| Complete endpoint arm | Stored tile fields | 1,024-tile fields | Aggregate relative RMS |
| --- | ---: | ---: | ---: |
| square8 table | 64 B | 65,536 B | .20928 |
| uniform8 table, no tuned producer | 64 B | 65,536 B | .11099 |
| searched affine8 table | 64 B + 3 B program | 68,608 B | .11021 |
| polynomial8 | 16 B | 16,384 B | .00374 |
| polynomial15 | 30 B | 30,720 B | .00241 |
| direct32 quadratic table | 256 B | 262,144 B | .00205 |
| direct32×4 literal FP16 output table | 256 B | 262,144 B | .00206 |

A fixed layout addresses tiles as `(anchor*16+k)*16+o`, so no per-tile pointer array is needed; the table reader still computes that address and fetches its response. The affine grid's winning programs comprise **20 distinct `(a,b,s)` triples**; 314 tiles need a nonzero bias. All fitted `a,b,s` fit in three uint8 fields (3,072 additional bytes). A specialized code path for each triple instead needs a code-union charge and dispatch. The table total alone is **not** its complete paid description. Uniform/square/direct/polynomial have fixed reader structures whose code is shared once, with model-specific FP16 fields stored rather than hidden in instruction text.

For a standalone four-anchor fixture, also charge common input-context fields: four BF16 anchor vectors of length 1,024 (8,192 bytes), sixteen uint16 coordinate IDs (32 bytes) and sixteen FP16 input standard deviations (32 bytes), **8,256 bytes common to every arm**. The second coordinate is the deterministic successor in the ID list; x and t step factors are fixed constants. This makes the square, uniform, polynomial8 and direct quadratic descriptions 73,792, 73,792, 24,640 and 270,400 bytes respectively, before each generic reader's executable code. Live anchor identification, input quantization, output dispatch, remaining model tensors and full-model behavior are **not** included in those totals; this is not a model-compression claim. In a live layer the anchor is dynamic state rather than necessarily stored model data, but it is never free to select a response table without it.

## What is shared

Every one of the 1,024 FP16 square tables is **bitwise distinct**. This does *not* imply an inability to reuse normalized shapes: after removing a scalar mean and gain, a held table's nearest training table has median absolute cosine .99916 and tenth percentile .99429. Those are shape statistics, not an executable compression gain.

As a concrete paid reuse control, select K training tables by farthest normalized response shape, store K full 64-byte FP16 templates, and for **each** tile store a selector (one byte for K≤256, two for K=512), FP16 gain and FP16 offset. Fit each held tile's gain, offset and selector to its full response; round the fields before scoring. The K=512 image costs 32,768 template bytes plus 6,144 tile-metadata bytes = **38,912** (47,168 with the common anchor description), versus 65,536 for private square tables. It scores .21753 held aggregate relative RMS, **worse** than individually fitted square's .21327 on the same 512 held tiles. K=8/32/128 score .41147/.27558/.22801 on held, respectively. This is a deterministic dictionary screen, not an optimal dictionary lower bound. It does establish that a high shape cosine alone does not recover the original fidelity using this FP16 affine-template reader. Its runtime additionally requires selector decoding, indirect template access and gain/offset arithmetic. Polynomial8 is both smaller and far more accurate on this restricted domain without those accesses.

The most discriminating *next* native workload, if real producer traffic first confirms this domain, is **polynomial8 versus the 256-byte direct table**, across many naturally diverse tables while all 16 output rows share the x/t input. Price coefficient evaluation, model-specific fields, cache residency, anchor selection and actual input-code preparation; do not benchmark square versus direct by merely increasing element count. The present CPU evidence already rejects square for this family, not ISA-shaped partitions generally.

## Reproduce

From this directory, with one BLAS thread and the existing model/capture (no download or GPU):

```sh
for anchor in 0 1 2 3; do
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python screen.py --anchor "$anchor"
done
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python screen.py --summarize
```

Each anchor computation completes well below one minute. The intermediate `anchor-*.npz` responses are local regeneration artifacts, ignored by Git; only the compact summary is committed. The model/capture hashes in the receipt bind the external immutable inputs. Numerical outputs are FP64 evaluation of BF16 source matrices and input states followed by declared FP16 candidate fields, not bitwise GPU MLP output or a complete sequence-level model check.
