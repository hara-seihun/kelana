# Fit a smaller output-sign orbit alphabet

The frozen paid binary `mlp_up` factor occupies all 128 half-orbit labels in each eight-sign output chunk. I changed the signs rather than trying to prepare the same table selectively. A 96-label alphabet on each of the 48 rank chunks, followed by one complete teacher-response row fit, reaches held original-weight response RMS **.57862** at layer 14 versus **.58596** for the frozen paid image. Layer 0 moves the other way, **.66386 to .66867**. The same row fit without the alphabet cap reaches **.56500/.65443** at layers 14/0. The cap's quality cost relative to an equally fitted uncapped control is real; it is not a native speed result.

## Map and fitting contract

The paid image computes `h = V (x * scale_pre)` and `y_i = scale_post_i * sum_r U_ir h_r`, with signed one-bit `U,V`. This experiment keeps `V`, both scales, rank 384, the output factor's one-bit payload and the final response map. It changes only output `U` signs. For each consecutive eight-rank-coordinate chunk, quotient its signs by a global sign; the first sign remains stored, and the other seven define one of 128 orbit labels. Each chunk may use at most 112, 96 or 64 labels over all 3,072 rows. A cap of 128 is the equally fitted one-bit control. The alphabet is chunk-specific, not a single 96-pattern codebook for the whole matrix.

On 512 original-producer train inputs, compute the paid first-factor responses. A greedy deletion starts with 128 labels per chunk and repeatedly removes the representative with the smallest increase in *best fixed-alphabet local response squared error*, weighting old-label frequencies by the output scale squared. For a fixed live alphabet, choosing the nearest representative is optimal for this additive local surrogate. The deletion sequence itself is not globally optimal. It preserves each row's anchor sign. The first arm makes only those local assignments. Then one conditional row/block pass chooses, for each row and each chunk, its best currently allowed sign label against the **entire original-weight output** and the current other 47 chunks. The conditional choice is an exact squared-error minimum for that row and block, with the chosen alphabet and other blocks held fixed; one sweep is not a global optimum. It uses no validation input for fitting. The 128-cap arm receives the same teacher-response pass, which avoids crediting the smaller alphabet for a fitting budget denied to its control.

For label responses `R_c(t) = sum_{j=0}^7 s_j(c) h_{8b+j}(t)` and row anchor `a_i`, the update selects `argmin_c || (Y_i - current_i)/scale_post_i + a_i R_old - a_i R_c ||_2²`. This equation fits the composed output response, not a bitwise copy of the frozen signs. The search never expands weights to int4; `h` is a paid binary-factor response and sign labels are consumed as response-table addresses. CPU matrix multiplication is only the offline fitter and evaluator, not a claim about online inference.

## Held response and preparation bill

The held inputs are the first 128 rows of the pinned validation fixture, disjoint from the first 512 train rows. RMS is `||prediction - target||_F / ||target||_F` over all 128 by 3,072 outputs. The teacher is that fixture's FP32 original weight; the frozen target is its paid binary image, with both factors and both FP16 scales replayed in FP32. All these validation rows belong to the repeatedly inspected exploratory split, not a fresh model-loss or task set.

| Layer | Output alphabet | Local-only RMS vs frozen | Local-only RMS vs teacher | Teacher-refit RMS vs teacher | Refitted changed chunks / 147,456 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | frozen | 0 | .663862 | .663862 | 0 |
| 0 | 128 | 0 | .663862 | .654433 | 106,422 |
| 0 | 112 | .187218 | .677755 | .661678 | 108,530 |
| 0 | 96 | .277747 | .693940 | .668671 | 111,481 |
| 0 | 64 | .418995 | .730218 | not fitted | n/a |
| 14 | frozen | 0 | .585959 | .585959 | 0 |
| 14 | 128 | 0 | .585959 | .564999 | 95,943 |
| 14 | 112 | .150676 | .597457 | .571732 | 99,190 |
| 14 | 96 | .226001 | .612939 | .578619 | 103,707 |
| 14 | 64 | .345834 | .647334 | not fitted | n/a |

The row refit changes many signs: this is a new lossy factor image, not a small edit to the old numerical map. At cap 96, it uses all 96 allowed labels in every output chunk. Its output factor still stores **1,179,648 one-bit signs = 147,456 bytes**, alongside the unchanged paid first factor and scales. There is no extra per-weight label: the eight signs themselves identify their orbit. If a reader needs a compact 96-entry address, it also needs per-chunk routing; that metadata and online extraction have not been priced or implemented.

A regular half-orbit generator takes 127 Gray updates per eight-input table. Across both factors in this `mlp_up` map, 128 first-factor chunks plus 48 output chunks cost 22,352 Gray updates before the other setup. Even granting a free first response and one new response per scalar update, a 96-label output image could save **at most 48 × 32 = 1,536**, or **6.87%** of that two-factor preparation. The 112-label ceiling is 768, or 3.44%; 64 labels would permit at most 3,072, or 13.74%. These are optimistic preparation ceilings, not achieved reductions: needed labels may require unused intermediate Gray states, and compact address mapping, gathers, intermediate staging, row reductions and scales remain. The response-table approach has no demonstrated advantage over the direct packed-bitplane or partitioned-table consumers on gfx1151. Fitting output signs cannot reduce the paid first-factor work.

The evidence changes the next question. Pure nearest-orbit reassignment loses .0115–.0139 teacher RMS at cap 112 and .0270–.0301 at cap 96, while a complete-response refit recovers much of that cost. Yet cap 96 still gives up .01362/.01424 RMS to an equally fitted 128-label image on layers 14/0 for an ideal 6.87% *preparation-only* saving. Do not implement an irregular selective table for this frozen chunking on that promise. If an orbit restriction is to matter, co-train both factor images and a small **fixed, directly indexable** alphabet with the actual quantized-producer MLP endpoint, or redesign the native reader so the constrained alphabet saves recurring gather/reduction work, not just table setup. Compare its full two-factor time and held model loss against packed bitplane dots and the ordinary table before runtime adoption.

## Reproduction and custody

From Kelana's root, run `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-orbit-fit/fit.py 0` and the same command with `14`. Both are CPU jobs. `/path/to/workspace/data/kelana-subbit/binary-orbit-fit/layer{0,14}.json` contains source, paid-image and fixture hashes, all scores, output-code hashes and image paths. The adjacent `layer*-cap{128,112,96}-teacher-fit.npz` files retain the packed output factor, unchanged scales and the paid-parent hash; the parent NPZ retains `V` and rank dimensions. The code uses the parent original-weight and original-producer fixture. No GPU, Bonsai binary, resident service or serving default changed.
