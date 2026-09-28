# The fixed pinched final gain breaks the original Qwen observer

**Decision on the specified source-derived construction:** test the captured-hook realization of replacing the pinned Qwen3-0.6B final gain by the closest Frobenius symmetric gain that permits a 128-coordinate slice for layer-0 query head 0, retaining the original tied embedding/head. The exact hook reconstruction/rounding contract is stated below; this is not an unrun changed-model forward. On the already-owned original-BF16-model final-head producer capture, this fixed replacement increases validation gold-token NLL **4.039734→5.267159** (+1.227425) across 510 next-token positions and incurs teacher→candidate categorical KL **1.580497**. Train NLL increases **4.069119→5.616052** (+1.546932) with KL **1.758456** across 1,020 positions. On 64 separately saved **actual GPU BF16 source-head logits** from the two validation windows, candidate NLL is **4.520795** versus saved teacher **3.610259**, with KL **1.650258** and 42/64 changed top-1 predictions. The nonnegative coefficient pinching cost is therefore not a useful behavioral proxy: `||Δ||²_F=213.1940984756476` is only 1.35914% of `||Γ_final||²_F`, yet the normalized input to the vocabulary head changes by roughly 40–48% in Euclidean norm on these windows.

This is a **decisive negative for this fixed pinched-gain proposal at the original-producer final observation boundary**, not a theorem excluding every approximate gain, compensating head, jointly trained representation, quantized image or native frontier. The parent owns the general gain theorem and source-only coefficient screen. This independent study does no gain-strength sweep, quantizer refit, source fine-tune or rotation of the other 28 layers.

## Exact proposal; one live endpoint changes

Let `A=W_q[0:128,:] Γ_input` using source BF16 tensors interpreted as exact real coefficients. Compute an orthonormal 1,024×128 basis U for `range(Aᵀ)` by full-rank SVD, `P=UUᵀ`, final diagonal `Γ=diag(model.norm.weight)`, and

```
C = (I−P) Γ U,
Δ = C Uᵀ + U Cᵀ,
B = Γ − Δ = PΓP + (I−P)Γ(I−P).
```

The script checks `UᵀC≈0`, B symmetric, `[B,P]≈0`, `||Δ||²_F=2||C||²_F`, and the direct B application against its two rank-128 terms. The fixed B commutes with the desired head row-space projector. A common orthogonal residual gauge can therefore align that row-space with a 128-coordinate slice while diagonalizing B within its two blocks. This explains why the original [tied diagonal-gain obstruction](../residual-gauge-custody/README.md) no longer applies **exactly**: the target itself changes at the final observation. No numerical fit uses the final hidden captures, labels, logits or validation outcomes to choose U, C or B.

The checkpoint's saved final-head hook supplies `h=BF16(Γ n)` on each original-model state, where n is the final RMS-normalized residual before gamma. Reconstruct `n≈h/diag Γ` (all 1,024 original gamma fields are nonzero), apply the **fixed** low-rank correction

```
h_candidate = h − C (Uᵀ n) − U (Cᵀ n),
```

round the changed pre-head vector to BF16, and use the **original tied BF16 embedding matrix** for the output head. Thus the source BF16 embedding, all transformer layers, Q/K/V/MLP modules and producer states remain unchanged; only the final gain observer changes. Since a final-gain edit cannot alter upstream producer states, this is the complete affected *ideal* source map on the captured histories except for the recorded reconstruction/rounding boundary below. The hypothetical orthogonal gauge is not actually rotated into a model image, and this is not an exported quantized reader.

## Owned producer, numerical contract and full-head scores

[`score.py`](score.py) pins source safetensors SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`, the source revision and individual array hashes in [`/path/to/workspace/data/kelana-subbit/tied-head/capture.json`](/path/to/workspace/data/kelana-subbit/tied-head/capture.json), the owned [`final-head.npz`](/path/to/workspace/data/kelana-subbit/tied-head/final-head.npz) SHA256 `dc57232964e80d225f2212d85f89d43e5248ade92b7cfee17632a7502c195f1a`, and the original fixed WikiText-2 token fixture SHA256 `0479292cbee2cfc6cfc5f89e8f85dac85d2c0c275ed2704a59a7006faa7d66a2`. The prior source hook captured **all 256 BF16-normalized pre-head vectors** in four train and two validation windows. These fixed windows were chosen for that prior study, not selected after seeing this gain score. Their validation states have already been inspected in other research; they are not untouched holdout. The token fixture supplies next-token labels for positions 0–254 in each window. The other two original fixture windows in each split have no matching saved final-head states; no new CPU/GPU full-model forward was required.

Each window's 255 positions is scored against **all 151,936 vocabulary logits**, not a sampled vocabulary. The teacher head is a one-thread CPU PyTorch BF16 matrix multiplication of the saved BF16 hook output and original BF16 tied weights; the candidate head is the same BF16 multiplication after BF16-rounding the corrected hook vector. FP64 softmax/logsumexp computes categorical KL and gold NLL from these BF16 logits. This separates source BF16 matmul rounding from the source-derived FP64 U/C arithmetic. For the 64 saved positions (3,11,…,251 in each validation window), the separately captured actual GPU BF16 logits supply another independent teacher distribution: CPU BF16 baseline differs by just **9.73×10⁻⁵ relative logit RMS**, max 0.125 logit, and reproduces mean NLL 3.610261 versus saved 3.610259. Replacing only the candidate head BF16 matmul by a FP32 head on the *same corrected h* gives selected KL **1.649324** and NLL change **+0.910094**, versus BF16 candidate KL **1.650258** and NLL change **+0.910535**. BF16 head rounding is not the source of the large loss.

| Fixed original-producer window | Teacher NLL | Pinched NLL | Teacher KL to pinched | Top-1 changes / 255 |
| --- | ---: | ---: | ---: | ---: |
| Train 0 | 3.704633 | 4.931441 | 1.597776 | 170 |
| Train 1 | 4.320255 | 5.748824 | 1.609892 | 188 |
| Train 2 | 4.009227 | 5.750677 | 1.898011 | 183 |
| Train 3 | 4.242363 | 6.033265 | 1.928145 | 193 |
| Validation 0 | 3.941490 | 5.359294 | 1.582588 | 164 |
| Validation 1 | 4.137978 | 5.175024 | 1.578405 | 155 |

The complete per-window receipt and selected-GPU comparison are in [`results.json`](results.json). These are original upstream states, not forward propagation of a newly quantized embedding/model. Importantly, the saved hook observes **after** original gamma and BF16 rounding; `h/Γ` is a reconstruction, not the exact pre-gamma residual. Replacing the actual HF norm module by a dense B and forwarding would also round at a potentially different point. This study scores the explicitly stated captured-hook counterfactual, whose ideal FP32-head variant agrees closely with its BF16 version, but does **not** claim bit identity with that unrun changed-model forward. There is no unseen-history guarantee.

## Byte/work custody and stop rule

The original tied embedding/head remains one 151,936×1,024 image; no second vocabulary table is silently charged. An original-coordinate hook reader must store/realize B or its correction. A full symmetric FP16 upper triangle would cost **1,049,600 bytes** plus shape/framing, with up to 1,048,576 coefficient products per token to apply it, and would itself approximate the real B. A low-rank real factorization keeps U and C at 1,024×128 each; storing both in FP16 would cost **524,288 bytes**, plus a 2,048-byte FP16 diagonal gamma if not already retained, before descriptor/alignment and native work. One application needs four 1,024×128 products/syntheses (524,288 scalar products per token) and the output subtraction, or an algebraically fused consumer with its own measured cost. FP32 or higher-precision fields cost more. The trial computes U/C from the BF16 source *offline* and does **not** serialize these approximate factor images, so it neither saves bytes nor claims a throughput advantage. In the parent's fully transported residual gauge, B instead becomes a **diagonal** final gain, so neither the dense B nor these U/C correction fields need be stored or applied online. That route must transform every other live consumer and the tied embedding; those actual quantized images, encoding cost, quality effects and boundary rounding are absent here. The expensive original-coordinate correction ledger must not be imposed on that different gauged reader.

Given the large measured KL and NLL regression **before** fitting any transformed quantized image, do not recode the complete model around this specific Frobenius-optimal B merely to obtain a formal coordinate slice. A different endpoint correction would need to be selected on a behavioral objective and compared as a fully paid image to strong comparable-size controls. The present result neither proves that such a correction is impossible nor treats coefficient distance as the requested behavioral outcome.

Reproduce on CPU, one BLAS thread; the entire calculation including source and capture SHA checks, SVD, two full-vocabulary BF16 matmuls per window and receipt writing takes about eight seconds:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/pinched-gain-observer/score.py
```
