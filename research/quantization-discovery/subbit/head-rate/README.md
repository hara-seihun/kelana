# Spend Q precision by attention head

At fixed rank 88, Q's left factor can use two bits in some heads and three in others while sharing the same four-bit right factor. The two trained images in [attention-radial](../attention-radial/README.md) have identical right codes and scales. This experiment chooses eight of sixteen complete Q heads for the three-bit left image, using only train attention observations. It tests whether head-local sensitivity is a useful allocation coordinate before training another factor or building a mixed-bit kernel.

## An exact allocation rule inside the frozen-image family

Keep the original K, V, O, Q/K norms, RoPE, input activations and both candidate left images fixed. For each head `h`, let `L[h,b]` be the mean causal teacher-to-candidate attention KL over training positions when that head uses image `b`. Attention softmax does not mix query heads. Consequently the aggregate KL for any chosen set `S` of three-bit heads is exactly

`L(S) = (sum_h L[h,2] - sum_{h in S}(L[h,2]-L[h,3])) / 16`.

Each head has 128 rows of 88 codes, so switching a complete head from two to three bits costs exactly 1,408 bytes, with the same FP16 row scales and right factor. At exactly eight upgraded heads, selecting the eight largest train differences is a global optimum **within these frozen head choices and this train attention-KL objective**. No independence of post-O error or of full-model loss is assumed. This is also a small search reduction: all 12,870 eight-head sets reduce to one sort. It does not optimize the underlying codes, rank, native execution or the held data.

The packed image stores a two-byte little-endian head mask, separate two- and three-bit row streams, their FP16 row scales, one right factor and a 16-byte shape descriptor. Its 106,898 payload bytes are 0.407784 bits per original matrix weight. The corresponding uniform images contain 95,648 and 118,176 bytes. There are 270,336 factor terms per query in every arm. Native mixed-head dispatch, bit extraction, two factor passes, scaling, intermediate traffic and boundary conversion have **not** been timed. A dynamic branch or split launch may erase the byte saving.

## Fixed-input result

Eight 256-token WikiText train windows choose the heads. Four distinct 256-token validation windows measure the result. All arms share the same BF16 projection boundary and consumer. Original K/V/O remain fixed; embeddings and preceding layers are not quantized here. The even-head and reverse-rank arms pay exactly the same mixed payload rate. The reverse arm selects the eight *lowest* train KL gains.

| Three-bit heads | Train attention KL | Held attention KL | Held post-O relative squared error |
| --- | ---: | ---: | ---: |
| None, 0.36487 BPW | .060858 | .112897 | .026079 |
| Lowest train gain, 0.40778 BPW | .055511 | .104986 | .023623 |
| Even indices, 0.40778 BPW | .048488 | .100640 | **.023471** |
| Highest train gain, 0.40778 BPW | **.046136** | **.100332** | .024280 |
| All, 0.45081 BPW | .040789 | .092421 | .021807 |

Train selection improves held attention KL by .012564 against uniform two-bit and .004654 against the equal-rate reverse selection. It saves 11,278 bytes against uniform three-bit at a .007911 held-KL penalty. Its held attention KL is .000308 better than the even-head arm, but its post-O error is .000810 worse. That disagreement matters: the exact KL decomposition does not make O's summation across heads separable. A post-O-aware allocator should account for cross-head residuals instead of treating the KL ranking as universally optimal.

As a **held-only oracle diagnostic**, sorting the sixteen validation KL differences would reach .098791 at this eight-head rate. The oracle chooses heads 1 and 5 that the train ranking omits, so there is a .001542 gap on this validation panel. Those held heads were not used for selection. The train/held difference is a reason to use more independent attention captures before spending additional training on the selected rows.

This supplies an intermediate rate-quality point and a checked optimal assignment for a stated fixed-code family. It is not a quality-matched win over the higher-rate three-bit image, a complete quantized-model result, or an inference speedup. The useful next construction jointly trains both left images against a differentiable downstream objective with a rate penalty, then prices grouped mixed-bit consumption. A stronger experiment should allocate across whole layers and the tied embedding as well, since one Q matrix's saved bytes barely change total model rate.

`allocate.py` reads the fixed pinned model and fixture, writes a packed image plus all 16 train head gains, per-head train/validation KL, full consumer measurements and source/input/image SHA256s to `/path/to/workspace/data/kelana-subbit/head-rate/`. It checks that the mask and split records recover the selected source rows. `run.log` preserves command output. Reproduce without the GPU or resident-service lock:

```sh
cd /path/to/workspace/projects/kelana
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/head-rate/allocate.py
```
