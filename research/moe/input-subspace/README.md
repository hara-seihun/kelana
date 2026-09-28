# Shared input subspaces on actual Qwen routes

A narrow common input basis looks excellent if the basis is fitted to the same few producer tokens it is asked to represent. On disjoint tokens it fails badly. This experiment carries a projected 2,048-dimensional layer-0 producer input through **both** Q4_K gate/up projections, SwiGLU, Q5_K down and the score-weighted sum for each actual top-eight route of the pinned Qwen3.6-35B-A3B GGUF. It decodes all observed experts from the 256-expert bank. No hidden gate channel is the acceptance target.

The train capture has 113 tokens; the held capture has 126. A common orthogonal basis comes from SVD of the uncentered producer inputs, with no access to weights, IDs or outputs. At runtime the proposed carrier would be the `r` coefficients of `x V_r^T`; the study reconstructs `x V_r^T V_r` before the original expert path to isolate subspace loss. The dequantized GGUF weights, FP32 BLAS products and SwiGLU, and FP64 weighted sum define the local reference. It is not the installed GPU's FP32 execution order. That offline reference differs from the native captured weighted sum by 2.0107% relative RMS before projection.

| Basis, rank | Input RMS, all 126 held | Routed-sum RMS, all 126 held | Routed-sum RMS, independent final 63 |
| --- | ---: | ---: | ---: |
| Train only, 32 | .6703 | .9492 | .9419 |
| Train only, 64 | .6433 | .9168 | .9104 |
| Train only, 112 | .6087 | .8541 | .8532 |
| Train only, 113 | .6082 | .8535 | .8526 |
| Train plus first 63 held, 112 | .3989 | .5749 | .8417 |
| Train plus first 63 held, 160 | .3646 | .4945 | .7881 |
| All held, 64, transductive control | .2396 | .3859 | .3748 |
| All held, 112, transductive control | .0372 | .0417 | .0388 |

The last two rows **fit the evaluated tokens** and are not deployable held results. Likewise, the all-126 number for the augmented basis contains its 63 calibration tokens; its independent final-63 column is the result to use. The 113-dimensional train span reconstructs every train input to numerical precision because the train matrix has row rank 113 (smallest singular value 1.8433), yet it misses 60.8% of held input energy and 85.4% of the held composed output by RMS. Adding 63 more calibration tokens and even expanding the rank to 160 leaves 78.8% final-half output RMS. The attractive 4.17% transductive rank-112 number is mostly sample leakage, not evidence for a transferable narrow expert input. This is a negative for **uncentered PCA projection learned from these captures**; it is not a lower bound on nonlinear or quantized full-width codes, a proof about later layers, or a complete-model language-loss result.

There is a real conditional prize if a better representation emerges. For eight selected experts, a rank-160 shared dense factor would use 327,680 shared products and 1,310,720 expert gate/up products instead of 16,777,216 direct products, an ideal 90.23% reduction for those projections before online movement and changed FP32 association. Across the layer-0 bank, BF16 projected factors plus one BF16 input factor would occupy 84,541,440 bytes against 301,989,888 bytes of the installed Q4_K gate/up images. These are *different precision and numerical maps*, not an image proposal or a speedup. All down weights, shared expert, router, state, head, gather and scheduling costs remain. The measured approximation is far too poor to justify a native port or whole-model speed claim.

The next experiment should capture substantially more disjoint producer windows before fitting a learned shared bottleneck, then measure held composed error and complete-model loss with the factor image charged. The exact local full-Jacobian witness in [the routed-sum study](../routed-jacobian/README.md) separately rules out an exact smooth bottleneck of width below 2,048 on one neighborhood; the result here tests a finite-data approximate family. It also reinforces the complete ternary pilot's lesson that local error alone cannot select a serving image. A full-width packed coordinate co-designed with gate/up consumption is still open.

[The receipt](/path/to/workspace/data/qwen-moe/input-subspace/receipt.json), SHA-256 `89cf195fa6610d734f0a0af8a7821ec8b2bd4ba64b678bfaa35933fa3385d263`, records model, inventory, bank, library, capture and source hashes, all singular values and per-token output errors. Run from the Kelana root, without a GPU reservation:

```sh
OPENBLAS_NUM_THREADS=8 OMP_NUM_THREADS=8 python3 research/moe/input-subspace/evaluate.py \
  --output /path/to/workspace/data/qwen-moe/input-subspace/receipt.json
```

No installed image, native executable or resident service changed.
