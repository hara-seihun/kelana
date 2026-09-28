# Complete sub-bit Qwen images

We now have complete packed Qwen3-0.6B images, including all 196 body matrices, the tied embedding/head, norms and descriptors. The first image costs **46,532,412 payload bytes, .624544 bits per unique parameter**. It is genuinely sub-bit in storage, but it does not retain useful language quality. Independent matrix fits collapse when composed across 28 layers. Four response-coordinate sweeps help substantially; an eight-window end-to-end scale fit helps again. Neither closes the gap to the original model.

The distinction matters. We have a local quantizer with a measured direct GPU advantage, and complete compressed images whose quality remains poor. We do not yet have a good sub-bit model or a compressed full-model runtime speedup. [Fresh prefix substitutions](PREFIX-ABLATION.md) locate a large causal part of the damaged prefix at layer 0: restoring it alone lowers 16-window NLL from 13.014 to 7.626, but paying BF16 for it would add .40830 complete-model BPW. [Frozen narrow V/O substitution inside that quantized prefix](NARROW-PREFIX.md) lowers test NLL by 0.758–0.910 at equal or lower V/O bytes, but rank-28 and 192-coordinate images reverse their ranking across test and validation. [Paired layer-0 V/O and MLP substitutions](COUPLED-SUBSTITUTION.md) now measure the interaction: frozen narrow V/O plus original MLP scores 10.579 test / 8.819 validation NLL, while original V/O plus original MLP scores 6.804 / 7.746. Binary Q/K with original V/O and MLP is within .097 / .080 nats of the whole original layer, saving .08161 whole-model BPW against full restoration. [Splitting the exact MLP repair](MLP-SPLIT.md) shows that none of its one- or two-projection subsets approaches the complete repair on both held splits. A compressed joint V/O-to-MLP fit remains open; neither exact MLP nor exact V/O is a sub-bit solution. [The coefficient-truncated correction of the frozen binary MLP](MLP-FACTOR-RESPONSE.md) spends 67,584 extra bytes at rank 8 yet lowers held original-producer post-MLP squared error only .65752 to .65214; its rank 32 overfits. [Covariance-aware reduced-rank ridge](REDUCED-RANK-RESPONSE.md) on the same data instead scores .61904 held at rank 32 and 2,048 training positions, against .66098 for coefficient truncation. This is a paid response gain, not model loss or a native speedup. [Joint refitting of existing gate/up/down output scales](MLP-SCALE-FIT.md) lowers the same held post-MLP error from .65752 to .63294 at zero incremental payload or online work. [Training the already-paid gate/up input scales too](MLP-INPUT-SCALE.md) reaches .62089 on the same 2,048-row train and 1,024-row held captures. That is close to the paid rank-32 correction's .61904 without its 264,192 extra bytes and factor terms. [Refitting on the actual quantized narrow-V/O producer](MLP-QUANTIZED-SCALE.md) lowers held layer-0 endpoint-response error .85875 to .83064 with the same paid scales. It improves six-window test NLL 12.14876 to 11.56619, but loses eight-window validation NLL to the prior original-producer fit, 11.29725 versus 11.21059. Response fit is not a reliable selection rule here. [Refitting the down output signs on that damaged producer](MLP-QUANTIZED-CODES.md) lowers held endpoint error .83064 to .82140 at unchanged 614,436-byte MLP payload, but **worsens** six-window test NLL 11.56619 to 11.83990 while improving eight-window validation NLL 11.29725 to 11.21527. A stronger local response fit is not a reliable image selector. [Stopping after one down-sign sweep](DOWN-SWEEP-SELECTION.md) improves the held endpoint error further to .81920 and lowers the two-sweep test NLL 11.83990 to 11.61623, but still loses to the scale-only 11.56619 on six matched test windows; eight validation windows favor two sweeps. [A common gain chosen on six train gold-loss windows](GOLD-DOWN-GAIN.md) changes only the already-paid FP16 down output scales. At identical 614,436-byte MLP payload and online factor work, it lowers 18 later test-window NLL 11.32575 to 9.54966 and eight validation-window NLL 11.29725 to 9.29478. This fixes a large part of the response-fit selection error, but the model is still badly damaged. Fit coupled MLP and V/O paid coordinates on independent train text before choosing a native image. [Propagating the two train-selected paid gains into the actual complete image](COMPLETE-GAIN-TRANSFER.md) changes the selection: on four test windows the .624513-BPW complete base/joint images score 9.15036/9.16755 NLL, although the same gains dramatically improve the frozen original-downstream prefix. Fit against the quantized tied producer and later layers together; the original-downstream prefix is not a reliable image selector. [Selecting nine paid down/O gain pairs on the complete model](COMPLETE-PAID-GAIN.md) fixes that boundary but chooses 2/1.5, which loses to the prior 2/1.75 on independent eight-window test and validation panels. [The exact gold-label window oracle over three frozen gains](gain-validation/README.md) can lower the same test NLL only from 9.416896 to 9.150627, even though it chooses an arm after seeing every answer. Common frozen gains are not enough; change jointly learned codes against the composed loss.

## Same model, actual complete images

The source is pinned Qwen3-0.6B, revision `c1899de289a04d12100db370d81485cdf75e47ca`, with 596,049,920 unique parameters. `capture.py` runs the original BF16 model on eight train and four validation windows. It records shared Q/K/V, attention-output, gate/up and down input tensors for every layer as actual BF16 bit patterns. Q/K/V and gate/up inputs are not needlessly duplicated. `prepare.py` derives the same 0.4-shrunk squared input-channel moments used by the earlier comparator; output moments remain uniform ones.

The [batched initializer](../batched-fit/README.md) fitted all 196 matrices with 400 ADMM iterations and five power iterations per projection step. It used 284.49 GPU solve seconds across 14 bounded reservations. A sixteen-matrix Cholesky allocation failure led to an owning-layer repair: the fitter now processes chunks of eight, retaining each completed chunk. The failed invocation and the successful recovery have separate source and run receipts. These are NanoQuant-derived initializer images, not a reproduction of its full gradient calibration, block reconstruction and model KD.

`image.py` assembles each complete image. Binary U/V planes, FP16 input/output scales and dimensions are stored per body matrix. The shared tied image uses the [mixed codebook/exact/RTN4 construction](../tied-factors/README.md). Norms retain their BF16 bit patterns. The package includes the model config, a complete manifest and hashes. Input embeddings and output logits use the same paid tied image. Two stored FP32 constants apply a head-only correction to the remaining codebook rows; they do not change input embeddings.

| Image | Payload bytes | Payload BPW | All package files, bytes | Package BPW |
| --- | ---: | ---: | ---: | ---: |
| ADMM initializer | 46,532,412 | .624544 | 46,878,985 | .629195 |
| Four response sweeps | 46,532,412 | .624544 | 46,879,097 | .629197 |
| Centered response fit plus paid biases | 47,220,540 | .633780 | 47,614,251 | .639064 |

Payload includes dimensions, scale arrays, all codebook and exact-row data, head correction and norms. Package rate additionally counts NPZ headers, config and the source-bearing manifest. Neither rate counts runtime scratch or KV as weights. The unique tied matrix is counted once, rather than counting both checkpoint aliases. All packages and hashes are recorded in [results.json](results.json) and `/path/to/workspace/data/kelana-subbit/full-model/`.

## Fit response geometry, then measure composition

For a binary image, let `Z = (X D_pre) V^T`, with prediction `Z U^T D_post`. `refine.py` uses the strong control's four output-sign coordinate sweeps. It computes the full training feature Gram matrix and target cross-products, chooses each output sign against the current residual, then refits and rounds each existing output scale. V and input scales remain fixed. This costs no additional image bytes.

The affine variant fits the same codes on centered training inputs. For mean input `mu`, it also stores `b = W mu - Wq mu`, rounded to FP16. This is the least-squares intercept for fixed Wq before rounding. It costs 688,128 additional bytes and one output add per body channel. It is an explicit affine approximation on the observed activation distribution, not an exact replacement for the original linear map. Its held model results split by corpus window; it is not a uniform improvement.

`evaluate.py` expands each saved body image to FP32, then rounds its dense weight to BF16 for a common model-quality forward. It actually feeds quantized embeddings into the transformer and applies the quantized output head. This is **not a compressed-runtime timing**. Each split is the original four 256-token pilot windows, 1,020 predictions. Train, validation and test are separate, but these repeatedly inspected pilot windows are exploratory, not a new blind evaluation.

| Complete model | Total payload BPW | Validation NLL | Test NLL | Test teacher KL |
| --- | ---: | ---: | ---: | ---: |
| Original BF16 | 16 | 3.90522 | 3.31076 | 0 |
| Binary initializer plus mixed tied image | .62454 | 16.70403 | 14.94775 | 12.21749 |
| Four response sweeps, same bytes | .62454 | 9.31067 | 9.65603 | 6.98149 |
| Centered response sweeps plus FP16 biases | .63378 | 9.46266 | 9.23832 | 6.62170 |
| [Eight-window end-to-end scale repair](../model-tuning/README.md) | .62454 | 9.09895 | 9.11738 | 6.381 |
| [FP16 response residual, rank 8](../model-residual/README.md) | .76000 | 9.30518 | 9.72919 | 7.04433 |
| FP16 response residual, rank 16 | .89546 | 9.48939 | 9.84258 | 7.19636 |
| [Scalar group-128 LS, two-bit](../full-scalar/README.md) | 2.12657 | 15.41435 | 15.55316 | 13.3332 |
| [Scalar group-128 LS, four-bit](../full-scalar/README.md) | 4.12635 | 4.86962 | 4.05740 | .79670 |

The rank-8 and rank-16 residuals improve held-out original-producer response error on every matrix, but worsen complete-model test NLL. Their median local errors are .226669 and .221202 versus .232794 for the base. Their complete payloads are 56,624,956 and 66,717,500 bytes. This is a measured failure of the local selection rule, not a reason to build its extra kernels.

The .625-bit image beats this two-bit scalar control because both are badly damaged, not because sub-bit language inference is solved. The four-bit scalar image is much better. Neither scalar control is GPTQ, QuIP#, or a strong reconstructed quantizer. Complete-model quality still does not support a state-of-the-art claim.

The [scale repair](../model-tuning/README.md) changes only the 344,064 existing FP16 output-factor scales. It trains through the quantized body on original final hidden targets from the eight train windows, then merges gains into the packed image and runs the held model again. Its half-nat test recovery leaves a 5.81-nat gap. More iterations of the same local scale repair are not the first priority.

## The tied consumers change the ranking

Here the body remains original. Exact-row and mixed-row head images are compared through the complete transformer, first with only one consumer changed and then with both changed.

| Changed consumer | Exact-row image test / validation NLL | Mixed-row image test / validation NLL |
| --- | ---: | ---: |
| Output head only | 4.20097 / 4.63365 | 4.24237 / 4.68416 |
| Input embedding only | 3.75689 / 4.54598 | 3.73369 / 4.45704 |
| Shared input embedding and output head | 4.36930 / 4.98173 | **4.32659 / 4.96719** |

The .893824-bit mixed tied image loses on head-only NLL but wins when both tied consumers use it. Selecting only on fixed final hidden inputs would have picked the worse shared image here. This is direct evidence for a joint-consumer objective.

A head-only diagnostic retains the original BF16 input embedding and a separate compressed head. It therefore costs about **16.2337 whole-model BPW**, not 12.0573. The lower rate applies when the compressed image actually replaces both tied consumers. The evaluator prices these distinct cases rather than assigning shared storage to two different numerical matrices.

## Errors are not additive across module families

These ablations use the four-sweep body images and retain the original tied matrix. Unchanged body matrices remain BF16.

| Quantized body subset | Whole mixed-model BPW | Validation NLL | Test NLL |
| --- | ---: | ---: | ---: |
| Q and K only | 13.71491 | 4.71921 | 4.28392 |
| V and O only | 13.71491 | 8.11287 | 8.12018 |
| All attention projections | 11.42981 | 8.28938 | 8.32795 |
| All MLP projections | 9.13778 | 11.86538 | 11.53544 |
| All body projections | 4.56760 | 9.21919 | 9.44595 |

V/O deserves a composed-map study: it damages the model far more than Q/K at the same partial rate. MLP-only is worse than quantizing every body matrix. That non-monotonic result rules out adding independent projection penalties as a faithful complete-model loss estimator on these images. Changed producers alter the inputs seen by later quantized consumers; cancellation can make a more compressed model look less damaged without making it good.

## Online cost and next constructions

The 196 binary body programs have 222,035,968 signed factor terms per query, 66,304 total intermediate coordinates and 630,784 pre/post channel scales. Their minimum FP32 intermediate write-plus-read is 530,432 bytes per query before scheduling and fusion. The signed term count is about half the original body coefficient count, but it is not a GPU throughput estimate. Packed extraction, scale multiplication, reductions, launches and matrix reuse still need a chosen native lowering. The tied head has a different table/exact/RTN4 consumer whose preparation and row costs are in its owning report.

The paid .76/.90-BPW residual experiment has now answered the first question negatively for its original-producer quadratic fit. A [shared value basis](../value-observer/README.md) is more promising: it compresses the observed V/attention/O map and keeps narrow value coordinates through the cache and reduction. Its layer-0 isolated continuation improves test NLL from 8.73188 for independent V/O to 4.90511, while layer 14 has lower teacher KL but slightly worse NLL. Both remain isolated substitutions with all other weights exact. Next fit composed maps and quantized producers under a complete rate budget; another small weight-error improvement by itself does not address the model failure.

## Reproduce and custody

The data map is `/path/to/workspace/data/kelana-subbit/README.md`. It owns the capture, fit inputs, per-task solver output, three complete images, source snapshots, quality reports and GPU wrapper logs. `summarize.py` collects those existing receipts without a model run. `results.json` retains per-window losses and token-frequency buckets as well as the aggregate results.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
S=/path/to/workspace/projects/kelana/research/quantization-discovery/subbit
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
D=/path/to/workspace/data/kelana-subbit/full-model
$B --runtime-max 50s --exec "$P" "$S/full-model/capture.py"
"$P" "$S/full-model/prepare.py"
# Run one indexed task per bounded reservation, retaining completed tasks.
"$P" "$S/batched-fit/run_task.py" --task 0 --source "$S/batched-fit/fit.py"
"$P" "$S/full-model/refine.py" --task 0
# After all 14 tasks, assemble into a fresh candidate directory.
"$P" "$S/full-model/image.py" --series "$D/binary055-refined" \
  --head-variant mixed --out "$D/NEW_IMAGE"
$B --runtime-max 50s --exec "$P" "$S/full-model/evaluate.py" \
  --image "$D/NEW_IMAGE" --arms reference body complete --out "$D/NEW_QUALITY.json"
"$P" "$S/full-model/summarize.py" \
  --extra "$D/residual-rank8-quality.json" "$D/residual-rank16-quality.json" \
  --images /path/to/workspace/data/kelana-subbit/model-residual/images/rank8 \
           /path/to/workspace/data/kelana-subbit/model-residual/images/rank16
```

The first head-only run's original evaluator and image source were recovered byte-for-byte from the stored tool writes, matching its recorded hashes. Subsequent evaluation snapshots source at execution. Historical fit failures remain identified as failures; successful saved images are reused rather than refitted to satisfy a publication procedure. No Bonsai serving default changed.
