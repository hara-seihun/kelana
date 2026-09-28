# Layer-0 q-projection input is a source-known token map

This changes the premise of the [full-row transfer diagnosis](../quip-covariance-transfer/README.md) without fitting another quantizer. On Qwen3-0.6B's **token-ID inference path**, `model.embed_tokens(input_ids)` is the initial hidden state, layer 0 applies `input_layernorm`, and its attention immediately applies `q_proj` to that normalized state. There is **no prior attention/history operation** in this layer-0 q-projection producer. With `inputs_embeds` supplied directly, the external caller may bypass token IDs and the finite embedding-ID domain; later-layer projections also depend on history. The code source is the installed Transformers `models/qwen3/modeling_qwen3.py` (`Qwen3Model.forward`, `Qwen3DecoderLayer.forward`, `Qwen3Attention.forward`, `Qwen3RMSNorm.forward`), the pinned config and safetensors. Qwen3RMSNorm squares BF16 embedding elements in FP32, averages, adds `1e−6`, multiplies by reciprocal square root in FP32, casts normalized values back to BF16, then multiplies BF16 gamma.

[`producer.py`](producer.py) checks the pinned revision `c1899de289a04d12100db370d81485cdf75e47ca` and the existing train/validation token windows. A CPU float64 sum of the **exact BF16-square values**, cast to FP32 for the variance, followed by the specified FP32/BF16 operations reconstructs **all 3,145,728 captured float32 input entries bitwise**: 2,048×1,024 train and 1,024×1,024 validation. A native CPU FP32-order reduction instead differs at ten entries of one held token (`25450`), by up to `.001953125`, where the variance rounds one FP32 ulp differently. This establishes an exact **capture-equivalent CPU realization on all supplied token IDs**, not bitwise equivalence for every vocabulary ID under every GPU reduction schedule. No held outputs choose any parameter or code; the validation rows are used only to check the declared source map.

## Complete finite source law, not text frequency

The pinned BF16 embedding has **151,936 rows of width 1,024**, and the layer-0 norm gamma is BF16 width 1,024. Define `u_id` as the capture-equivalent embedding→RMSNorm map for each integer ID `0..151935`. The uncentered **uniform-ID** source moment is `G=(1/151936) Σ_id u_id u_idᵀ`. It is complete for this declared ID set and source map; it is **not** the probability of tokens in WikiText or generated language, and may include reserved IDs. A user-supplied `inputs_embeds` is outside this finite law. The exact empirical train moment `H` sees only 896 distinct IDs from 2,048 positions, whereas `G` sees every ID and is numerically full rank 1,024 (minimum eigenvalue `.00667881`, maximum `25.27102`). `G` assigns **3.12143** total energy to the 128-dimensional empirical train-null space, exposing missing directions without using validation.

The 8,388,736-byte float64 matrix is in [the durable data owner](/path/to/workspace/data/kelana-subbit/isa-source-law/qwen3-0.6b-layer00-q-input/README.md), SHA256 `48446e3398f37e867e0e79b6538252b3cf1cb155739fb7d737d5ec423393ad7d`; it is not another activation capture or checkpoint. [`vocab.py`](vocab.py) constructs eight 18,992-ID covariance chunks under a minute each on one CPU BLAS thread, merges them, and removes redundant per-chunk files. No GPU was needed. This source moment is available for the parent's parameter-free covariance-completion investigation, but this study does **not** claim that uniform-ID loss predicts language-frequency loss.

A score of the **two frozen, fully paid** 128×1,024 images under `G` (no fit or selection) gives QuIP# E8P12RVQ3B **.02784776** and scalar mixed group128 Q3/Q4 **.01589692** relative squared response error. QuIP# has `0.08963657` source error from its train-null projection alone versus scalar `0.01759430`; these positive terms include potential cross-interference in the complete scores. For context only, their separate captured train errors are `.00384223 / .00880129` and held errors `.01310979 / .01042320`. The *uniform-ID* score also prefers scalar, and makes the source-coverage risk visible without validation, but no fit was selected by any of those scores here. See [`source-results.json`](source-results.json) for teacher denominators and pinned image hashes.

## Exact rank scope

The 896 unique train float32 rows prove real rank **at most 896** exactly, irrespective of numerical eigendecomposition. [`modular_rank.py`](modular_rank.py) interprets each captured float32 as its exact dyadic rational, scales by `2^149`, and reduces modulo prime `65521`. It exhibits an **897×897 minor** of the first 896 distinct training rows plus the first new held token (`ID 6009`), with determinant **18187 mod 65521**. [`rank-witness.json`](rank-witness.json) stores the source row positions and pivot columns; a separate `verify` invocation checks that fixed minor without searching. A nonzero modular determinant certifies those 897 real rows independent. Therefore held inputs are **not contained** in the training span, independent of the prior numerical threshold; the measured projected energies and individual quantizer losses remain numerical results. The complete-source `G` positive eigenvalue statement likewise remains numerical, not an exact rational positive-definiteness certificate.

## Reproduce

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/quip-token-producer/producer.py
for id in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/quip-token-producer/vocab.py chunk "$id"; done
$PY research/isa-quantization/quip-token-producer/vocab.py merge
$PY research/isa-quantization/quip-token-producer/source_score.py
$PY research/isa-quantization/quip-token-producer/modular_rank.py verify
```

No extra source blob is committed to Git. The original pinned model, token windows, original captures, fixed quantized images and their hashes remain in their respective owners. CPU preparation memory includes the source embedding (~311 MB BF16), a 18,992×1,024 float64 chunk (~156 MB) and the 8-MiB covariance; these are offline resources. Inference memory and instruction cost of any new quantizer are unchanged because none was built.
