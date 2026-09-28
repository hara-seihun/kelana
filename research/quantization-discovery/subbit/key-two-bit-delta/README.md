# Two-bit temporal key symbols lose to the split three-bit stream

A tempting change to the [parallel temporal key-score carrier](../key-delta-parallel/README.md) is to put 32 two-bit symbols in eight bytes instead of twelve. It does not save space on the frozen Qwen3-0.6B keys. The fourth two-bit symbol must mark an escape, leaving only three direct differences. The best three are `-1, 0, +1` on both inspected layers, globally and in every KV group. At layer 14, the five-bit escape stream grows by 69,911 payloads across 1,024 tokens. The complete cache grows from 109,299 to 121,260 bytes, including block alignment and offsets. Layer 0 grows from 129,608 to 149,325 bytes.

| Four 256-token validation windows, eight groups | Layer 0 | Layer 14 |
| --- | ---: | ---: |
| Delta coordinates inside 32-key blocks | 253,952 | 253,952 |
| Three-bit stream escapes | 46,628 | 14,137 |
| Best two-bit stream escapes | 128,961 | 84,048 |
| Two-bit bytes, four-byte block offsets included | 149,325 | 121,260 |
| Existing three-bit bytes, same accounting | 129,608 | 109,299 |
| Static mixed three/four-bit cache, different score map | 114,688 | 114,688 |
| Plain nibble cache, same score map | 131,072 | 131,072 |

This is an exact finite-family rate result, not a rejection of learned two-bit key producers. For a fixed two-bit alphabet, one symbol denotes an escape and three denote signed differences. Every other difference is in `[-14,14]`, so a self-contained signed-difference escape needs five bits. Given transition counts `n_d`, the optimal fixed alphabet takes the three largest `n_d`. For these blocked histories those differences are `0,+1,-1` at both layers and for each group individually. The two-bit rate before anchors and alignment is `2N+5E₂`; the existing seven-inline three-bit rate is `3N+5E₃`. At layer 14, beating the three-bit stream requires at most 64,927 escapes instead of 84,048, a 22.75% reduction. At layer 0 the threshold is 97,418 instead of 128,961. Group-specific alphabets change neither count. These thresholds use the same 32-key anchors and offsets; per-block byte rounding cannot reverse the observed 11,961-byte layer-14 deficit.

Even granting four bits per escape as an *optimistic rate bound* rather than the self-contained signed-difference representation, the layer-14 escape threshold is 81,159, below the observed 84,048. A four-bit absolute next-code payload could exploit the previous key's state, but its direct delta dot would then need that previous coordinate, losing independent lane-local delta parsing. This comparison is a bit bound, not an implemented four-bit reader. A genuine two-bit win needs a producer whose delta alphabet has at least 19,121 fewer escapes over these 253,952 transitions, or a changed observation/consumer that earns the extra parser work. Reassigning symbol labels on the frozen keys cannot get there.

The executable two-bit codec keeps a 16-byte signed-nibble anchor per 32-key block, 31 fixed eight-byte symbol rows, a five-bit escaped-difference side stream and a four-byte block offset. The same two warp prefix scans as the three-bit split carrier locate escapes and compute scalar scores for both heads. For real arithmetic, `u·c_t = u·c_0 + Σ_{i=1}^t u·(c_i-c_{i-1})` for any query `u` and signed-nibble key history. The CPU reader round-trips all 8,192 cached key rows per layer and checks two deterministic query vectors on every block; maximum observed FP64 score association differences are 1.42e-14 / 1.07e-14. Those are not FP32 bit-identity claims. The two-head 512 query-coordinate products per key remain, and the extra escaped-difference reads make this larger image a worse native starting point than the three-bit stream.

`measure.py` rebuilds the paid binary K producer's frozen post-RoPE nibble codes, writes source/model/capture/image/parent-hashed receipts and hashes the concatenated encoded payload at `data/kelana-subbit/key-two-bit-delta/layer{00,14}.json`. Reproduce without the GPU:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-two-bit-delta/measure.py \
    --layer "$layer" --output "/path/to/workspace/data/kelana-subbit/key-two-bit-delta/layer$(printf '%02d' "$layer").json"
done
```

The next useful experiment changes the K producer and its temporal code together, and selects the image by composed causal loss on quantized-producer text. The concrete rate target is fewer than 64,928 escapes per 1,024-token layer-14 panel before building a native two-bit reader. This study changes no Bonsai executable or service and measures no new model loss or GPU latency.
