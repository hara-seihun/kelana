# A learned butterfly is too rigid as NanoQuant's first factor

The first factor of a binary matrix product has a tempting replacement: rotate the input with a fitted butterfly, keep some coordinates, and apply a short binary output matrix. It removes the dense `R×K` binary plane. At approximately .55 payload bits per matrix weight, the resulting representation loses to the ADMM-only NanoQuant comparator on early and late Qwen3-0.6B attention projections. The result is useful because the binary coefficients have an exact conditional optimum, so this is not a poor local fit of those coefficients. The remaining question is how to recover the missing input-side capacity without restoring its full storage and online work.

## Construction and conditional optimum

Let `W` have `N` output rows and `K` inputs, and let `D` be a positive diagonal input scale. A `log2(K)`-stage orthogonal butterfly `T` has one learned rotation for each pair at each stage. For one activation, the stored program computes

```
z = T (D^-1 x)
y_i = a_i sum_{j in S} C_ij z_j,       C_ij in {-1,+1}.
```

`S` is a common set of `R` coordinates, each `a_i` is a nonnegative FP16 row scale, and `C` is a packed binary matrix. Here `D²` is the 0.4-shrunk channelwise mean square on the 2,048 train activations. Its FP16 rounded values, all angles, `S` and `a` count as stored model parameters. There are no implicit permutations. The inference map never expands a weight matrix. A signed response table for every eight `z` values can consume each output row's eight packed signs in one lookup, followed by row reduction and scale.

For fixed orthogonal `T`, scale `D`, and common set `S`, set `P = W D T^T`. In the diagonal-covariance surrogate, the *global* optimum over each row's signs and nonnegative scale is `C_ij = sign(P_ij)` and `a_i = (1/R) sum_{j in S}|P_ij|`. Its exact minimized weighted squared error is

```
||W D||_F² - (1/R) sum_i (sum_{j in S}|P_ij|)².
```

We select `S` by aggregate absolute projection, then train the butterfly angles for 240 Adam steps on the eliminated objective, reselecting `S` at every step. Aggregate absolute selection is a heuristic for the *common-set* combinatorial optimum; the signs and scales given a selected set are exact. A separate 64-step activation refinement changes the angles by sampled 256-token train-response loss, periodically reassigning signs. At 384 refinement steps, early and late Q held-out response errors rose to .19033 and .27992, respectively, rather than improving; the 64-step variant is reported separately. The source `fit.py` runs on the unchanged CPU PyTorch environment. Seed 0, eight threads. It rounds stored values to FP16 and packs/unpacks signs before scoring. The train and 1,024 validation activations come from the pinned fixture manifest in `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/`; the known BF16 weights train the quantizer, and only activations are held out.

## Real-matrix results

Errors are relative squared held-out response errors. Each row uses its own known weight matrix, 2,048 train-token inputs, and 1,024 disjoint validation-token inputs. The comparator is the [matched NanoQuant ADMM-only report](../binary-factors/README.md), not NanoQuant's full trained system. These are isolated projections, not whole-model loss. The `O` rows use `N=1024,K=2048`, whereas `Q` uses `N=2048,K=1024`.

| Projection | R | Payload BPW | Fixed Walsh | Learned butterfly | With 64-step activation refinement | NanoQuant .55 target, actual payload BPW / error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Layer 0 Q | 496 | .55066 | .27397 | .16497 | .14867 | .53906 / .09666 |
| Layer 27 Q | 496 | .55066 | .30196 | .20020 | .17552 | .53906 / .11579 |
| Layer 0 O | 888 | .54974 | .53834 | .31076 | not run | .53906 / .29092 |
| Layer 27 O | 888 | .54974 | .77250 | .59430 | not run | .53906 / .48098 |

The Q fits buy nearly the same matrix payload but retain 54% and 52% more validation-response squared error than the comparator even after activation refinement. The O fits also lose, though their actual NanoQuant rate is lower. This is enough to reject native implementation of this *orthogonal, one-scale-per-row family* as a quality competitor, not to reject learned fast input programs generally. The `fit_weight_error` values in the machine reports illustrate why choosing by unweighted weight reconstruction is misleading.

For Q, payload bytes are 126,976 binary output coefficients, 10,240 FP16 rotation angles, 2,048 input scales, 4,096 row scales and 992 coordinate indices, totaling 144,352 bytes or .55066 BPW. For O they are 113,664, 22,528, 4,096, 2,048 and 1,776, totaling 144,112 bytes or .54974 BPW. A NumPy ZIP adds 1,498 bytes to each image and is not included in the parameter rate. There are no uncharged row permutations, free preconditioners or decompressed weights. These are matrix rates; retained embeddings, head, norms, scratch and KV require separate accounting for a whole-model rate.

## Direct-consumer cost, not a speed claim

For one Q vector, the butterfly costs 5,120 pair rotations, 1,015,808 signed output terms if evaluated arithmetically, or 15,810 eight-sign table-build additions and 126,976 output table reads if the second stage uses lookup. Its table occupies 31,744 BF16 bytes. Model payload read is at least 144,352 bytes, plus at least 6,144 BF16 bytes for input and output. Keeping butterfly intermediates in registers or shared memory requires placement across ten stages; a materialized transform writes and reads another 4,096 BF16 bytes. Every pair rotation takes four multiplies and two additions, and an implementation must count indexing, gathers, table reduction, register pressure and launches.

At the matched Q rank 352, NanoQuant's packed first factor plus packed second factor uses 1,081,344 signed terms if expanded to signed arithmetic. Eight-input lookup instead builds 128 response tables and consumes `352×128 = 45,056` first-stage table reads, then builds 44 tables and consumes `2,048×44 = 90,112` output reads. Table construction costs 32,640 plus 11,220 additions using a one-step-per-entry recurrence; the two sets of BF16 response tables occupy 65,536 plus 22,528 bytes if both are materialized, but can be streamed. Its two packed planes and scales use 141,312 payload bytes. A fused kernel may avoid its 352-element intermediate write/read; a nonfused consumer adds 1,408 BF16 bytes. Both competitors need reduction of their lookup responses. NanoQuant's first stage can also be shared by joint Q/K/V, and expanded factors may suit WMMA especially at prefill batch sizes. Conversely, butterfly stages have inter-stage dependencies. Neither raw signed-term count nor compressed byte count establishes a native gfx1151 speed advantage. This report contains no kernel timing.

## Next decision

Do not spend the next GPU reservation building this butterfly consumer. The tight conditional optimum says that exchanging the 360k-bit dense Q input plane for 5,120 angles while spending the freed bits on more binary output coordinates loses too much learned subspace capacity. Try a *block-pattern coded input factor* instead: for each group of eight input channels, learn a dictionary of sixteen eight-sign patterns, store one four-bit label per group and factor row, and compute those sixteen activation responses once per group. At Q rank around 400 the input labels cost `400×1024×4/8 = 204,800` bits rather than `400×1024 = 409,600` bits, with 128 local dictionaries of `16×8` signs costing another 16,384 bits. The second factor costs `2048×400 = 819,200` bits, before scales and alignment. The first-stage lookup now uses about 51,200 response reads and 16,384 pattern bits, rather than rebuilding an arbitrary 256-entry table for each eight-channel group. Fit the dictionary and the second factor jointly on the same train activations. This keeps much more trainable input-side geometry than a butterfly, retains a direct native lookup program, and should be compared to the binary factor's *own* lookup rather than to an arithmetic unpacking strawman. The dictionary may fail if sixteen local patterns cannot approximate the needed correlated sign blocks; that failure has a clear measurable capacity diagnosis. This experiment is distinct from merely sweeping more butterflies or ranks.

## Reproduce and custody

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/fast-transform
F=/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext
$P "$D/fit.py" --fixture "$F/layer00-self_attn_q_proj.npz" --rank 496 --steps 240 --activation-steps 64 --output "$D/layer00-q_proj-activation.json"
$P "$D/fit.py" --fixture "$F/layer27-self_attn_o_proj.npz" --rank 888 --steps 240 --output "$D/layer27-o_proj.json"
```

The four unrefined JSON reports and two Q refinement reports live beside this document. The stored packed images and their ZIP byte counts live at `/path/to/workspace/data/kelana-subbit/fast-transform/`. Every image contains one packed sign plane, one flattened FP16 angle vector, uint16 selected indices, FP16 pre/post scales and dimensions. No model weights, activation fixtures or generated binary images belong in Git.
