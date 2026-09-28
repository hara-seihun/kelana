# Direct byte-dot reader for a narrow value cache

The paid rank-28 V/O image already has a one-byte cache candidate. Its E4M3 group-scale reader needs floating conversion of cached values. A different one-byte coordinate, signed int8 with 28 train-fitted static scales per GQA group, lets the attention consumer dot the byte codes with conserved integer probability masses and apply each scale **after** the reduction. This keeps the 128-dimensional value out of the map and never expands cached bytes to int4 or floating values per key.

For group `g`, coordinate `j` and head `h`, store `q[t,j] ∈ [-127,127]` and a fixed FP16 `s[g,j]`. With nonnegative counts `n[h,t]` summing to `M`, the real-valued response is

```
A[h,j] = (s[g,j] / M) * sum_t n[h,t] * q[t,j]
y      = sum_h O_paid[h] A[h].
```

The scale commutes with the attention sum for both GQA heads because it is static across keys. This is an identity for the count-rounded cache map over real arithmetic, **not** bit-identical floating execution or an identity for the original BF16 attention. The integer sum has absolute value at most `127M` by conservation. At `M=4095` it is at most 520,065, safely within signed 32-bit. Split each count into signed low byte `l=((n+128) mod 256)-128` and high `u=(n-l)/256 ∈ [0,16]`; two byte-dot passes give `sum lq + 256 sum uq`. The CPU receipt checks that decomposition for every captured row. At `M=255`, one unsigned-count/signed-value dot pass suffices, but that count map changes quality.

I froze the eight groups' 224 train-coordinate-MSE scales from [the existing cache comparison](../value-fp8-cache/README.md), rounded those fitted FP32 choices to the charged FP16 storage, and froze its paid factor images. Four previously inspected 256-token validation windows per layer supply original-producer Q/K/hidden states. The same original V/O output is the teacher. The table reports complete two-head post-O relative squared error. The BF16 row reproduces the parent receipt. Both one-byte arms differ slightly from the parent because it used unrounded FP32 scale candidates. This panel rounds both formats' train-selected scales to the FP16 storage it charges.

| Layer | Paid BF16 cache | E4M3, group scale | int8, coordinate scale and float probabilities | int8, 255 counts | int8, 4,095 counts |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .37888697 | .37921783 | .37888879 | .37897280 | **.37889031** |
| 14 | .32619491 | .32654831 | .32637304 | .33121461 | **.32640126** |

Against the *same FP16-scale float-probability int8 cache*, the 4,095-count map adds relative squared response error 7.01e-7 / 2.48e-5 at layers 0/14. The one-dot 255-count arm adds .00011228 / .00600788; it is not an acceptable generic substitution at layer 14 on these inputs. The byte cache itself is better than the static E4M3 cache on this held panel, but that small quality margin buys neither model loss nor native speed by itself.

Both one-byte arms store 224 logical V bytes per token/layer, or 256 with eight 32-byte group slots. The int8 arm pays 448 FP16 static scale bytes/layer versus 16 for E4M3, an extra 432 bytes or .001099 BPW across one layer's 3,145,728 V/O weights. The paid 208,640-byte factor image and 688,128 signed factor terms/token are unchanged. At each query the 4,095-count reader must construct 16 conserved probability rows, issue two signed-byte passes over 448 logical head-coordinate products per cached key, apply 448 post-attention scale multiplications, then execute the paid O factor and head combination. Count preparation, intermediate storage, append quantization, physical cache lines, occupancy and the paid O work belong in native timing. The 255-count reader has one pass and worse late-layer quality. E4M3 needs per-key float conversion or a different consumer; its apparent one-pass floating products and the byte-dot instruction costs cannot be compared as scalar counts.

This is a concrete native experiment: on identical captured Qwen contexts, compare fused 4,095-count int8 append/attention/O against paid BF16-narrow and E4M3-narrow consumers with their conversion and scale work included. A headwise 255/4,095 selector must use a fresh quality budget rather than promote layer 0's one-dot mean to the whole model. Before selecting a model map, propagate the fixed images through quantized upstream layers and measure fresh text loss. The result establishes a cheap *integer algebra* and a held original-producer quality point; it establishes no GPU latency or full-model improvement.

`measure.py` reopens and checks the parent receipt, model, capture and factor hashes. The [data directory](/path/to/workspace/data/kelana-subbit/value-int8-consumer/README.md) retains source and input hashes, frozen scales' parent hash, eight cache-code hashes, per-window errors and the checked integer split. Reproduce from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-int8-consumer/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
