# A shared narrow value observer for GQA

[The layer-0 ridge-seeded paid decoder](LAYER0-RIDGE.md) improves held original-producer causal post-O error .385779 to .381749 at unchanged 183,552 bytes and online work. Direct rounding of its stronger continuous solution loses; two train-only code/scale sweeps recover an advantage on each of four held windows. Fresh gold loss and quantized-producer transfer remain open.

[Fresh model loss after causal-ridge fitting](RIDGE-MODEL-LOSS.md) improves layer-14 quantized-producer test NLL from 13.28466 to 13.09549 at unchanged 183,552 V/O bytes on twenty separate windows. An equally fitted uniform-rank control scores 13.10861; rank selection no longer separates reliably. The damaged producer's original V/O scores 13.09840. Work on the early composed model before another layer-14 sweep.

[Regularized causal left-code fitting](CAUSAL-RANK-FLOOR.md) changes the layer-14 quantized-producer image at unchanged .466797 V/O BPW and factor work. Four leave-one-train-window-out ridge fits select a penalty before validation; rounding the selected decoder to the existing two-bit left codes improves held causal post-O error .336551 to .303868 for selected ranks and .336175 to .310756 for uniform ranks. The unconstrained real fit catastrophically overfits, so this is a useful paid fit and a warning against driving four-window train response error toward zero. Its separate fresh model-loss comparison is linked above; native timing remains open.

[The exact eight-group paid-gain fit](CAUSAL-GROUP-GAIN.md) tests a cheap repair of the layer-14 quantized-producer gap. On four train windows the optimum moves existing group scales by at most .4%; held causal error changes .336551 to .336186 after FP16 storage for selected ranks, while a held-only oracle at unchanged bytes reaches .312639. The frozen-image train objective, not an omitted group-gain solver, is the obstacle. Broader composed producer/consumer fitting is the next question.

[New right coordinates on quantized producers](RIGHT-TRANSFER.md) lower layer-14 held causal post-O error from .484360 to .336551 for the 192-coordinate selected-rank image, at the same .466797 V/O BPW and online work. Equally trained uniform rank 24 scores .336175; the old rank-selection edge disappears. This is four held validation windows and a CPU observer, not model loss or native speed. The remaining train/held gap calls for fresh-text propagation before selecting a native layout.

[Quantized-producer transfer](PRODUCER-TRANSFER.md) changes the rank-allocation decision at layer 14. After the first fourteen layers use the refined binary body image, the original-producer selected 192-coordinate V/O allocation loses to equal-rate uniform on held causal post-O response (.9202 versus .9012). Two train-only sweeps of its paid output codes and scales recover a .4844 held error versus .4926 for equally refitted uniform; both still have a large train/held gap. The right basis is unchanged. This is an actual upstream-produced input and a matched-rate CPU observer, not model NLL or native timing.

Quantizing all Qwen3-0.6B V/O projections independently is costly for quality. The [complete-model attention ablation](../RESULTS.md) leaves Q/K and FFN exact yet gives test/validation NLL 8.1202/8.1129 when all V/O images are quantized, against 3.3108/3.9052 original. This study does not claim to repair that model. It finds a local representation in which each GQA value group uses one 28-dimensional stored basis shared by both query heads, and both heads' output slices consume that basis directly. On original-producer captures at layers 0 and 14, the paid joint image improves the causal post-O response error over the existing independent binary V/O images at a slightly lower stored rate. The proposed narrow consumer does not need a reconstructed 128-dimensional value cache. The later HF quality replay uses padded coordinates instead of claiming a native cache implementation. [Equal-byte group-rank allocation](RANK-ALLOCATION.md) proves a conditional continuous optimum for a finite rank grammar and lowers held stacked-response error on both studied layers without more logical cache or factor terms; causal quality after code rounding is still open. [Causal coordinate pruning](CAUSAL-PRUNE.md) solves a different finite grammar on the already rounded rank-28 images: at .466797 V/O BPW, a train-selected 192-coordinate allocation lowers held post-O error versus uniformly keeping 24 coordinates by 6.05% at layer 0 and 3.83% at layer 14. It discards coordinates without retraining the codes or producer. [Non-prefix block selection](FREE-MASK.md) tests whether that prefix restriction is binding: at the same 192 coordinates, a twelve-start train-only exchange improves layer-0 held causal error .391723 to .390890, but returns the same .339522 allocation at layer 14. This small frozen-image gain points to fitting a new basis with quantized producers instead of further shuffling the old one. [Causal left-code refitting](CAUSAL-REFIT.md) first recovers part of the pruning loss without changing rate or online work: at .466797 BPW, train-selected ranks score .385779 and .330364 held post-O error at layers 0 and 14 against .407794 and .340384 for equally refitted uniform ranks. The right basis and original producers remain frozen. [Fresh single-layer loss](FRESH-LOSS.md) reveals why held post-O error cannot select the low-rate image on its own: layer-0 selected ranks beat refitted uniform on all twelve fresh test windows at equal bytes, but one of eight fresh validation windows reverses mean NLL, 6.05061 selected against 5.79216 uniform. Layer 14's paired NLL difference is near zero on both splits. The raw fresh windows and hashes are retained; native timing did not move. [Window-robust allocation](ROBUST-ALLOCATION.md) exhausts the same 6,371 frozen masks with a worst-train-window penalty. At layer 0, the train aggregate optimum is also the exact minimax choice, so this tail penalty cannot repair the fresh loss reversal. At layer 14 it trades a small amount of train mean error for .001298 lower held mean response error at equal rate. The next quality experiment needs a different observer or right basis with quantized producers, not another weighting of frozen block errors.

[A static-scaled one-byte narrow V cache](../value-fp8-cache/README.md) halves the 28-coordinate value-cache payload while keeping the paid V/O weights unchanged. E4M3 raises held original-producer causal post-O error only .378887→.379186 at layer 0 and .326195→.326527 at layer 14; one int8 scale per group loses badly at layer 14. Native conversion and quantized-producer language loss are open.

[Unequal-rank cache layout](LAYOUT-OPT.md) exhausts reordered and gapped 64-byte-line layouts for the actual 192-coordinate paid images. Both selected rank allocations fit all eight groups without a split into seven lines, at 16 group-line requests per key for separate heads. Uniform rank 24 needs eight lines for zero crossings. This changes the native layout comparison without changing a weight code or stored rate; requested lines are not latency. [The cache-coordinate cost study](CACHE-COST.md) finds a native layout tradeoff at rank 28. Eight compact 56-byte value groups occupy seven 64-byte lines per token but trigger 28 group-line requests for two independently scheduled GQA heads; eight padded 64-byte slots occupy eight lines but need 16 requests. A paired-head attention work unit can halve either request count without restoring the 128-wide values. This is a restricted layout bound and priced native experiment, not measured latency or a reason to choose an image with worse fresh loss.

## Algebra: the value basis belongs to the two consumers

Write `V_g` for one `128×1024` value projection, `O_h` for the `1024×128` columns of O belonging to query head `h`, and `a_{h,s,t}` for the original causal Q/K attention probabilities. GQA shares group `g` between heads `2g` and `2g+1`. Their output contribution at query `s` is

```
sum_{h in {2g,2g+1}} O_h sum_{t<=s} a_{h,s,t} V_g x_t.
```

For any invertible `128×128` matrix `G_g`, replace `V_g` by `G_g V_g` and *both* `O_h` by `O_h G_g^{-1}`. The expression is identical: the scalar attention coefficients commute with the same value-basis change for both heads. An independent factorization of V and O need not preserve that freedom.

For a narrow `r×1024` basis `B_g` and two `1024×r` decoders `A_h`, the online map becomes

```
z_{g,t} = B_g x_t
contribution_{h,s} = A_h sum_{t<=s} a_{h,s,t} z_{g,t}.
```

This is an approximation, not an invertible change of coordinates. It keeps only `8r` value-cache elements per token rather than `8×128`, and it never materializes the old value vector. The composed weight targets are `O_{2g}V_g` and `O_{2g+1}V_g`, not V and O separately.

The continuous starting point has a useful exact conditional optimum. Let `X` be the 2,048 original train inputs, `T=X V_gᵀ`, and stack the two O slices vertically into `O_pair`. A thin QR decomposition `T=Q R` followed by the SVD `R O_pairᵀ=U S Hᵀ` yields the best rank-`r` train-response approximation to the stacked outputs `T O_pairᵀ`. Set `B_g=(R⁻¹U_r)ᵀ V_g` and stack `A_h=H_r S_r`. Then `X B_gᵀ A_pairᵀ=Q U_r S_r H_rᵀ`. This is Eckart-Young on the actual train responses, with one shared input basis for both heads. It is not an optimum for the later attention probabilities, rounded codes, or validation samples.

## The paid image

`fit_direct.py` tests three frozen precision/rank points that fit below the independent binary V/O payload: 2/2 bits at rank 28, two-bit output plus four-bit input at rank 20, and 4/4 bits at rank 14. An odd signed grid, one FP16 scale per output row of each O slice, and one FP16 scale per input-basis row and 128 input channels are stored. A square-root coordinate balance precedes rounding. After quantizing the left decoder, a small least-squares solve repairs the input basis before its own quantization. The group descriptor records shapes, bit widths and scale group. The three families cost 208,640, 199,424 and 206,848 bytes respectively, counting all eight groups, both factor planes, every scale and 256 descriptor bytes. The original V and O together contain 3,145,728 weights, so the rank-28 image costs **.53060 bits per original weight**. The complete independently refined NanoQuant-derived V/O images cost 210,968 bytes or .53652 bits per weight, including their two 12-byte descriptors.

The best family at both layers is 2/2 rank 28, selected by *train causal attention output* after refinement. [`pack.py`](pack.py) combines its eight paid group images into one NPZ without changing any code or scale. The retained images are:

| Layer | Packed joint image | SHA256 | Parameter bytes | ZIP bytes |
| ---: | --- | --- | ---: | ---: |
| 0 | `/path/to/workspace/data/kelana-subbit/value-observer/layer00-joint-r28.npz` | `93b969a9dbde2c28a23862f5199c1db7e7a12080a836aafb8eed94f8170f420c` | 208,640 | 210,184 |
| 14 | `/path/to/workspace/data/kelana-subbit/value-observer/layer14-joint-r28.npz` | `6673197d16a29148f64b997a2007a004161bfe7d8277d77e7dcf4e6af273e4e4` | 208,640 | 210,184 |

The value basis is group-major; each left factor has 1,024 rows for the first head followed by 1,024 for the second. Its 2-bit codes and FP16 row scales stay bitpacked in the image. The joint image uses six stacked arrays, including all eight 16-byte left descriptors and eight 16-byte right descriptors. No original O binary factor, free post scale, hidden 128-dimensional decoder, permutation or extra dictionary belongs to the program.

## Causal consumer fit and measured result

The starting rank factors fit the composed train responses but lose to the independent images at causal attention output. With Q/K, headwise RMSNorm and RoPE unchanged, layer-0 validation post-O squared relative error is .47194 for the rank-28 seed versus .39579 for independent V/O. Layer 14 is .46013 versus .35247. The group-0 rank-28 continuous SVD tail alone is .49754 of train composed-output energy on layer 0. Rank reduction is not free.

`refine.py` freezes every input-basis code, right scale, rank and payload byte. It computes the actual original-Q/K causal attention mixture of each stored narrow basis on all eight 256-token train windows. With those features fixed, each output code has an exact squared-error conditional optimum before projection onto its paid 2-bit alphabet. Four coordinate sweeps also fit each existing FP16 row/head scale by nonnegative least squares. Validation never updates codes, scales or family selection. This changes 242,784 of the 458,752 output codes at layer 0 and 191,560 at layer 14. The original model's Q/K and RoPE stay exact; only V/O change.

The four validation windows supply 1,024 held-out original-producer inputs. Numbers are relative squared errors after causal attention and the O projection, against the original BF16 model's attention output. The CPU replay of original Q/K/V/O against the captured actual BF16 input to O differs by just 5.6e-6 at layer 0 and 7.1e-6 at layer 14 on validation. This is a close subgraph replay, not a language-model loss measurement.

| Layer | Independent binary train / validation | Joint rank-28 before fit train / validation | Joint rank-28 after causal fit train / validation |
| ---: | ---: | ---: | ---: |
| 0 | .33177 / .39579 | .42817 / .47194 | **.22282 / .37889** |
| 14 | .26231 / .35247 | .43049 / .46013 | **.16418 / .32619** |

The layer-0 held-out improvement is .01691 squared relative error, 4.3% of the independent control; layer 14 improves .02627, 7.5%. Each layer improves on all four validation windows. The [compact result](results.json) and full `layerXX-{direct,refined,joint}-consumer.json` receipts preserve the per-window values, capture and factor hashes, all three precision arms, and train/validation score. The packed joint image was reopened and scored independently; it reproduces the separate refined group images exactly.

There is an instructive failed alternative in `fit.py`. We tried retaining the independent O factor's packed 352-column left basis and factoring only the composed maps into that basis. Even with a *full-rank* value map inside that frozen basis, layer-0 group 0 has .58451 held-out composed-response squared error. Its rank-76 signed factor worsens to .86450. At layer 14 group 0 the corresponding floor is .20331. A fixed independently fitted O basis can be a severe obstruction before any value-code rounding. That is why the selected family learns both shared value coordinates and their two consumers instead of preserving the old O factor for convenience.

## Online work and next decision

For each token the selected program projects into eight 28-wide values, writes those BF16 values to the KV cache, applies the original Q/K attention weights to the narrow values, then uses sixteen two-bit `1024×28` head decoders and sums their 1,024 output contributions. The two factors use **688,128 signed-grid terms** per token: 229,376 input-basis terms and 458,752 output terms. A 16-wide WMMA tiling would pad rank 28 to 32, increasing that count to 786,432; model storage and the chosen cache layout still hold 28. The independent binary V/O maps require 1,605,632 signed terms across their four factor passes. These instruction types are not equal-cost operations.

A direct four-input, two-bit response table has 256 entries. The joint map would consume about 57,344 first-factor and 114,688 output-factor table reads and build at most 93,840 table entries by recurrence. This presumes reusing each unscaled input table across all eight groups and applying each right factor's FP16 group scale after its partial reductions. The independent binary images can themselves use eight-sign tables: 200,704 combined reads and 117,300 table additions. Neither packed-code path has a native gfx1151 timing receipt here. The narrow decoder pays for more scales: about 1,792 right group multiplications plus 16,384 left row/head scale multiplications per token, and up to 15,360 additions when summing sixteen output contributions. The independent factor paths have about 5,120 pre/post scale multiplications. Native fusion, register pressure, table placement, launch count, code unpack and partial-output reduction can erase an arithmetic-count advantage.

The value cache shrinks from 2,048 BF16 bytes per token to 448. K remains at 2,048 bytes per token, so the full K/V cache falls from 4,096 to 2,496 bytes per token, a 39% saving. Padding the narrow value width to 32 at a native boundary would instead give 2,560 bytes per token. No 128-wide V is needed online. Q/K projections and their attention probabilities are unchanged. Runtime scratch and cache traffic are separate from stored model bits.

This earns a native-consumer investigation, not an all-layer model win. The single-layer follow-up below measures model loss, but only two original-producer layers and the pilot windows have been compared. The all-layer independently quantized V/O model loses badly and errors interact with quantized producers and FFNs. Before claiming native latency or a broadly useful model improvement, test the joint map at additional layers, on fresh text and on quantized-producer captures, then implement a fused narrow-cache consumer against the same independent binary lookup baseline. If the consumer must materialize sixteen 1,024-vectors or cannot reuse the small two-bit tables, change its accumulation schedule rather than claiming that the factor count alone makes it fast.

## Frozen single-layer complete-model follow-up

[`evaluate_model.py`](evaluate_model.py) places each frozen rank-28 joint image into one original Qwen3-0.6B layer at a time. It expands the paid factors, writes their 28 coordinates into the first 28 slots of each 128-wide GQA value and O-head block, and leaves the other slots exactly zero. Both query heads in a group consume the same narrow value. This is a quality-only HF BF16 forward, not a native narrow-cache implementation or timing result. The matching independent refined binary V/O images replace those same two projections in the control. Q/K, all other layers, embedding and head remain original in both arms.

The fixed pilot four validation and four test windows each contain 1,020 next-token predictions. The study did not fit or choose an image on these windows. Each panel forwards the original model in the same four-window batch for its teacher. This batching differs from the one-window full-model pilot, so its BF16 reference NLL also differs slightly; comparisons here use this panel's matched teacher. All numbers below are means per prediction; argmax is agreement with that teacher.

| Changed layer | Arm | Paid whole-model bytes / BPW | Validation NLL / KL / argmax | Test NLL / KL / argmax |
| ---: | --- | ---: | ---: | ---: |
| either | Original BF16 | 1,192,099,840 / 16 | 3.90716 / 0 / 1 | 3.30660 / 0 / 1 |
| 0 | Independent binary V/O | 1,186,019,352 / 15.918390 | 8.89077 / 5.40987 / .18137 | 8.73188 / 5.85564 / .21373 |
| 0 | Shared rank-28 V/O | 1,186,017,024 / 15.918358 | **5.29513 / 1.64537 / .46275** | **4.90511 / 1.93385 / .45098** |
| 14 | Independent binary V/O | 1,186,019,352 / 15.918390 | **3.91794** / .02582 / .90490 | **3.30540** / .02223 / .92549 |
| 14 | Shared rank-28 V/O | 1,186,017,024 / 15.918358 | 3.93531 / **.02282** / .90294 | 3.30991 / **.02024 / .93725** |

Layer 0 transfers its held causal-output advantage to NLL by a large margin, though it remains far worse than the original model. At layer 14, the joint image lowers teacher KL on both splits and raises test argmax agreement but slightly loses NLL to independent binary V/O. A local squared-error improvement is not a guarantee of language-loss improvement. These are isolated substitutions, not simultaneous quantization of both layers or all 28.

[`full-model-results.json`](full-model-results.json) retains each window's NLL, teacher KL, argmax counts, paid bytes and hashes of the model, tokens, images, manifest and evaluator. The identical receipts reside at `/path/to/workspace/data/kelana-subbit/value-observer/full-model-layer{00,14}.json`; the committed report hashes those receipts. The original model's unique tied matrix is counted once. Reproduce a panel with the shared GPU reservation, one layer per bounded invocation:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
B=/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare
D=research/quantization-discovery/subbit/value-observer
$B --runtime-max 45s --exec "$P" "$D/evaluate_model.py" --layer 0
$B --runtime-max 45s --exec "$P" "$D/evaluate_model.py" --layer 14
```

## Reproduce

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-observer
for layer in 0 14; do
  $P "$D/fit_direct.py" --layer "$layer"
  $P "$D/measure.py" --layer "$layer" --variant direct
  $P "$D/refine.py" --layer "$layer" --sweeps 4
  $P "$D/pack.py" --layer "$layer"
  $P "$D/measure.py" --layer "$layer" --variant joint
done
$P "$D/summarize.py"
```

The frozen binary controls live in `/path/to/workspace/data/kelana-subbit/full-model/image-binary055-refined/`. The pinned BF16 model, original-producer captures, group images, final joint image and per-window receipts are in the data directory. Fitting was CPU-only. The model follow-up used two bounded GPU reservations; the resident service was restored and no serving map changed.
