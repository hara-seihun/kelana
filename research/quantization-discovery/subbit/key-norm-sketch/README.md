# A sparse key-norm sketch has a costly quality tail

The [paid-key denominator study](../key-rms-factor/README.md) found that estimating the full 128-row key RMS from only the score-selected rows fails on layer 14. I tested the next cheap family: retain the 224 score rows across eight GQA groups, compute a few additional *raw* binary-factor rows only for the denominator, and estimate the omitted squared energy. No weight expansion to int4 is involved in the proposed consumer. This experiment evaluates the BF16-expanded paid image for quality, not its native execution.

For a group, let `S` be its score-selected raw rows, `M` the other rows, and `y_i = BF16(raw_i)^2`. Partition `M` into strata `M_h`; sample `n_h` rows uniformly without replacement within each stratum. The estimate is

`d_hat² = (sum_{i in S} y_i + sum_h |M_h|/n_h * sum_{i in sample_h} y_i)/128 + epsilon`.

Uniform sampling is one stratum. The four-stratum arm sorts missing rows by their *training* mean squared output and splits that ordering evenly; every stratum gets the same number of draws. Each of eight fixed-seed independent maps keeps its row list for replay. Conditional on any fixed activation and training-derived partition, sampling is unbiased for the full BF16 raw energy. Its variance before division by `128²` is `sum_h |M_h|² (1-n_h/|M_h|) S_h²/n_h`, where `S_h²` is the finite-population variance of the missing row energies within stratum `h`. This is a statement about random design expectation, not a bound on a selected row list's error or on attention KL. Rounding the normalized output to BF16 and applying RoPE/softmax makes KL nonlinear in that energy error.

## Held causal attention

Both layers use the existing `.6245`-BPW refined binary K image, fixed 112-plane score masks and group affine. The denominator alone changes. Eight original-producer train windows determine the strata; the same four previously inspected validation windows evaluate every map. Original Q supplies the candidate scores and original Q/K the teacher attention; both query heads and every causal key are included. The full-denominator arm recomputes all 128 BF16 raw rows per group. The table averages causal teacher-to-candidate KL over groups and four windows, then averages over eight independent row draws. The range is across draws, not a confidence interval over text.

| Extra rows/group | Layer 0 uniform mean [range] | Layer 0 stratified mean [range] | Layer 14 uniform mean [range] | Layer 14 stratified mean [range] |
| ---: | ---: | ---: | ---: | ---: |
| Full 128 raw rows/group | .263253 | .263253 | .477637 | .477637 |
| 0, selected-only prior replay | .384417 | .384417 | .997543 | .997543 |
| 8 | .360353 [.324775, .406021] | .363191 [.327619, .433516] | .626022 [.574615, .696571] | .662831 [.583184, .735856] |
| 16 | .327252 [.300434, .361044] | .321261 [.299480, .348876] | .555252 [.432509, .648702] | .559160 [.473182, .685480] |
| 32 | .303382 [.287598, .313676] | .304696 [.290741, .322713] | .535079 [.490472, .586535] | .480677 [.453430, .503057] |
| 48 | .289697 [.281091, .303402] | .284402 [.278947, .291869] | .488067 [.454080, .508365] | .501477 [.462088, .544396] |

The zero-extra-row control comes from the hashed preceding [denominator replay](../key-rms-factor/README.md), not a new fit. The 32-row stratified sketch nearly matches the full paid-K denominator on layer 14, .480677 against .477637, while the group-average relative RMS denominator error is about .136. Four individual draws beat the full-denominator KL, but it loses clearly on layer 0. That is not evidence of a faithful norm or a selected model; all eight draws were inspected on the same held text. At 48 rows, the layer-0 gap remains .021149 for stratified, and layer 14's stratified gap is .023840. Unbiased reconstruction of squared energy is not the objective that selects a good attention map.

## Paid work

The binary K factor has rank 256, with 262,144 signed input terms/token/layer common to all arms. The full output stage has 262,144 terms. Selected score rows alone use 57,344 output terms; 16, 32 and 48 extra rows per group bring the output stage to 90,112, 122,880 and 155,648 terms. Total signed terms become 352,256, 385,024 and 417,792, reductions of 32.8%, 26.6% and 20.3% from 524,288. Squared reductions, reciprocal square roots, normalization, key-cache stores, irregular row addresses and occupancy are not included in this term count. The K code image is unchanged. A uniform sample needs one byte per extra-row index in each of eight groups, thus 128/256/384 bytes/layer at 16/32/48; a stratified sample also needs four FP16 population multipliers per group, another 64 bytes/layer. The selected score-affine table and plane masks are common to every arm. The CPU replay used FP32 population multipliers, so these metadata byte counts are a proposed native format, not tested FP16 quality. Nor does the BF16-expanded evaluation preserve the factor consumer's operation order.

This closes *small, untrained, row-sampling norm sketches on this frozen paid K image* as a cheap fidelity repair. It does not rule out learned rows, a factor-coordinate low-rank quadratic, a norm trained together with the selected score, or a different Q/K image. A useful next experiment is a low-rank PSD approximation to each paid K factor's Gram, with eigen-tail and BF16-rounding errors separated, then a held attention comparison to this row-sample cost curve. If a sketch instead deliberately changes attention temperature, select it on train causal/gold loss with quantized producers and independent held text; do not pick the best of these eight held draws.

The replay source is [`measure.py`](measure.py). Raw per-group, per-window, per-draw scores, row indices, estimator multipliers, relative norm errors and source/model/capture/image/prior hashes live in `/path/to/workspace/data/kelana-subbit/key-norm-sketch/layer{00,14}.json`. Reproduce one layer per bounded CPU command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/key-norm-sketch
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 0 --output /path/to/workspace/data/kelana-subbit/key-norm-sketch/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" "$D/measure.py" --layer 14 --output /path/to/workspace/data/kelana-subbit/key-norm-sketch/layer14.json
```

No GPU reservation, Bonsai executable or resident service changed.
