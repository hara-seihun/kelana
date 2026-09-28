# Exact tied rows selected for gold loss or embedding error

The K256 Qwen3-0.6B tied image leaves room for 2,560 exact rows at 0.895325 bits per unique tied weight. Which rows should get those bytes? On fixed original-model head inputs, a ranking by train gold-token loss fits the training sample much better than frequency, but loses on held next-token NLL and input embedding error. Ranking by train token occurrence times squared embedding reconstruction error nearly preserves the frequency plan's held NLL and embedding RMS, while reducing held teacher KL from 1.06488 to 1.00130. This is a useful rate-allocation signal, not a quality-matched int4 result or a quantized-model continuation.

## The exact selection objective

For head input `t`, let `b_ti` be the base codebook score, `d_ti` the change when row `i` becomes exact, `y_t` the gold row, and `Z_t = sum_i exp(b_ti)`. Replacing a set `S` changes its mean cross-entropy by exactly

```
Delta NLL(S) = mean_t [log(1 + sum_{i in S} exp(b_ti) * (exp(d_ti) - 1) / Z_t)
                       - 1[y_t in S] * d_t,y_t].
```

The row gain used here is `-Delta NLL({i})` after fixing the first 1,280 frequent rows. It is an exact one-row counterfactual on the fit inputs, not a sum certificate for the whole selected set. The shared log partition couples rows; subsequent gains change with the selected set. For the embedding consumer, replacing row `i` removes `train_count_i * ||w_i - decoded_i||²` from train occurrence-weighted squared error. These two quantities are normalized over positive row gains and embedding gains, then combined at fixed weights 0, 0.5 and 1 before taking another 1,280 rows. No held sample selects the mix.

The source matrix, base labels and scales, 1,280 frequent anchors, 2,560 exact-row payloads and two train-fitted rare-logit scalars have the same paid rate in all arms: 17,412,108 bytes. Online the head prepares the same 64-by-256 response table, consumes 64 entries for each of 151,936 rows, and performs 2,560 exact 1,024-element BF16 row dots. The input consumer decodes one codebook row unless it finds an exact ID. Row selection is offline; it cannot be used to claim a faster native kernel. The exact-row ID and BF16 payload images, score arrays and hashes are retained under `/path/to/workspace/data/kelana-subbit/gold-row/`.

## Separate fit, calibration and held observations

The pinned WikiText train capture supplies 128 head inputs at offsets 4,12,...,252 in four 256-token windows for ranking. A disjoint 32 inputs at 0,32,...,224 calibrate the same two rare-logit scalars separately for each image. The 64 held validation head inputs and gold labels from the tied-head study measure head quality; the entire separate validation corpus supplies occurrence counts for embedding error. The original final hidden inputs stay fixed. Nothing propagates the approximate embedding through the 28 layers. The reference held NLL is 3.61026.

| Exact-row allocation | Fit uncalibrated NLL | Held calibrated NLL | Held teacher KL | Held top-1 / 64 | Held embedding RMS | Held token coverage |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2,560 frequent | 4.50798 | **4.62868** | 1.06488 | 52 | **.41641** | 78.16% |
| 1,280 frequent + 1,280 gold-gain | **3.66423** | 4.69246 | 1.05954 | 48 | .46079 | 72.97% |
| 1,280 frequent + 1,280 joint | 3.72490 | 4.75632 | 1.07408 | **53** | .41707 | 77.84% |
| 1,280 frequent + 1,280 embedding-gain | 4.57576 | 4.63478 | **1.00130** | 52 | .41643 | 77.90% |

Gold-gain ranking buys 0.844 nats of uncalibrated fit NLL but costs 0.064 nats of *calibrated* held NLL and 0.044 embedding RMS against frequent rows. Its train calibration NLL also falls, 6.278 to 5.914, so recalibrating on separate train positions does not remove the held loss. The 0.5 mix is not a compromise on NLL. The embedding-gain plan improves teacher KL by 0.06357 at nearly equal head NLL (+0.00609) and embedding RMS (+0.00002); it does not beat the frequent plan on all observations. The 64 held tokens are too few to select an allocation for deployment. The gold-only loss rejects this small-sample one-row ranking, not gold-token training in a richer representation.

The next construction should learn rare-row responses with more independent head and embedding training inputs, optimizing the *joint selected-set* log partition rather than summing single-row gains. Then pass the shared quantized embedding through the model and compare a complete loss/rate/cost point. Merely swapping frequent exact IDs according to 128 training head inputs is not the missing capacity.

[`study.py`](study.py) regenerates fit, calibration and held score matrices in three bounded CPU jobs, then selects and assesses the four images. The data receipt identifies source, pinned images, split arrays, images and the paid payload. The GPU and resident service are not touched.

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for step in fit tune held assess; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/gold-row/study.py "$step"
done
```
