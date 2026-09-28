# Fold causal key-plane gains into the paid normalization

The preceding [group-specific gain fit](../rope-causal-gain/README.md) lowered original-producer held attention KL, but charged 224 new FP16 bytes and 224 multiplies per key token per layer. Qwen3-0.6B already multiplies each key coordinate by one BF16 `k_norm.weight` after the key RMS denominator. I asked how much of that gain can live in the existing 128 BF16 normalization slots, with no new metadata or online operation.

There is a constraint the earlier cost discussion missed. `k_norm.weight` has shape `(128,)`, not `(8,128)`: all eight KV heads use the *same* per-coordinate affine weight. Thus a gain on plane `i` folds into this tensor only if its value is shared across groups using that plane. Both components of a plane get the same gain. A group-specific post-normalization gain cannot in general be folded into this shared tensor. The projected K rows are upstream of RMS normalization, so scaling them does not implement it either.

For a key head `g`, let `u_g = W_g x`, `d_g = sqrt(mean(u_g²)+epsilon)`, and let `gamma_i` be the shared post-denominator weight on coordinate `i`. For a real scalar `a_i`, setting `gamma'_i = a_i gamma_i` yields `k'_{g,i} = a_i k_{g,i}` without changing `d_g`. A single scalar on both coordinates commutes with the RoPE rotation on that plane. Therefore every query head's causal score receives exactly the selected plane's `a_i`-weighted contribution, without reconstructing omitted planes. This identity is over real arithmetic. BF16 rounding of `gamma'` and of the normalization output changes the finite map; the experiment below evaluates that map separately. No bit-identity claim against a separate post-normalization multiply follows.

I optimized 64 shared real gains in `[.25,2]` against the same eight original-producer train windows, 16 strided causal queries per 256-token window, both observing heads and every causal key. The fixed 112-plane masks and the same `.002 sum_i(a_i-1)^2` penalty are retained; each group's cross-entropy has weight 1/8. I rounded the gains to FP16, multiplied the checkpoint's shared BF16 `k_norm` by them and stored the result in BF16. Four already-inspected validation windows are the comparison. The teacher distribution comes from the *original* Q/K in every arm, including the folded-gamma arm.

| Layer | Unit gain KL | Separate group gains KL | Shared real gain KL | Folded BF16 `k_norm` KL | Folded recovery of group-gain reduction |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .301353 | .229977 | .243803 | **.243792** | 80.6% |
| 14 | .432293 | .343686 | .362375 | **.362446** | 78.8% |

Every one of four held windows improves over unit gains on both layers. The maximum difference between the mean shared-real and folded-BF16 KL is .000071. These are original-producer CPU causal attention scores, not a paid sub-bit Q/K image, quantized-upstream model loss or native speed. The group-specific arm is stronger, but the shared fold gets roughly four-fifths of its KL reduction with **zero additional stored bytes, key-producer instructions, per-key attention instructions or cache elements**. The original 256-byte BF16 `k_norm` payload is replaced, not supplemented. The 112-plane Q/K score map still carries 512 padded BF16 key bytes/token/layer and 448 score products per attended key across both heads. Offline fitting and replacing the gamma tensor is paid quantizer work; the engine would still need a selected-plane Q/K producer and consumer before this becomes a model image.

The next construction should put shared gains into the already-paid normalization slots of a selected-row sub-bit Q/K producer, then fit the remaining group-specific residual only where its held post-O or gold-loss gain pays for a post-norm instruction and metadata. Train that choice with quantized upstream and evaluate independent text against a same-byte binary control. Do not reserve 224 bytes and 224 multiplies per layer for all gains just because the first fit parameterized them that way.

`fit.py` and `/path/to/workspace/data/kelana-subbit/rope-gain-fold/layer{00,14}.json` retain the 64 FP16 gains, 128 folded BF16 affine weights, full per-window scores, fit objectives and source/model/capture/prior hashes. Reproduce from the Kelana root with the installed CPU Python environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-gain-fold/fit.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-gain-fold/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-gain-fold/fit.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-gain-fold/layer14.json
```

No GPU, Bonsai executable or resident service changed.
