# The exact RoPE coordinate family for a joint key/query quantizer

A Q/K representation can change its coordinate axes before rounding both sides of a score. The useful question is which changes can cross RoPE without a position-dependent dense decoder. There is a sharp answer for fixed real linear maps: with distinct, non-real RoPE frequencies, every invertible map commuting with every position rotation is an independent complex multiplier on each two-coordinate plane. This leaves a practical, untested quantizer variable: choose a phase per selected plane, rotate both observing queries and the shared key before packing the key into signed nibbles, and score those labels directly. The unrounded score remains exactly the same over the reals, but the rounding cells change. A two-coordinate finite witness below reduces absolute score error from .52 to .080660 without changing the key-code width or the number of score products. This is a construction and search reduction, not a Qwen quality result.

## Theorem and boundaries

Write the 128-dimensional positional operator as `R(t) = diag(R(t theta_0), ..., R(t theta_63))`, where `R(a)` is a planar rotation. Assume `e^{i theta_j}` and `e^{-i theta_j}` are all distinct, including between different planes. For the pinned geometric Qwen RoPE schedule, the 64 angles are distinct and lie strictly between zero and pi, so the assumption holds. If a fixed real matrix `T` satisfies `T R(t) = R(t) T` for every integer `t`, then

```
T = diag(a_0 I + b_0 J, ..., a_63 I + b_63 J),
J = [[0,-1],[1,0]].
```

It suffices to require commutation with `R(1)`. After complexification, `R(1)` has 128 distinct eigenvalues. A commuting matrix must preserve each one-dimensional complex eigenspace. Reality pairs the conjugate coefficients, leaving the displayed real blocks. Conversely each displayed block commutes with every `R(t)`. `T` is invertible precisely when every `a_j²+b_j²>0`. Thus the invertible family has 128 real parameters instead of a generic matrix's 16,384. An orthogonal member has `a_j²+b_j²=1`, leaving 64 phase angles. Repeated frequencies or a zero/pi angle invalidate the distinct-eigenvalue premise and permit larger blocks; this theorem must not be applied unchanged to another positional scheme.

A fixed real projection `P` commuting with `R(1)` obeys `P²=P`. Each complex scalar block therefore has coefficient zero or one. Every position-independent *commuting projection* retains or discards an entire plane, so its rank is even. This is not a bound on a rank-one **post-RoPE** observer: that valid map projects after the position rotation and makes the producer position-dependent, as [the half-plane study](../rope-half-plane/README.md) explicitly does. It also says nothing about nonlinear encoders or approximate scores.

For an arbitrary invertible commuting `T`, set `k'=Tk`, `q'=T^{-T}q`. Then for every pair of positions,

```
(R(p)q')^T (R(t)k') = (R(p)q)^T (R(t)k).
```

The identity follows because `T` commutes with both rotations and their inverses. For the orthogonal phase family `U`, use `q'=Uq` and `k'=Uk`; the score is unchanged and both observing GQA heads share the same key transform. Any center in the *post-RoPE* key coordinate must be rotated or refitted as well. The key RMSNorm denominator is computed on the original full raw K vector and is unaffected by a phase applied after normalization. BF16 normalization, finite rounding and separately contracted FMA operations need not reproduce the original FP32 bits.

## A different packed map at unchanged cache and score width

Take one plane with `q=(1,1)`, `k=(.49,.49)`, signed-nibble codes `-7..7`, and a scalar key step `.75`. The teacher score is `.98`. With zero phase, nearest-coordinate rounding stores `(1,1)` and the direct score is `1.5`. With phase `pi/4`, rounding the rotated key stores `(0,1)`; the same rotated real query dots its decoded signed-nibble key to `1.0606601717798212`. Absolute error falls `.52 -> .08066017177982121`. There is no float/int4 expansion of the cached key at the dot. This is one constructed input, not a measured distributional improvement; the phase can also worsen another input. `check.py` writes [the deterministic receipt](receipt.json) with the codes, scores, source hash, and a 201-case numerical check of the **unquantized** score identity. The algebra above, rather than floating arithmetic, proves the identity for all real inputs.

For the existing selected 128-plane Q/K observer across eight GQA groups, a per-plane phase keeps 256 signed-nibble key coordinates, hence 128 logical and padded key bytes/token/layer. Its two-head four-dot reader still takes 1,024 signed-nibble coordinate products/key/layer; the three-dot shared reader still takes 768. Existing binary Q/K factor bytes and full K-norm work do not disappear. A fixed FP16 cosine/sine pair per selected group/plane costs 512 bytes/layer, 0.000192 bits per unique Qwen3-0.6B parameter if paid on all 28 layers, using the [complete image's](../full-model/README.md) 596,049,920 unique parameters. The 14,336 metadata bytes are an incremental charge, not a complete image rate. Composing that phase with existing position sine/cosine once per token and selected group/plane costs four real multiplies and two real additions per plane before the already-required RoPE rotations, up to 512 multiplies and 256 additions/token/layer at 128 planes. Both query heads and the key can share the resulting angle at an append position. Alternatively a position/group/layer angle table costs four bytes per selected plane per position, 16 MiB per layer at 32,768 positions, so its lookup and memory budget must be charged rather than called free. BF16 phase metadata and finite native composition change the exact map and need quality checks.

The practical next search is small: fit phases and key steps against both heads' finite causal/post-O loss on **quantized-upstream train text**, with selected planes and paid Q/K images fixed first. Compare fresh held text against the same paid image and per-coordinate signed-nibble steps at zero phase. Then jointly retrain the paid producer if this degree of freedom helps. Do not run another fixed-query base-head selector or infer speed from the unchanged product count. A native candidate would have to price append-time phase composition, label packing, query preparation, fused score/softmax and the full K projection, then show a matched-quality model result before runtime adoption. No GPU, model NLL, Bonsai executable or service changed in this iteration.

Run the finite witness from a Kelana checkout with `python3 research/quantization-discovery/subbit/rope-commutant/check.py`. The source and receipt are in Git custody.
