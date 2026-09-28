# Quantize the query for a direct signed-nibble key dot

The paid four-bit key cache has a direct integer score consumer without reconstructing BF16 keys. Its missing operand is the query after multiplication by the 256 coordinate-specific key steps. Quantizing that prepared query to one signed nibble per coordinate loses too much attention quality; two signed-nibble dot passes recover nearly all of the float-query result on the existing causal captures. This is a CPU map experiment and an executable integer-dot construction, not a native timing or model-loss result.

| Layer | Floating prepared query | One signed-nibble dot | Two signed-nibble dots |
| ---: | ---: | ---: | ---: |
| 0 | .275403 | .290584 | .275431 |
| 14 | .332292 | .362763 | .332396 |

These are mean teacher-to-candidate causal KL over four previously inspected 256-token validation windows, both query heads and all eight KV groups. The paid binary Q/K producer, 128 selected RoPE planes, 256 coordinate-step FP16 entries, per-group train-selected raw/centered key arm and full raw K normalization are frozen from the [key-cache study](../key-nibble-cache/README.md). The floating query and both integer arms share **exactly the same signed key codes**. No held data selects the query scales: each query/head/group computes its own max absolute value. Every float-query-to-two-dot change is under .00035 KL on each of the eight layer/window aggregates; the one-dot arm loses .01518/.03047 mean KL at layers 0/14. The average absolute score change over all groups and windows is .2800/.3197 for one dot, versus .0165/.0191 for two. Maximum changes reach 4.93/4.63 and .250/.261 respectively. These maxima include terms that causal masking discards.

Let `c_j` be a stored signed key nibble in `[-7,7]` and `a_j=q_j s_j` the prepared real query at one head/group. Choose `d=max_j |a_j|/C` with `C=7` or `119`, and `z_j=round(a_j/d)` in `[-C,C]`. The candidate score over 32 selected coordinates is

```
S(q,c) = d * sum_j z_j c_j / sqrt(128).
```

For one dot, `z` is a signed nibble. For two dots, set `lo=((z+8) mod 16)-8` and `hi=(z-lo)/16`. With `|z|<=119`, both `lo` and `hi` are in `[-8,7]`, and the exact integer identity is

```
sum_j z_j c_j = sum_j lo_j c_j + 16 * sum_j hi_j c_j.
```

The CPU replay checks this equality over every measured query/key pair. Every dot sum is below 32 * 119 * 7 = 26,656 in magnitude, so signed int32 accumulation has ample headroom. Two signed-nibble instructions per eight elements are the intended gfx1151 `v_dot8_i32_iu4` lowering, with its signed source selectors; the *actual* operand packing, issue rate, query preparation, key loads and native FP32 rounding still need measurement. The key stays 128 bytes/token/layer, without a decoded BF16/int4 buffer. A 512-byte query-step table is shared by the cached keys; group centers cancel in real causal softmax, so the dot does not read them. The exactness claim is for integer accumulation and the real score formula, not native FP32 logits.

If rounding does not clip and `d>0`, each coordinate error is at most `d/2`. Hence a query's score error against **any** key code is at most `d sum_j |c_j|/(2 sqrt(128))`. If every score of a causal softmax is within `epsilon` of its floating-prepared-query score, Hoeffding's lemma gives `KL(softmax(S_float) || softmax(S_integer)) <= epsilon^2/2`. This is a conservative query-specific certificate; the actual causal KL above uses the teacher rather than the floating-query distribution. The proof does not bound the error from the lossy key producer or key-code quantization.

The two-dot choice costs 512 coordinate-step products, 512 query rounds/clips and a 32-coordinate absolute maximum for each of 16 head/group queries per token/layer; it then costs 1,024 signed-nibble products and 16 final score-scale multiplies per cached key. One dot costs 512 key products. At 256 occupied keys, that is 262,144 versus 131,072 integer products/token/layer after 512 activation-dependent query-preparation products, before instruction packing and key reuse. The full 1,024-row K producer remains unchanged. The 8-bit split buys quality at twice the dot arithmetic; the prior BF16 selected-cache route performs 512 BF16 products per key and reads four times the key payload, so traffic alone cannot decide a winner. Query quantization must be inside native timing. The prior int8 key cache uses half the BF16 payload and already has better observed attention KL on these captures than this nibble key image.

This result changes the native question. Test the two-dot program, not the one-dot arm, against the int8 and BF16 score consumers at actual contexts and with the full producer counted. First freeze fresh quantized-upstream and complete-model loss to make sure this key image is worth executing; none of these original-producer windows is independent acceptance text. No Bonsai runtime or service changed here.

`measure.py` replays the frozen paid image and writes per-group/per-window KL, absolute score errors, hashes and cost counts to `/path/to/workspace/data/kelana-subbit/nibble-query-lowering/layer{00,14}.json`. Run each layer with the installed CPU PyTorch environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/nibble-query-lowering/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/nibble-query-lowering/layer$(printf '%02d' "$layer").json"
done
```
