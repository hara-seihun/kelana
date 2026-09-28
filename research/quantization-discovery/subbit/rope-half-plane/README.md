# One scalar from a RoPE plane is not one producer row

A full two-dimensional RoPE plane is a convenient unit for a narrow key cache because its projector commutes with rotation. Could a cache use one scalar from some planes instead? A fixed one-dimensional direction chosen **after** rotating the key gives a valid direct score map: store `uᵀR(p_k)k` and use `(uᵀR(p_q)q)` on the query side. It does not reconstruct either original plane coordinate at score time. The same direction must be used at both ends. This report solves the rank-0/1/2 allocation for an isotropic score query, then evaluates that image and two whole-plane controls under the two real Q heads of each pinned Qwen3-0.6B GQA group.

## Exact isotropic allocation

Let `C` be the covariance of the post-RoPE key, averaged over positions 0–4095. Hidden inputs are independent zero-mean isotropic vectors; the original BF16 K projection is cast to FP64. A block-diagonal orthogonal projector `P` keeps rank zero, one or two per RoPE plane, with total rank 28 per KV group. For an independent isotropic score query the expected squared score error is `tr((I-P) C (I-P)) = tr(C) - tr(PC)`. At rank one in plane `i`, the maximizing direction is the top eigenvector of its 2-by-2 principal block of `C`. The best gains at ranks zero, one and two are respectively `0`, `lambda_max(C_ii)` and `tr(C_ii)`. Off-plane K covariance does not enter this isotropic objective. The dynamic program in `half_planes.py` exhausts the three choices at each of 64 planes and every scalar budget up to 28. Its terminal state is therefore the global optimum **within post-rotation block-diagonal orthogonal projectors** at rank 28. It is not an optimum among unrestricted rank-28 projectors, query-weighted objectives, or nonlinear codes.

With both Q heads weighted equally, let `Q` be their average post-RoPE query covariance over the same absolute-position range. Query and key hidden states and their absolute positions are independent in this diagnostic domain. The fraction of score variance retained by a fixed `P` is `1 - tr((I-P)Q(I-P)C)/tr(QC)`. Unlike the isotropic fit, off-plane covariance matters to this evaluation. This contract has executable fixed orientations in the **absolute** post-RoPE cache. It is different from the earlier relative-offset surrogate, which holds the query at position zero and rotates only the key; a rank-one projector applied in that relative frame would not be a fixed key-cache direction.

## Pinned result at 28 scalars per group

Every arm stores 224 logical BF16 key scalars over eight groups, aligns each group to one 64-byte line for 512 bytes per occupied token/layer, and spends 448 scalar score products across both heads. The last column replays the previous Q-weighted 112-whole-plane capped masks under this study's absolute-position domain, rather than quoting their earlier relative-offset scores.

| Layer | Isotropic 14 full/group | Isotropic mixed rank | Q-weighted 14 isotropic full/group | Q-weighted mixed rank | Q-weighted prior capped 112 full planes |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 | .342615 | **.353758** | .438123 | .442844 | **.458826** |
| 14 | .405416 | **.414085** | .482160 | .481137 | **.568041** |

The exact isotropic rank-one freedom recovers .011143 and .008669 of full isotropic score variance over the best fourteen full planes per group. But its isotropic-selected image loses the Q-weighted comparison to the existing feasible whole-plane masks by .015983 and .086904 on these layers. This is a negative about the **isotropic-trained** rank-one image and independent-position covariance. It does not bound a trained Q-weighted or causal-text rank-one image. The per-group ranks, axes, masks, denominators, pinned input/source hashes and all five fractions are in `data/kelana-subbit/rope-half-plane/receipt.json`.

There is also a producer cost that the cache-bit comparison hides. For a fixed nonzero direction `u`, the coefficient of the *unrotated* key is `R(-p)u`. At positions zero and one these vectors are linearly independent whenever the plane frequency is not a multiple of pi. Thus a key producer with position-independent linear rows needs both original plane coordinates to produce a single cached post-RoPE scalar at arbitrary positions. A query producer has the same issue. The mixed optimum retains 82 one-dimensional planes over layer 0 and 48 over layer 14. It needs 306/272 projected key rows instead of 224 for fourteen full planes per group, plus 82/48 two-component direction dots per token on each side. The image must also store directions, for example 328/192 FP16 bytes for two coefficients per rank-one plane per layer in addition to mask provenance. These are logical costs, not GPU timings; a learned position-dependent producer could have a different implementation cost. A full-plane mask needs no direction dot and its retained 224 producer rows are also the cached coordinates.

This result says not to choose post-RoPE half-planes on the isotropic score surrogate merely to save cache: the cache bytes and score products stay fixed, the isotropic score gain is small, and the producer becomes wider. The next useful test must train a paid Q/K producer and the two-head causal score consumer on quantized-producer text, then compare matched-rate full- and half-plane images by held attention/post-O and model loss. Only if rank-one choices earn a quality improvement should a native producer and cache comparison pay the extra rows, metadata, query preparation, padding and occupancy. The existing Q-weighted full-plane masks are the control; another covariance-only angle sweep cannot decide language behavior.

Reproduce on CPU without the GPU reservation:

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/rope-half-plane/half_planes.py \
  --output /path/to/workspace/data/kelana-subbit/rope-half-plane/receipt.json
```

No packed Q/K model image, native executable, whole-model loss or service state changed.
