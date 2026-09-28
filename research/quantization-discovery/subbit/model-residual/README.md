# Complete-model response residuals at ranks 8 and 16

Two serialized Qwen3-0.6B image candidates are ready under `/path/to/workspace/data/kelana-subbit/model-residual/images/`: `rank8` is **0.760003 BPW**, and `rank16` is **0.895462 BPW** over all 596,049,920 unique model parameters. Both retain the refined .624544-BPW binary-factor body, the same tied head, norms and config. Each of the 196 body matrices gains FP16 `residual_left[N,R]` and `residual_right[R,K]`. Rank 8 is the first eight coordinates of the rank-16 fit, not a second independent optimizer run.

On distinct original-model validation activations, every body matrix's response error improves at both ranks. Median per-matrix relative squared error changes from **.232794** for the refined binary base to **.226669** at rank 8 and **.221202** at rank 16. The mean changes from .234424 to .227443 and .221782. The [compact result](results.json) gives each module family's median and pins all 28 layer fit receipts; every layer receipt retains its own seven train and validation scores, binary-image hash, residual-image hash and original-capture hash.

The completed [full-model reforward](../full-model/results.json) reverses that local trend. Using the same mixed tied embedding/head and four pilot windows per held split, rank 8 and rank 16 do not improve test loss:

| Complete image | Payload BPW | Validation NLL | Test NLL | Test teacher KL |
| --- | ---: | ---: | ---: | ---: |
| Refined binary base | .624544 | 9.31067 | 9.65603 | 6.98149 |
| Rank 8 residual | .760003 | 9.30518 | 9.72919 | 7.04433 |
| Rank 16 residual | .895462 | 9.48939 | 9.84258 | 7.19636 |

Original BF16 is 3.90522 validation and 3.31076 test NLL. Body-only arms with original tied weights also worsen test NLL, 9.44595 to 9.49166 and 9.57704. These are BF16-expanded model-quality forwards, not compressed execution times. The reports are `/path/to/workspace/data/kelana-subbit/full-model/residual-rank{8,16}-quality.json`, with per-window values and source/image identities.

This allocation spends more bits to improve all 196 isolated response metrics and still worsens the composed model. Stop native work on this particular residual allocation. Fit quantized-producer or downstream behavior before treating a local quadratic improvement as a complete-model selection rule.

## Construction and quality boundary

For each weight W, [`fit.py`](fit.py) decodes that matrix's *actual* refined binary image, forms the FP32 remaining residual E = W − W_binary, then evaluates Y = X_train Eᵀ with the original BF16-model train producer capture. It sketches the output-side column space of Yᵀ with 32 random response probes, makes one power iteration, and diagonalizes a 32-column response matrix. The resulting sorted output basis Q has 16 columns. The least-squares input factor for that fixed output basis is QᵀE; the consumer adds `(x @ residual_right.T) @ residual_left.T` to the existing binary output. This construction minimizes train-response squared error for its chosen output subspace, not weight Frobenius error. Randomized subspace search is an approximation to the top response singular subspace. One rank-16 fit supplies a nested rank-8 prefix. The FP16-rounded stored factors are what the train and validation scores evaluate, not unrounded latent factors.

Train has 2,048 rows and validation has 1,024 rows for every matrix. Both come from the pinned original BF16 Qwen model with disjoint WikiText splits and no candidate-image propagation. Capture `uint16` arrays are interpreted as BF16 bit patterns, not converted as integers. [The capture manifest](/path/to/workspace/data/kelana-subbit/full-model/capture/manifest.json) maps Q/K/V, attention output, gate/up and down to their actual producer inputs. The safetensors model SHA-256 is `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`; the refined binary source manifest and every matrix SHA-256 are in [results.json](results.json) and the image manifests. The layer receipts' `model_sha256` field records the pinned `source.json` hash unless `--hash-model` was passed; these runs did not pass it. The safetensors file hash is pinned separately in `source.json` and `results.json`. No validation row selected a factor.

Median validation errors by family:

| Module | Refined binary | Rank 8 | Rank 16 |
| --- | ---: | ---: | ---: |
| Q | .087053 | .084114 | .081741 |
| K | .101580 | .096826 | .092928 |
| V | .354793 | .338620 | .325451 |
| Attention output | .297126 | .286586 | .278432 |
| Gate | .107028 | .104305 | .102029 |
| Up | .322587 | .314223 | .307948 |
| Down | .403584 | .395021 | .387605 |

## Paid storage and online computation

| Complete image | Total payload bytes | Added body FP16 bytes | Bytes in containers, excluding manifest | BPW over unique model parameters |
| --- | ---: | ---: | ---: | ---: |
| Refined binary base | 46,532,412 | 0 | 46,815,508 | .624544 |
| Rank 8 | 56,624,956 | 10,092,544 | 57,009,580 | .760003 |
| Rank 16 | 66,717,500 | 20,185,088 | 67,102,124 | .895462 |

Every stored byte of the existing binary image and tied image remains in these totals. The base body's binary signed-dot work has 222,035,968 FMA terms per query across 196 matrices, before its pre/post scale work. The residual adds 5,046,272 FMA terms at rank 8, or 10,092,544 at rank 16, for its **two additional products per body matrix**. It also needs an FP32 rank intermediate write/read, at least 12,544 or 25,088 bytes across all 196 matrices per one-query traversal, and an FP32 addition at each of the 344,064 body output coordinates. The residual coefficient images alone cost the added bytes in the table. A straightforward standalone lowering submits two extra kernels per matrix with the addition fused into the second, or a third kernel if not fused. At 196 matrices that is up to 392 or 588 added launches per token; fitting time and coefficient traffic do not price those launches away. Shared tiling or fusion might change this cost, but no native consumer or full-model speed claim is made here.

## Reproduce and custody

[`fit.py`](fit.py) accepts a bounded layer interval, verifies each refined base body image and BF16 producer capture against its manifest, writes one rank-16 factor NPZ and a seven-matrix response receipt per layer. Four bounded runs covered the remaining 27 layers after a one-layer pilot. Each used Bonsai's exclusive GPU reservation with `--runtime-max 43s --memory-gib 12 --pin-clock`; the wrapper restored `bonsai-halo.service`. `/path/to/workspace/data/kelana-subbit/model-residual/` retains the factor images, 28 fit reports, wrapper clock traces and run logs. [`assemble.py`](assemble.py) copies the same tied head/norms/config into each image, combines the base body NPZ with either eight or sixteen residual coordinates, and counts **all** NPZ payload arrays. The original base image and producer captures stay unchanged.

```sh
D=research/quantization-discovery/subbit/model-residual
O=/path/to/workspace/data/kelana-subbit/model-residual
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 43s \
  --memory-gib 12 --pin-clock --exec \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python "$D/fit.py" \
  --first 7 --last 14 --out "$O/fits"
OPENBLAS_NUM_THREADS=4 python3 "$D/assemble.py" \
  --base /path/to/workspace/data/kelana-subbit/full-model/image-binary055-refined \
  --fits "$O/fits" --out "$O/images"
```

Image manifests list each complete body's SHA-256, original image hash, residual-fit source hash, response errors, exact payload bytes, original fit receipts and 28 residual fit receipts. All 196 body and tied/norm hashes were checked after assembly. The report's `results.json` pins both final image manifest hashes. The [data custody note](/path/to/workspace/data/kelana-subbit/model-residual/README.md) explains which files survive task-checkout reclamation. The full-model programme owns the shared quality decoder and the linked NLL comparison. This report retains the matrix-response construction alongside its adverse model-level result.
