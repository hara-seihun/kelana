# Group-indexed key affine absorbs the full causal gain fit

The [shared key-affine fold](../rope-gain-fold/README.md) recovered roughly four-fifths of the group-specific causal gain's held KL reduction without adding bytes or arithmetic. The remaining fifth does not require a second multiply. Replace the 128-element shared BF16 key RMSNorm affine with an `(8,128)` head-indexed BF16 affine. The normalization already performs one multiplication per key coordinate; its operand now depends on the KV group. The cost is a larger affine table and group-dependent addressing, not another 224 multiplies per key token.

For group `g` and plane `i`, let `u_g=W_g x`, `d_g=sqrt(mean(u_g²)+epsilon)`, and `gamma_i` be the existing affine. Put `gamma'_{g,i}=a_{g,i} gamma_i` on **both** coordinates of the selected RoPE plane, leaving unselected coordinates at `gamma_i`. The real-arithmetic map `(u_g/d_g) gamma'_{g,i}` equals multiplying the post-normalized selected key plane by `a_{g,i}`. Its scalar commutes with that plane's rotation. The denominator is unchanged. Neither the 128 original key coordinates nor an int4 intermediate needs reconstruction at the attention boundary. This is a reparameterization of the *normalization consumer*, not a fold into upstream K projection rows.

I replayed the preceding frozen FP16 gains and 112-plane masks. The teacher remains the original Q/K. The group affine values were rounded to BF16, then run through the same CPU BF16 RMS normalization and FP32 RoPE/score as the shared-affine control. Each of four previously inspected validation windows uses every causal query and key. The separately stored gain arm instead scales captured FP32 plane score contributions, so its numerical map differs slightly.

| Layer | Unit KL | Shared BF16 affine KL | Separate FP16 gain score KL | Group BF16 affine KL |
| ---: | ---: | ---: | ---: | ---: |
| 0 | .301353 | .243792 | .229977 | **.229924** |
| 14 | .432293 | .362446 | .343686 | **.343980** |

All four windows improve over the shared BF16 arm in both layers. The group-BF16 map retains the whole previous gain to within .0003 KL at layer 14. This is an original-producer CPU attention result, not a paid sub-bit Q/K image, post-O behavior, fresh text, complete-model quality or native latency.

The original affine has 128 BF16 values (256 bytes). A dense group-indexed affine has 1,024 BF16 values (2,048 bytes): **1,792 added bytes per layer**, or 50,176 bytes across 28 layers. If the Q/K matrices have 3,145,728 weights per layer, that is .004557 added bits per Q/K weight. The selected-plane key cache still uses 512 padded BF16 bytes per occupied token per layer and 448 score products per key across both query heads. There is no additional normalization multiply or per-key score instruction. The group-indexed affine needs a different norm-table address and may alter cache requests, register use and load scheduling; no native instruction-count or latency claim follows. A sparse override table would save metadata but need indexed selection online, so the dense table is the simple constant-work candidate. The shared fold remains the cheaper storage point; the dense group affine buys the last .013868/.018465 KL of this fixed-mask original-producer fit.

The next paid selected-row sub-bit Q/K study can carry both representations as explicit controls. Fit against quantized-producer two-head post-O or gold loss, then freeze on fresh text. A group table should only be selected if its gain survives that continuation and its extra 1,792 bytes and changed lookup schedule beat the shared table at native cost. A separate post-normalization multiply is not the default implementation of group gains.

`measure.py` replays the two frozen layers. `/path/to/workspace/data/kelana-subbit/rope-group-affine/layer{00,14}.json` stores four-window scores, the 1,024 BF16 affine values and source/model/capture/prior hashes. From the Kelana root:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-group-affine/measure.py --layer 0 --output /path/to/workspace/data/kelana-subbit/rope-group-affine/layer00.json
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 $P research/quantization-discovery/subbit/rope-group-affine/measure.py --layer 14 --output /path/to/workspace/data/kelana-subbit/rope-group-affine/layer14.json
```

No GPU, Bonsai executable or resident service changed.
