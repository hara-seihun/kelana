# One signed-Hadamard coordinate across the complete Qwen3-0.6B image

The selected `fresh-duration32` ternary image uses the **same 1,024-wide packed sign vector in all 140 Q/K/V/gate/up matrices** (five per layer, 28 layers). The 28 attention-output matrices use the same vector's 2,048-bit prefix and the 28 down matrices its 3,072-bit entirety. The separately quantized tied embedding/head uses a *different* 1,024-bit vector. This is a checked image property, not an assumption that all seeded rotations are interchangeable. The transformer uses rotation blocks of 1,024 throughout.

## Exact complete physical image

[`measure.py`](measure.py) constructs an independently addressed 197-matrix image from the already checked [code/scale-page image](../code-pages/README.md). It removes only the matrix-local sign bytes; the 196 transformer matrices derive their sign-vector prefix from their existing input shape, and the embedding selects the second dictionary entry. `signs.bin` is 384 + 128 = **512 bytes**, with no per-matrix indices. For each matrix the script reinserts its chosen sign vector into the newly written bytes and checks equality with its complete paid parent file. It checks every original NPZ sign vector and the unchanged norms. [The full source/parent/image-hashed receipt](/path/to/workspace/data/kelana-subbit/ternary/fresh-duration32-shared-rotation/receipt.json) records each matrix's SHA-256 and physical bytes.

| Exact complete image | Bytes | BPW per 596,049,920 unique parameters |
| --- | ---: | ---: |
| Code + scale pages, matrix-local signs | 122,975,884 | 1.650544760 |
| Code + scale pages, shared signed coordinate | **122,940,428** | **1.650068880** |

The 197 local vectors previously cost 35,968 bytes; replacing them with 512 saves **35,456 bytes**. All codes, signs, FP16 scales, BF16 norms and shapes are unchanged after decoding. The selected image therefore retains its measured **4.498337 held NLL**, without a new language evaluation; this is the exact same complete numerical image. This rate gain is small and has no direct serving reader or measured TPS. The page-inflation penalty in the [cold consumer study](../code-pages/CONSUMER.md) still applies.

## A shared producer coordinate, not merely a dictionary

Let `D` be the checked sign diagonal and `H` the block-1,024 orthonormal Hadamard, `R = D H`. A row input `x` and a stored rotated matrix `T_i` have the real-arithmetic map `y_i = (x R) T_i^T`. If several projections consume the **same** `x` and `R`, compute `z = x R` once and use it for every `T_i`; no original-coordinate matrix or individual intermediate weight needs to appear. The three Q/K/V projections share their normalized input, and the two gate/up projections share their MLP input. Across 28 layers these are 56 common-producer groups instead of 140 separate rotations: **84 of 140 1,024-wide transforms can be shared**, a reduction of 430,080 Hadamard butterflies and 86,016 sign applications per token in a hypothetical consumer that otherwise transforms once for each projection. Attention-output, down and tied head have separate producers and cannot be folded into those groups by sign equality alone.

The derivation uses the `quantize.py` encoder and its decoder identity `W_effective = T_i R^T`. It is exact over real arithmetic. The existing evaluation expands each image to BF16 and does **not** pay these activation transforms. A direct packed runtime would have to price transformed-activation preparation, staging and the quantized matmul against that expanded control, and show its own FP32/FP16 numerical quality: reassociating the Hadamard and dot products need not reproduce expanded floating-point bits. This image result establishes a viable shared coordinate and actual paid rate, **not** 84 saved transforms in today's serving path or a whole-model speedup.

Reproduce without GPU: `python3 research/ternary/shared-rotation/measure.py` from the Kelana root. No Qwen3.6 MoE weights were modified. Its routed experts need a separately trained image on broad actual producers, with complete-model held loss, before this sign-sharing structure can transfer there.
