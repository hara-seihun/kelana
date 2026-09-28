# First sub-bit transfer to Qwen3-1.7B

A larger Qwen changes the matrix geometry, but it did not reverse the raw-response ranking of the frozen sub-bit shortlist. At roughly .55 matrix bits per weight, the response-fitted binary factor beats the selected spectral 4-bit family on held-out inputs for early Q, late Q and middle down. The early-Q whole-model continuation is less simple: binary wins validation loss and teacher KL, while spectral wins test loss on four windows. It is another split-dependent observation, not a scale-up quality win.

## Pinned model and matched observations

The official `Qwen/Qwen3-1.7B` model is pinned to `70d244cc86ccca08cf5af4e1e306ecf908b1ad5e`. The two source weight shards are 4,063,515,592 bytes. [`fetch.py`](fetch.py) records the SHA256 of every downloaded file in `/path/to/workspace/data/kelana-subbit/models/qwen3-1.7b/source.json`. Its bounded 16-MiB HTTP range requests resume on complete chunk boundaries; the ordinary snapshot downloader restarted multi-gigabyte Xet transfers when a 55-second foreground session ended. Small files still use the pinned Hugging Face snapshot. No new machine or service was provisioned.

The 1.7B and pinned 0.6B tokenizer JSON, tokenizer config, vocabulary and merges are byte-identical. We reused the exact eight train, four validation and four test WikiText-2 raw windows from the 0.6B `tokens.npz`, each 256 tokens. The [fixture manifest](/path/to/workspace/data/kelana-subbit/size-transfer/fixtures/manifest.json) keeps the source token hash and every window start. `capture.py` used original BF16 producers and captured 2,048 train and 1,024 held-out validation input vectors for layer 0 Q, layer 27 Q, and layer 14 MLP down. The three split captures ran under Bonsai's exclusive `tools/run-batch-compare`, then `assemble.py` joined the matched `weight/train/validation` fixtures. Model and fixture blobs stay out of Git.

The loaded model has **1,720,574,976 unique parameters**. The input embedding and LM head share storage; the checkpoint names count another 311,164,928 tensor elements for that alias. The model has 28 layers and 151,936 vocabulary rows. Single-matrix substitution does not make a sub-bit model: with all other unique parameters left BF16, the isolated Q images cost about 15.962 bits per unique parameter, and the isolated down images about 15.887. These totals include the binary image's 12-byte dimension descriptor.

The original BF16 reference NLL is 3.55578 on validation and 2.97271 on test, for 1,020 next-token predictions per split. The corresponding perplexities are 35.0152 and 19.5448. The four windows, not a complete corpus pass, are the unit of this comparison. [The compact receipts](results.json) record source hashes, individual reference-window losses, each image identity and online work. Full per-window continuation and clock-admission evidence live under `/path/to/workspace/data/kelana-subbit/size-transfer/`.

## Frozen matrix shortlist

`fit_binary.py` runs the authors' pinned NanoQuant ADMM initializer for 400 outer and five inner iterations, seed 0, using 0.4-shrunk train-channel squared norms and uniform output norms. It exports packed one-bit U/V and FP16 pre/post scales, then gives the output signs and response scales four coordinate sweeps on train activations. This is still an ADMM-only adaptation with our explicit output refit, not the published full NanoQuant gradient calibration, block reconstruction or model KD.

`fit_spectral.py` freezes the 0.6B study's covariance metric, with 0.4 shrinkage toward the train-channel diagonal, group-128 signed-grid quantization, square-root factor balancing and a least-squares input-factor repair after rounding the left factor. It tests only 4/4 and 4/2 output/input precision and selects by *train* response error. The output eigensystem of the same augmented response metric avoids a large tall SVD. All known weight rows may train either quantizer; only activation windows are held out. Both families count their scales and packed coefficients. The displayed binary payload rate excludes its 12-byte dimension descriptor, which the image rate and isolated full-model rate count separately. The spectral payload includes two 16-byte factor descriptors. These are matrix rates, not whole-model rates.

Relative squared error is `||X_val(Wq-W)^T||² / ||X_val W^T||²`. The factor image itself, not a latent continuous fit, is scored. The NanoQuant postfit image is the frozen candidate even where held-out error increases.

| Matrix | Shape | Binary rank / BPW | Binary ADMM error | Binary postfit error | Spectral selected precision / rank / BPW | Spectral error |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Layer 0 Q | 2048×2048 | 544 / .54688 | .07910 | **.05385** | 4/4, 128 / .51569 | .07042 |
| Layer 27 Q | 2048×2048 | 544 / .54688 | .11425 | **.11985** | 4/4, 128 / .51569 | .14623 |
| Layer 14 down | 2048×6144 | 800 / .53125 | .43199 | **.49852** | 4/2, 320 / .54820 | .51878 |

Late Q and down expose an overfit, not a higher-quality postfit: their training errors fall from .10432 to .06202 and .42790 to .29164 while held-out error rises from .11425 to .11985 and .43199 to .49852. Early Q improves on both splits. The same four-sweep 0.6B control was .06962 on early Q, .10438 on late Q and .42379 on middle down. At fixed 2,048 train vectors, more model parameters and wider channels did not uniformly lower response distortion. The 0.6B selected spectral errors with the same 0.4 covariance shrinkage were .08103, .12391 and .47882 on those respective modules. Three matrices and one model size cannot fit a scaling law.

The precision alternative matters only for down here. 4/2 at rank 320 gives .51878; 4/4 at rank 200 gives .55742. Both Q matrices choose 4/4 at rank 128 by train fit. The group-scale cost creates a rank cliff and leaves the selected Q spectral images at .51569 BPW, so Q is a budget-capped comparison rather than an equal-byte claim.

The direct arithmetic work map also changed. A Q binary map needs 2,228,224 signed terms, or 139,264 first-stage plus 139,264 second-stage eight-sign response lookups with 82,620 table additions. Its packed payload is 286,720 bytes. The Q 4/4 spectral map needs 524,288 factor terms and 270,368 payload bytes, plus its FP16 group scales. For down, binary needs 6,553,600 signed terms or 819,200 two-stage lookup reads; 4/2 spectral needs 2,621,440 arithmetic factor terms. These are executable logical maps, not measured 1.7B gfx1151 latency. NanoQuant's own direct lookup lowering is the comparator; interpreting its dense arithmetic term count alone as GPU latency would be wrong. WMMA padding, unpacking, table placement, scale traffic and two-pass intermediate writes remain unpriced by native timing.

## Consumer quality and isolated continuation

The immediately consumed Q normalization is headwise RMS with 16 heads of width 128 and `eps=1e-6`. `consumer.py` applies the real stored Q-norm weights to the two reconstructed response streams. On layer 0, relative normalized-Q error is .14930 binary versus .18684 spectral; on layer 27 it is .12411 versus .14860. Raw Q error alone understates the early normalized error. This is not an attention KL, since K and the full attention map were not captured for this transfer.

`continuation.py` then substitutes one image at a time into the original BF16 model. It expands the *stored* factors and rounds the resulting dense matrix once to BF16 for quality evaluation. The native packed-consumer timing is separate work. The table reports NLL changes relative to the same-window BF16 reference and teacher KL against its logits.

| Replaced matrix | Validation binary ΔNLL / KL | Validation spectral ΔNLL / KL | Test binary ΔNLL / KL | Test spectral ΔNLL / KL |
| --- | ---: | ---: | ---: | ---: |
| Layer 0 Q | +.00883 / .05161 | +.03420 / .09649 | +.02773 / .05616 | +.00959 / .06547 |
| Layer 27 Q | -.00827 / .00729 | -.00333 / .00757 | -.00839 / .00502 | -.00972 / .00510 |
| Layer 14 down | +.00199 / .03124 | +.00851 / .03375 | -.01513 / .02735 | -.01413 / .02948 |

Layer-0 Q test NLL ranks the two images opposite to validation and to teacher KL. Its second test window contributes +.11285 nats/token for binary and +.06797 for spectral; the other three binary window changes are +.00246, -.01190 and +.00751. A quantized matrix yielding a negative four-window ΔNLL at late Q or down is not evidence that compression improves the language model. Keep the per-window report and evaluate new text before selecting a larger-model quantizer by NLL.

## Decision

At this model size the frozen spectral 4-bit shortlist keeps a large logical-work advantage, but no raw projection or normalized-Q quality advantage over the four-sweep binary factors. The downstream Q0 test loss exception is real on these four windows and does not survive validation or teacher KL. Do not extrapolate the 0.6B attention-consumer win or a native speedup to 1.7B from this point. The first useful follow-up is to vary calibration coverage for late Q and down, then fit the actual Q/K attention consumer on fresh text if its benefit survives; the larger rank and channel width make the present fixed 2,048-token output refit brittle. A complete-model quality/rate allocation remains the programme owner's work.

To reproduce, run `fetch.py --seconds 38` until `source.json` appears, capture each split under `tools/run-batch-compare --runtime-max 44s --memory-gib 28 --exec .../capture.py --split SPLIT`, then run `assemble.py`, `fit_binary.py` and `fit_spectral.py` for each of the three manifest fixtures. `consumer.py` handles the Q-normalization metric. `continuation.py --fixture-name layer00-self_attn_q_proj` takes one bounded GPU panel per matrix. Finally `summarize.py` regenerates [results.json](results.json). The source shard hashes, packed candidate hashes, fixture hashes and complete per-window outputs are retained in their owning data records.
