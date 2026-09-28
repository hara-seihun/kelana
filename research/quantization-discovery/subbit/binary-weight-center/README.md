# A shared-input-sum correction does not rescue the paid binary reader

The paid Qwen3-0.6B binary `mlp_up` factors need not reconstruct the input-factor rank response literally. I tried a constant correction to each packed sign row. It reads one shared sum of the pre-scaled input and adds a learned multiple at each rank coordinate before the output-factor A7 ladder. A second arm applies the same idea at the complete output. Both retain packed one-bit signs and avoid int4 expansion. Neither is a useful frozen-image selection: first-stage fitting loses held complete response on three of four layers, and output fitting loses on all four. More importantly, even a held-data oracle for the entire output-correction family can improve RMS by only 0.4–0.43% on these inputs. Centering the **dynamic rank groups** at the second A7 stage, as the [affine rank reader](../binary-affine-rank/README.md) does, is a different map and improves 5.3–7.0%.

## Map and exact family limit

Write the paid factor product as `diag(post) U V diag(pre)` with packed signs `V` and `U`. Let `x` already include `pre`, `s(x)=sum_j x_j`, and let `h_A7(x)` be the first signed-seven-bit integer-ladder response scaled to real units. For each rank row choose a constant `c_r`, then send `h_A7,r(x)+c_r s(x)` through the same output-factor A7 ladder. This is the response of real first-factor row `V_r+c_r 1` up to the existing first-stage quantization. The FP16 constants change the real weight map intentionally. They cost 768 bytes for 384 ranks, or 0.001953 BPW of a 3,072-by-1,024 dense projection, in addition to the frozen packed-factor image. The online reader pays an input sum over 1,024 coordinates, 384 FP16 coefficient loads and 384 real multiply-adds before the second quantizer. It still pays both packed sign reductions, A7 selectors, intermediate traffic and output scaling. The first-stage fitting objective minimizes `sum_{x in train,r}(xV_r^T-h_A7,r(x)-c_r s(x))²`; each coefficient has the closed-form ratio of residual/sum cross-product to the sum's squared norm. The deployed image would round those fitted coefficients to FP16. No weight expansion is required.

A separate output arm uses `y_A7(x)+s(x)d_o` after the complete two-factor reader. It needs 6,144 FP16 bytes, 0.015625 dense-matrix BPW, one shared input sum and 3,072 products/additions. Given a fixed input panel `X` and complete-reference response `Y`, its best unrestricted real coefficient for every output is

`d_o* = sum_i s_i (Y_io-y_A7,io) / sum_i s_i²`.

This is the orthogonal projection of each output residual onto the one-dimensional activation statistic. It is an **exact lower bound on achievable panel SSE** for *any* coefficient vector in this output-correction grammar, before FP16 rounding or native cost. It is not a bound on groupwise affine quantization, nonlinear input features, refitted signs, or composed model loss. The statistic depends on the current input, so fitting it is not an offline bias correction that can be folded into `post`.

## Fresh held panel

`measure.py` loads the paid `.55` U/V images and the original-producer `mlp_up` fixtures for layers 0, 7, 14 and 27. It fits 128 `train[512:640]` rows and evaluates 128 disjoint `validation[576:704]` rows. The reference is the unchanged paid signs' FP64 two-factor response, not original dense teacher logits. Both stages use the safe `.75` two-choice A7 ladder. The output arm's oracle is selected **on validation** only to bound this family; it is not a deployable fit.

| Layer | Symmetric held RMS | Fitted rank-row center | Fitted output center | Held oracle output center | Train/held output-center cosine |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .01756815 | .01755483 | .01761642 | .01749834 | .034 |
| 7 | .01635172 | .01638776 | .01640980 | .01629185 | -.100 |
| 14 | .01609515 | .01609976 | .01614977 | .01602790 | -.046 |
| 27 | .01104641 | .01109964 | .01113665 | .01099894 | .048 |

Training response improves for both fitted arms on all four layers. Held first-stage reconstruction *worsens* under the rank-row fit on all four layers. The output fitted and held-oracle coefficient directions are close to orthogonal or opposed, and even the held oracle removes little complete error. Merely paying for more shared-sum corrections is not a promising frozen-image direction. This same-image limit does not constrain a correction fitted to the original dense teacher: [the output-scale study](../binary-output-gain/README.md) finds that larger teacher-response calibration can improve held error without adding bytes. The strong second-stage dynamic-center result attacks the A7 activation-cell geometry instead of projecting error on a stationary rank-one input statistic.

Run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-weight-center/measure.py` from Kelana's root. The [receipt](/path/to/workspace/data/kelana-subbit/binary-weight-center/receipt.json) binds source, paid images, input fixtures, fitted FP16 constants, first/second stage outputs and per-input held errors. This was a CPU original-producer panel. No GPU, full-model loss, native time, Bonsai executable, service or default changed. The next useful construction is to fit the dynamic *second-stage* affine reader against quantized-producer composed MLP behavior, and to price its center correction inside a full native two-factor reader if that quality survives.
