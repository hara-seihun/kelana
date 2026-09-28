# Reciprocal RoPE-pair gamma balance on the actual Qwen GQA source

**An exact source-map representation change, not a new attention approximation.** Under the same train-uniform causal-pair law as the [key-centroid screen](../qwen-kernel-gauge-screen/README.md), we choose one integer power-of-two reciprocal gain for each of Qwen3-0.6B layer-0's 64 RoPE coordinate pairs. It is folded into the existing 128 BF16 Qgamma and 128 BF16 Kgamma fields: the complete replacement image remains **512 B**, identical to the original gamma allocation, with no new inference exponent array or multiplication. All replacement fields are exactly BF16 representable and normal (no zero/subnormal/overflow). On all **8 train + 4 inspected-held** original 256-token windows, independently decoded replacement gamma produces bitwise-identical rotated Q/K up to the specified power-of-two factors, and bitwise-identical complete causal scores, softmax probabilities, both head outputs and two-head post-O result. This is the canonical **CPU BF16 replay**, not a proof of bitwise native GPU behavior or an altered whole-model checkpoint deployment.

After recomputing a diagnostic optimal shared key centroid under the changed coordinates, the finite-Gaussian positive-feature *mean pairwise variance exponent* falls from **395.2444 to 51.0563 on train** and from **429.1943 to 52.8848 on inspected held**. Both numbers are still large; this study does **not** evaluate, fit or export another positive-feature reader. The actual complete attention function is unchanged. [Parent work](../reciprocal-attention-gauge/README.md) owns the general covariance objective, rational proof and finite toy; this directory owns the paid BF16 image, source arithmetic and captured behavior. Reciprocal Q/K scaling with an equal-scale RoPE-pair constraint is established prior art in [QServe SmoothAttention, §IV-B](https://arxiv.org/html/2405.04532v1#S4.SS2); this source's post-normalization gamma fold and declared positive-feature covariance objective are the scoped adaptation here.

## Exact declared law and analytic one-choice preparation

The source is the pinned Qwen3-0.6B BF16 checkpoint SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b` and producer fixture SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`, with the original Q head0/head1, shared K/V, Q/K gamma, RoPE and O. `attention-consumer/measure.py` supplies the original BF16 projection, norm and rotary helpers. Inputs to geometry are the two original post-Qnorm/RoPE query vectors `u_hi` and original post-Knorm/RoPE shared keys `v_j`, each divided by `128^(1/4)`; their dot is the original attention score. **Train pair measure:** equal mass on both heads, all eight train windows, and every one of the 32,896 lower-triangular `(i,j≤i)` pairs in each window. This is not equal-query then equal-prior sampling. No held information enters the gains.

For each RoPE pair `(t,t+64)`, let `a_t=E||u_pair−E u_pair||²`, `b_t=E||v_pair−E v_pair||²` under that law. [`prepare.py`](prepare.py) accumulates the requisite weighted query/key moments without storing the pair matrix, verifies **all 64 a,b positive**, computes the real minimizer `e*=¼ log₂(b/a)`, and compares only integer `floor(e*)` and `ceil(e*)` in the closed expression `a·4^e+b·4^(−e)`, with lower-e ties. No numerical gain sweep, held gain selection or fitting to output loss. Chosen gains `λ_t=2^e` have distribution `e=-2:1, -1:5, 0:52, 1:3, 2:2, 3:1`: **12/64 nontrivial pairs**, range `[−2,3]`. Original paired query covariance trace is positive (range `.03038..3.68551`) and paired key trace is positive (`.02865..330.09547`). The cross-covariance trace is invariant because Q and K gains are reciprocal, and after optimal key translation the mean exponent is `Σ_t(a_t4^e+b_t4^-e)+2Σ covariance(Q_t,K_t)`.

The full `e` list in [`prepare.json`](prepare.json) is **offline preparation evidence**, not a reader field. Actual [512-byte BF16 gamma image](balanced-qk-gamma-bf16.bin) SHA256 `c8173158c88975e808804bb89a9e59b4cfa485a60f8d854fc4963ad89c830865` replaces the source's original 512-byte Q/K gamma image (original concatenated SHA256 `cae8b69bdb89082b436e1d2c1a0314f245f051a2f17b6026a68dac5bb2b2e79f`); first 256 B Qgamma, next 256 B Kgamma, each BF16 little-endian. The two indices of a RoPE pair receive the same Q factor and reciprocal K factor. Gamma is applied *after* RMSNorm in this source, so no norm-statistic redefinition is needed; paired diagonal powers commute with RoPE. [`reader.py`](reader.py) imports no fit routine: it parses all 256 BF16 fields directly, checks image and original hashes, verifies every Q/K ratio is a reciprocal exact power of two with equal paired indices, all original fields nonzero and all new fields normal finite. `prepare.py` independently checks exact BF16 roundtrip at every field. There is no gamma overflow, underflow, scale descriptor or online diagonal multiply. A future changed feature reader would still pay its own table, live state and any key-centroid fields; the **diagnostic centroid below is not in this 512-byte image**.

## Actual unchanged complete consumer

[`observe.py`](observe.py) reads the replacement image independently and runs both original Q/K/V/O heads, original fixture states and original/changed gamma through the **same** canonical 256-token causal consumer. It compares rotary Q/K coordinatewise against the original times reciprocal powers, complete visible scores, attention probabilities, each projected head output and combined two-head GQA output. [`aggregate.py`](aggregate.py) requires every window and combines squared output numerators/denominators. Results:

| Panel | Windows | Q/K rotary equal to prescribed powers | Causal score equality | Probability equality | Both head post-O equality | GQA pair post-O rel sq |
| --- | ---: | --- | --- | --- | --- | ---: |
| train | 8 | Bitwise | Bitwise | Bitwise | Bitwise | **0** |
| inspected held | 4 | Bitwise | Bitwise | Bitwise | Bitwise | **0** |

Every reported maximum absolute difference is zero in these actual CPU receipts. The original fixture's first 128 Q weight rows are checked elementwise against the source checkpoint. This is an *observed* bitwise invariant on the fixed capture/canonical CPU arithmetic; the analytic real-map identity applies to all source inputs for which gamma folding and RoPE commute, while backend-specific native floating-point instruction behavior is not claimed byte-identical without a separate native check. Full source static two-Q/K/V/O/gamma state is 1,573,376 B in every arm, with the same 512 B gamma allocation. No source Q/K/V/O weight, external K/V cache, observer or checkpoint elsewhere was refit/deployed.

## Balanced source geometry only

[`geometry.py`](geometry.py) pins and reuses the original [all-window gauge geometry reader](../qwen-kernel-gauge-screen/screen.py), changing only its gamma source to the independently decoded paid BF16 image. It computes a **fresh shared key centroid from train pairs after the actual BF16 gamma replacement**, rather than numerically transporting a stored unbalanced center. Its diagnostic FP64 vector [`train-balanced-center-f64.npy`](train-balanced-center-f64.npy) SHA256 `15ecf7b5a73b3cfe80ebcc08ab4f6ba286e852bff02ef180bf8b71622043a5b0` has 1,024 raw payload bytes (1,152 B NumPy artifact), squared norm `100.827976`; it is **not an inference operand**. If a future positive-feature reader uses it, that reader must serialize and charge an actual center (for example 256 B after a separately checked FP16 rounding), key subtraction and feature work. No such reader was run here. [`results.json`](results.json) pins the prior unbalanced-centroid results SHA256 `a1504c3f347010679f116ca814da491e7a18898b7657757051487428e52b5ddd`, retains all twelve new geometry/consumer receipts and checks the train centroid identity.

| Panel, two-head equal-pair mean exponent | Original Q/K, optimal old center | **Balanced BF16 Q/K, optimal new center** | Balanced centered exponent minimum head0/head1 |
| --- | ---: | ---: | ---: |
| train | 395.2444 | **51.0563** | 14.633 / 18.630 |
| inspected held | 429.1943 | **52.8848** | 14.333 / 17.863 |

The train balanced mean matches the covariance formula in `prepare.json` to floating arithmetic. The held panel uses **that same train-derived integer gain vector and train-derived centroid**; neither is retuned. Even the minimum centered exponent would make the *ideal iid Gaussian positive-product* per-score relative-variance expression `(exp(exponent)−1)/64` large, but that does **not** lower-bound normalized attention/output error or other deterministic/source-specific positive features. This result establishes that a huge part of source geometry can be removed by an exact, paid-neutral gamma/rotary coordinate change, and establishes no new kernel-quality result.

## Reproduction

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
$PY research/isa-quantization/qwen-balanced-gamma/prepare.py
$PY research/isa-quantization/qwen-balanced-gamma/geometry.py center
for i in 0 1 2 3 4 5 6 7; do
  $PY research/isa-quantization/qwen-balanced-gamma/observe.py train "$i"
  $PY research/isa-quantization/qwen-balanced-gamma/geometry.py train "$i"
done
for i in 0 1 2 3; do
  $PY research/isa-quantization/qwen-balanced-gamma/observe.py held "$i"
  $PY research/isa-quantization/qwen-balanced-gamma/geometry.py held "$i"
done
$PY research/isa-quantization/qwen-balanced-gamma/aggregate.py
```

Each command is CPU1 and under a minute. Source model/fixture, original gamma and earlier geometry results are pinned and reused, not rewritten. No GPU, new capture, feature table rerun, new rank, K/V fit or native inference claim.
