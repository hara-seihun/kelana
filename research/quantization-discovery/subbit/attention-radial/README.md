# Q-head radial gauge and asymmetric factor precision

The rank-88 attention-fitted Q factor uses four bits in both factors, but its next consumer RMS-normalizes each 128-dimensional head. Can the output factor lose a bit without paying proportionately in attention behavior? I kept the trained four-bit right factor and the same 270,336 factor terms per query, requantized the 2,048 × 88 left factor at two or three bits, and optimized its codes and existing FP16 row scales against the same attention objective as the four-bit image. This is a CPU study of the layer-0 Q projection on original Qwen3-0.6B inputs, not a quantized-model continuation or native timing result.

## A free coordinate choice, with a finite-precision boundary

For a nonzero head vector `z`, positive scalar `c`, mean square `m` and RMSNorm epsilon `e`, the real-valued normalized output satisfies

```
r_e(c z) = c z / sqrt(c² m + e) = z / sqrt(m + e/c²).
r_e(c z) / r_e(z) = sqrt((m + e) / (m + e/c²)).
```

The ratio is understood componentwise where the denominator is nonzero. At `e=0`, every positive head gain is an exact gauge symmetry, even after multiplying by fixed RMSNorm weights and applying RoPE and attention. At positive `e`, the displayed ratio bounds the real normalization change; it is close to one when `e/c²` is small beside `m`. This is **not** bit identity through Qwen's BF16 projection and RMSNorm casts. A gain also has to be common to all 128 outputs of one head. Independent row gains are not a gauge symmetry.

After code fitting, I chose one positive gain for each of 16 heads by least squares on the *train* raw Q responses, multiplied it into the already stored FP16 left-row scales, and rounded those scales back to FP16. It stores no new parameters and adds no online operation: the existing factor scales have different values. This gauge fixes an arbitrary raw amplitude left by fitting a nearly radial-invariant objective. It does not turn a damaged direction into a good one.

## Paid-rate and held-consumer results

The pinned fixture has 2,048 train and 1,024 held validation input vectors in eight and four separate 256-token windows. Original K, V, O, Q/K norm weights and RoPE are used for causal attention. Fitting uses 30 straight-through Adam steps at learning rate .2, optimizing both left codes and their paid FP16 scales with the four-bit study's `attention KL + 2 × post-O error + .5 × normalized-Q error`. Each left row is initialized by alternating least-squares scale and nearest odd-grid code. Validation enters no update. The seed is the [frozen attention-trained four-bit image](../attention-metric/README.md), not a newly trained rank or right factor.

| Q image | Factor bytes incl. scales/descriptors | Matrix BPW | Held attention KL | Held post-O relative squared error | Held raw-Q relative squared error |
| --- | ---: | ---: | ---: | ---: | ---: |
| Existing four/four-bit attention image | 140,704 | .53674 | .07776 | .01964 | .15121 |
| Strong four-sweep binary control | 141,324 | .53911 | .08164 | .02165 | .06962 |
| Three/four-bit, initialized | 118,176 | .45081 | .11038 | .02579 | .17620 |
| Three/four-bit, fitted | 118,176 | .45081 | .09243 | .02181 | 1.20210 |
| Three/four-bit, train head-gauge fixed | **118,176** | **.45081** | **.09242** | **.02181** | **.19304** |
| Two/four-bit, initialized | 95,648 | .36487 | .18746 | .04323 | .31432 |
| Two/four-bit, fitted | 95,648 | .36487 | .11288 | .02607 | .80469 |
| Two/four-bit, train head-gauge fixed | **95,648** | **.36487** | **.11290** | **.02608** | **.32442** |

The three-bit image saves 22,528 bytes, or 16.0%, against the existing four-bit image. It comes close to the higher-rate binary image's post-O error but loses attention KL by .01078, so this is **not** a quality-matched win. The two-bit image saves 45,056 bytes, or 32.0%, but loses more. Its three-bit competitor is better on both held consumer observations at a higher rate. Neither image has a measured native consumer, and three-bit extraction may cost more than four-bit extraction. A two-pass factor program still has 270,336 terms, two factor reads, scales, intermediate traffic and launches, instead of the 2,097,152 entries of a dense expanded int4 Q matrix. Counts alone are not latency.

The gauge is a useful diagnostic: raw-Q error for fitted three-bit codes falls from 1.20210 to .19304 with no extra storage, while held attention KL shifts by about `-0.000011` and post-O error by `-0.000007`. The differences are real BF16/epsilon effects, not exact invariance. A raw-projection MSE target would reject the un-fixed fitted image for a predominantly removable head-amplitude error. Conversely, a low raw error is no guarantee of the best attention behavior. The next rate/work question is whether a *higher-rank* two/four-bit pair at the same .45-BPW budget can beat rank-88 three/four-bit on held attention, and whether a native two-bit left pass actually spends fewer cycles. Do not build a three-bit kernel on this local quality evidence alone.

## Custody and reproduction

`fit.py` is the complete CPU experiment. It imports the established layer-0 consumer from `attention-metric/refine.py`; no GPU reservation or resident service was touched. The data owner [maps the images and receipts](/path/to/workspace/data/kelana-subbit/README.md). `/path/to/workspace/data/kelana-subbit/attention-radial/` retains both packed images, source/model/fixture SHA256s, train/held measurements before and after gauge fixing, optimizer traces and raw command output. The two-bit image SHA256 is `b0b2d56b4a817a85120610c290deab1fe7955e279aed2bc022726d276b9f064e`; the three-bit image is `3ad138d03ff01e92b5bd9bbd76455c1b05b035ed0555e5967c730a007f453ccb`.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/attention-radial
OPENBLAS_NUM_THREADS=1 "$P" "$D/fit.py" --bits 2 --steps 30
OPENBLAS_NUM_THREADS=1 "$P" "$D/fit.py" --bits 3 --steps 30
```
