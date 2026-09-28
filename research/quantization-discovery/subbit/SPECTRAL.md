# Rank and precision are joint quantization choices

A useful sub-bit representation need not use one-bit coefficients. A small pair of four-bit matrices can cost less than one bit per original matrix entry, preserve more useful response directions than FP16 factors, and perform far fewer arithmetic terms than a wide binary factorization. The first early-Qwen projection gives a concrete point worth a native consumer. It does not win across the model.

## The map and its conditional optimum

Let the known weight matrix be `W`, with shape `N×K`, and calibration activations be `X`, with shape `M×K`. Form `Y=X Wᵀ`. If `U` contains the first `r` right singular vectors of `Y`, store two factors

```
A = U,       B = Uᵀ W,       inference(x) = A (B x).
```

This attains the minimum calibration-response squared error among rank-at-most-`r` linear weight maps in exact arithmetic. Any such map produces a rank-at-most-`r` response matrix, so Eckart-Young bounds its residual by the squared singular-value tail of `Y`. The displayed construction attains that bound because `X Bᵀ Aᵀ = Y U Uᵀ`. No covariance inversion or recovery of individual weights is required online.

That optimum says nothing about held-out inputs, rounded factors, native time, or the best representation family. An affine variant centers `Y` and pays for an output bias. `spectral.py` measures both with FP16 factors. At early Q, rank 23 fits exactly .5390625 matrix BPW and gives .10287 held-out relative squared response error. The matched rank-352 binary control gives .09666. Narrow FP16 nearly matches it with 70,656 FMA terms instead of 1,081,344 signed terms. On middle-layer down and late Q, narrow FP16 gives .69633 and .16439 and loses clearly.

`spectral_quant.py` trades coefficient precision against rank. It tests factor precisions 2, 3, 4, 8 and 16, including asymmetric pairs, at three fixed payload budgets. Low-bit factors use an odd signed grid with `2^b` values, a paid FP16 scale per row and up to 128 columns, and genuinely bitpacked row-major codes. The four-bit map is `(2*code-15)*scale`. Each factor has a paid 16-byte shape/precision/group descriptor. Partial groups do not store padded coefficients. The `.npz` container bytes are reported separately.

For each rank, the two factors may share a diagonal change of coordinates. Multiplying column `j` of `A` by a positive value and dividing row `j` of `B` by it preserves the unquantized map. We test no balancing and square-root balancing of the input-factor row norms. Quantizing the balanced factors changes their error substantially. After rounding `A`, a least-squares projection `B=(AᵀA)⁻¹AᵀW` repairs the input factor before its own quantization. The small solve has `1e-8` diagonal regularization. All scores use the packed codes and rounded scales, not latent floating factors.

The empirical response metric also has a fixed shrinkage arm. It replaces the empirical second moment by `0.6 Σ_empirical + 0.4 D`, where `D` is diagonal and itself mixes each train channel's second moment with 40% of the channel mean. An augmented response SVD realizes that metric. This tests whether a little weight-space information helps directions underrepresented by eight calibration windows. The singular-value tail for that arm belongs to this surrogate, not to pure calibration loss.

## Matched projection results

All three matrices use the existing 2,048 train and 1,024 validation activation fixtures. All known weight rows are available. Within each target budget and covariance arm, the factor precision, balance and rank are selected by training response error. Validation selects nothing in these tables. `spectral-results.json` retains every arm, artifact hash, payload and container bytes, source hash, and factor work count.

The unshrunk results use relative squared response error, matching the NanoQuant ADMM-only comparator. They are not RMS errors or perplexities.

| Matrix | Factor precision A/B | Rank | Factor payload BPW | Factor validation error | Binary payload BPW | Binary validation error |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Layer 0 Q | 4/4 | 88 | .53674 | **.08145** | .53906 | .09666 |
| Layer 0 Q | 4/4 | 120 | .72620 | .07595 | .77344 | **.07368** |
| Layer 0 Q | 4/4 | 152 | .93127 | .07014 | .96094 | **.06025** |
| Layer 14 down | 4/2 | 144 | .49683 | .48336 | .52083 | **.44383** |
| Layer 14 down | 4/2 | 224 | .76701 | .39898 | .77083 | **.31712** |
| Layer 14 down | 3/3 | 240 | .97729 | .34819 | .97917 | **.24136** |
| Layer 27 Q | 4/4 | 88 | .53674 | .12613 | .53906 | **.11579** |
| Layer 27 Q | 4/4 | 120 | .72620 | .11555 | .77344 | **.08859** |
| Layer 27 Q | 4/4 | 152 | .93127 | .10491 | .96094 | **.07104** |

The early-Q low-rate point reduces squared response error by 15.7% at slightly fewer payload bytes. Four-bit factors beat both wider two-bit and narrower eight-bit factors under this budget. The grouping overhead creates rank steps, so some chosen points do not spend the whole allowed budget.

The fixed covariance-shrinkage arm keeps the same selected precision/rank combinations. Its errors at increasing budgets are .08103/.07482/.06876 for early Q, .47882/.39113/.33461 for down, and .12391/.11261/.10217 for late Q. It improves held-out responses but does not reverse the down/late-Q comparison. Late-Q training error at rank 88 is .07175 while validation error is .12613. Calibration coverage and the downstream consumer deserve more work than another claim based on training fit.

The binary comparator is the pinned [ADMM-only adaptation](binary-factors/README.md), not the complete published NanoQuant calibration and reconstruction-training pipeline. Its rate includes packed signs and FP16 scales but excludes its 12-byte shape array. Our displayed factor rate includes both 16-byte descriptors. This tiny accounting difference favors neither a hidden factor expansion nor a free scale.

## Equal output-coordinate refinement strengthens the binary control

The later [pattern-factor study](block-factor/README.md) gives binary factors four coordinate sweeps over output signs and response scales. Its early/late Q errors fall to .06962/.10438 without additional stored bits. Comparing only against ADMM initialization would now hide the strongest available control.

`spectral_refine.py` gives each small multilevel candidate four analogous sweeps. With the input factor fixed, each output coefficient chooses the nearest allowed odd-grid value to its conditional train-response quadratic optimum. FP16 group scales then minimize the residual against all other groups. The program packs the resulting image and selects the precision/rank arm on training error. Early Q retains rank 88 with four-bit factors and improves .08145 to .07610 at the same .53674 BPW. Late Q selects rank 104 with four/two-bit factors and reaches .12165 at .52991 BPW. Both still lose to the equally refined binary control on raw projection error.

The complete-model early-Q continuation confirms that more MSE fitting is not the answer by itself: its test NLL changes from 3.34965 to 3.34997 and teacher KL worsens from .06642 to .06776. The strong binary control gives 3.34220 and .05987. This led to the [attention-consumer fit](attention-metric/README.md), which changes the same paid codes for a different objective. [RESULTS.md](RESULTS.md) owns that later whole-model continuation and exact-image native panel. `programme-results.json` includes the refinement and continuation receipts.

## Calibration-size curve at a frozen rate and family

`calibration_curve.py` freezes the rank, factor precision, balancing and group size before varying calibration coverage. Three seeded permutations choose nested sets of 1, 2, 4 and 8 complete 256-token training windows. Validation remains the same 1,024 separate inputs. The eight-window point is one shared fit, not three independent repetitions. Medians below summarize the three nested subset curves; `calibration-results.json` retains each curve and its image hash.

| Train vectors | Early Q | Early Q, shrinkage | Late Q | Late Q, shrinkage | Down 14 | Down 14, shrinkage |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 256 | .10169 | .09751 | .17569 | .15577 | .60447 | .57674 |
| 512 | .09053 | .08872 | .15661 | .14591 | .55448 | .53205 |
| 1,024 | .08577 | .08462 | .13483 | .13006 | .51040 | .49401 |
| 2,048 | .08145 | .08103 | .12613 | .12391 | .48336 | .47882 |

These are actual calibration-size curves at fixed payload, not a scaling law across model sizes. Shrinkage helps most when observations are sparse. More calibration improves all three families, but the late-Q and down projections still lose the binary comparator at the largest measured set. The next useful extrapolation requires additional data and model sizes, rather than fitting a universal exponent to four means.

## Complete-model continuation of the early-Q point

`continuation.py` replaces only layer-0 Q in the original BF16 model, then runs the unchanged remaining model. It compares reference, the unshrunk rank-88 factors, the matched NanoQuant image, and a least-squares scalar four-bit control. Factors are multiplied offline in FP32 and rounded once into a dense BF16 projection for this quality experiment. Its timing is not compressed inference time.

The fixed validation and test splits each contain four 256-token windows and 1,020 next-token predictions. These are the same small-window pilot tokens, not full-corpus WikiText perplexity. Nothing was fitted on their test tokens.

| Replaced projection | Matrix BPW including shape data | Validation NLL | Test NLL | Test perplexity | Test KL from reference | Test argmax agreement |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Original BF16 | 16 | 3.90522 | 3.31076 | 27.4059 | 0 | 100% |
| Rank-88 four-bit factors | .53674 | 3.95265 | 3.34965 | 28.4928 | .06642 | 90.88% |
| NanoQuant ADMM-only | .53911 | 3.95406 | 3.35566 | 28.6647 | .05836 | 92.06% |
| Scalar four-bit LS | 4.12506 | 3.90532 | 3.30800 | 27.3304 | .00225 | 98.24% |

The factorized point slightly lowers pilot NLL versus the binary comparator, but has worse teacher-distribution KL and token agreement. The response-error gain is not a uniform quality gain after Q normalization and attention. Scalar four-bit is much closer to the original model and costs about 7.7 times the projection bytes. This is a useful rate/quality comparison, not a quality-matched int4 win.

Only 2,097,152 of 596,049,920 unique parameters change. The mixed model still costs about 15.9456 logical bits per unique parameter. It is **not a sub-bit whole model**. `continuation-results.json` retains per-window values and exact image hashes; the raw wrapper log is under `/path/to/workspace/data/kelana-subbit/continuation/`.

## Asymmetric precision after attention fitting

[The Q-head radial-gauge study](attention-radial/README.md) keeps the rank-88 four-bit right factor and retunes only the left codes and paid scales at three or two bits. The three/four-bit image costs .45081 matrix BPW and has .09242 held attention KL against .07776 for the .53674-BPW four/four-bit image; the two/four-bit image costs .36487 BPW and has .11290 KL. A positive per-head gain chosen on train raw responses reduces the three-bit image's raw held error from 1.20210 to .19304 without new bytes and barely changes its attention response. This is the RMSNorm radial gauge, subject to epsilon and BF16 rounding, not a matched-quality win or a native speed receipt. [The fixed-right-basis rank study](factor-rate-grammar/README.md) answers the first higher-rank question: rank 108 is the exact maximum in this row-packed format at the three/four-bit image's byte cap. Fitting its left codes on the spectral seed yields held attention KL .20130 against .19934 for rank 88 of the same seed, both far worse than .11290 for the attention-trained rank-88 two/four-bit image. More rank without a consumer-fitted right basis is not the next native kernel candidate.

## Online work and next experiments

The rank-88 image contains 90,112 left-factor code bytes, 45,056 right-factor code bytes, 4,096 plus 1,408 scale bytes, and 32 descriptor bytes. Total is 140,704 bytes. It evaluates `88×1024 + 2048×88 = 270,336` factor terms, one quarter of the matched binary factor's signed terms. Padding the rank to a 16-wide matrix tile raises that to 294,912. A straightforward two-pass consumer also materializes an 88-element intermediate and incurs two launches. Code extraction, per-group scale reductions, activation precision and the boundary between factors remain real costs.

The dense original projection has 2,097,152 terms. Expanding the compact map into a full int4 matrix would throw away its factorization and generally round it again. The [native panel](native-factors/README.md) measures all of those routes. At one query the packed two-factor path takes 13.12 µs versus 20.34 µs for an expanded dense FP16 wave dot and 16.86 µs for the full-matrix int4 control. Both factor launches and the intermediate are included. At 16 queries, 63.39 µs packed loses to 37.93 µs for two BLAS calls on expanded FP16 factors. The int4 control requantizes the factor map, adding .001173 relative squared output error on its 16 rows. These are cache-resident paired microbenchmarks under recorded host/package-power contention, not whole-model or quiet-host throughput. The subsequent [paired binary-factor panel](native-factors/NANO.md) measures the original spectral seed at 11.03 versus 12.17 µs for the actual ADMM image at one query, and 53.24 versus 93.00 µs at sixteen. It uses comparable direct wave consumers, while NanoQuant can also consume its signs by lookup or matrix instructions. [RESULTS.md](RESULTS.md) records the final attention-fitted images at 1.114x and 1.725x paired speedups against the stronger response-fitted binary image.

The [spectral/binary residual study](spectral-residual/README.md) found that part of its apparent improvement came from refitting output scales at no extra rate. Giving binary-only factors the same response-scale fit improves every .55-bit matrix. The hybrid beats that fairer control on 8 of 16 matrices, so its real modes earn their bits in specific places rather than everywhere. Pattern-coded input factors are exploring a different capacity/work trade. The tied embedding/head needs its own data and rate allocation. An attention-aware fit now targets Q normalization and its actual consumer rather than raw projection MSE. There is no reason to force one alphabet or one precision on the entire network.

## Reproduce

Run CPU fits through the existing read-only PyTorch environment. For the down projection use the exact comparator budgets `.5208333333333334 .7708333333333334 .9791666666666666`.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit
F=/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext
$P "$D/spectral.py" --fixture "$F/layer00-self_attn_q_proj.npz"
$P "$D/spectral_quant.py" --fixture "$F/layer00-self_attn_q_proj.npz" --refit
$P "$D/spectral_quant.py" --fixture "$F/layer00-self_attn_q_proj.npz" --refit --covariance-shrinkage .4
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 50s --exec "$P" "$D/continuation.py"
```

Source commit `2047235` preserves the first unshrunk fit programs. Subsequent source hashes in the receipts identify the covariance extension and continuation. Data images live under `spectral/`, `spectral-quant/`, `spectral-refine/`, `calibration-curve/`, and `continuation/` in the programme data directory. No serving default changed.
