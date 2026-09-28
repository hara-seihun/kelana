# Scalar corrections cannot rescue frozen Q3 expert directions

The complete actual-producer layer-0 Q3_K gate/up recode loses **.084997 held relative RMS** against decoded installed Q4_K. A paid FP16 gain per expert, fitted on 113 separate train tokens and applied to each Q3 expert's Q5_K down output before the weighted sum, **worsens held RMS to .086240**, although train improves .089569 → .088503. Even a free hindsight scalar for the *whole sum on every held token* only reaches .082993; eight free independent hindsight expert gains per token reach **.081500**. Thus at least .081500 held RMS remains in directions outside the span of the eight recoded routed expert outputs for this frozen image. This is a tight bounded negative for scalar-only repair of the Q3 recode, not a claim about retrained codes or other vector directions.

| Observed weighted-sum construction | Train RMS | Held RMS | Incremental image bytes per layer |
| --- | ---: | ---: | ---: |
| Frozen Q3 gate/up, original Q5 down | .089569 | .084997 | 0 |
| One global train-fitted scalar | .089564 | .085044 | 2 |
| Train-fitted FP16 scalar per expert | .088503 | .086240 | 512 |
| Free per-token hindsight scalar of sum | .088417 | .082993 | unavailable oracle |
| Free per-token hindsight eight independent expert scalars | .086598 | .081500 | unavailable oracle |

The oracle is the Euclidean orthogonal projection of the decoded-Q4 routed sum onto the span of the eight score-weighted decoded-Q3 expert outputs *separately for each token*. This grants the observer the target itself and arbitrary real scalars with no compute or metadata charge. Consequently no scalar-only correction using these frozen expert vectors, whether static, score-dependent, or input-dependent, can beat its **aggregate held squared-error** under this observation contract. The bound does not apply to new Q3 codes, vector-valued corrections, changed Q5 down weights or a downstream quality metric. FP32 implementation and full-model NLL are not certified by this real-valued post-output projection.

The paid table is exactly 256 little-endian FP16 gains (`gains.f16`, 512 bytes/layer); 169 experts occur in train, and 76 of 1,008 held routed slots refer to unseen experts and retain gain one. Gains before rounding span .807562–1.047623. Keeping this table across forty layers costs 20,480 bytes in addition to the Q3 images. If the same geometry and quality transferred, the conditional one-read byte saving relative to unchanged Q4 would be 89,108,480 of 2,626,187,904 bytes/token (3.393%). This is not actual DRAM traffic or native speed. The offline Q4 reference uses the exact same CPU FP32 gate/up, SwiGLU, Q5 down and FP64 eight-output summation as the Q3 arm; the per-expert reconstruction reproduces the original Q3 experiment's full per-token sums within 1e-7 absolute. Native FP32 reduction bits differ and no serving runtime was changed.

[Raw receipt](/path/to/workspace/data/qwen-moe/q3-scalar-correction/receipt.json) SHA-256 `6d43fa496609d25432af00a29c795d15203a6d43ab599102d0cee20f60901b53` records source, pinned library, original recode receipt and all eight packed Q3 bank hashes, capture hashes, per-shard decomposed expert outputs and the paid FP16 gain hash. It uses 113 actual train and 126 disjoint held layer-0 producer inputs, native router IDs and scores, and all 256 frozen expert images. The 8 stored decompositions are needed to reproduce the token-wise span bound and are not model payloads. CPU only; GPU reservation, installed Qwen and resident Bonsai service unchanged.

Reproduce from a Kelana writer with the installed library and existing Q3 image:

```sh
for i in 0 1 2 3 4 5 6 7; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 python3 research/moe/q3-scalar-correction/measure.py --part "$i"
done
OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 python3 research/moe/q3-scalar-correction/measure.py --combine
```

**Next:** correcting quantization-induced directions requires fitting the packed gate/up codes themselves or a paid vector correction against broader actual producer routes, followed by a frozen forty-layer image and held language loss. Another static or token-dependent scalar fitter on the same Q3 directions cannot cross this local oracle floor. Independent native Q8/expert phase diagnosis remains preferable before porting a mixed Q3 reader.
