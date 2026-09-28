# An integer probability consumer for narrow signed-nibble values

The frozen rank-28 V/O image can consume its signed-nibble value cache without expanding every cached value to floating point. Quantize each causal probability row to nonnegative integer masses summing to 4095, dot those masses against packed value codes, scale the 224 resulting head coordinates once per query, then run the paid O consumer. This changes the floating execution map, but on the four already-inspected original-producer validation windows its extra post-O error is small. It does **not** rescue the frozen half-byte cache's quality deficit against E4M3. The next useful experiment changes the narrow V basis and O codes while training against this integer consumer.

Let `p_0..p_(T-1)` be one head's real causal probabilities, `sum p=1`, and let `c_tj` be signed nibble values in `[-7,7]`. For integer mass `M`, form prefix masses `N_t=round(M sum_(i<=t) p_i)` and counts `n_t=N_t-N_(t-1)` with `N_(-1)=0` and `N_(T-1)=M`. Nonnegative counts sum to M; masked future keys get zero. The observed narrow value coordinate is

```
  a_j = (s_j/M) * sum_t n_t*c_tj + m_j.
```

`m_j` is the trained value center. Its contribution moves after the causal reduction because the integer masses sum to one. The O slice then consumes `a` directly; no 128-dimensional value vector or per-key FP32 decoded 28-vector is required. The replay uses original FP32 softmax probabilities and the frozen paid BF16-rounded narrow V producer; it quantizes only their causal probability rows and the value cache. This is not a claim about bit-identical FP32 attention.

There is a useful deterministic error certificate for *each code sequence*, not just a bound based on the largest value. Define `D_t=sum_(i<=t)(n_i/M-p_i)`. For normalized real `p`, prefix rounding gives `|D_t|<=1/(2M)` for `t<T-1` and `D_(T-1)=0`. Summation by parts gives

```
 |sum_t (n_t/M-p_t)c_tj|
   <= (1/(2M)) sum_(t=0)^(T-2) |c_tj-c_(t+1)j|.
```

Multiply by `|s_j|`; the post-O vector bound follows by applying each head's O-slice operator norm to its coordinate-error vector and summing heads. The bound assumes normalized real probabilities; the CPU replay uses stored FP32 probabilities, whose row sums can differ by rounding. It is an error bound for the probability conversion alone, not for the lossy factor image, nibble cache or final floating implementation. A sharply varying code history weakens it, which suggests training temporal code smoothness only if it improves actual causal output.

At `M=4095`, each count is in `[0,4095]`. The two signed-byte digits `lo=((n+128) mod 256)-128`, `hi=(n-lo)/256` lie in `[-128,127]` and `[0,16]`. Hence `sum n*c = sum lo*c + 256 sum hi*c`, checked for every measured query, key and coordinate. Each full integer result is at most `7M=28,665` in absolute value; even intermediate partial sums in these two digit passes fit exactly in FP32 and int32. A native program can expand the packed *nibble operand into registers* for two signed-byte dot passes, without building an int4-expanded cache. The model has not timed this lowering, and the code's CPU FP32 matrix multiplication is not a substitute for a native dot-instruction benchmark.

The 8-bit mass is an error control. The 12-bit construction needs two byte dots over 448 head-coordinate/key pairs per layer, or 896 scalar integer products per occupied key. For a 256-key context this is 229,376 byte products/query token/layer, before instruction packing. It also needs 16 causal prefix scans/roundings of up to 256 probabilities per query token/layer, 448 coordinate scale operations per query and the existing 458,752 paid O factor products per query. The 112 logical cache bytes per token/layer pad to 128; the E4M3 cache needs 224 logical/256 padded bytes, while the BF16 narrow cache needs 448 logical/512 padded. The frozen K producer/cache and 688,128 paid V/O factor terms/token do not change. Center metadata and any folded 4,096-byte O bias remain charged as in [the static nibble study](../value-centered-int4/README.md). Packing, unpacking, probability quantization, cache traffic, O work, registers and launches must all enter any native comparison. This result establishes an executable map, not that it is faster than E4M3 or than expanding the nibble cache.

Four previously inspected 256-token validation windows, original Q/K and hidden producer, fixed rank-28 paid V/O factors and train-selected nibble steps/centers:

| Layer and nibble arm | Float-probability post-O relative squared error | 8-bit integer mass | 12-bit integer mass | 12-bit error relative to float-nibble post-O |
| --- | ---: | ---: | ---: | ---: |
| 0, raw coordinate | .386704 | .386789 | .386705 | 7.06e-7 |
| 0, adaptive center | .385731 | .385814 | .385733 | 7.06e-7 |
| 14, raw coordinate | .365386 | .370241 | .365405 | 2.35e-5 |
| 14, adaptive center | .371962 | .376807 | .371983 | 2.35e-5 |

The prior E4M3 cache scores .379186/.326527 at layers 0/14. Its advantage over these nibble arms dwarfs the 12-bit probability error. Eight bits is adequate at layer 0 but visibly harms layer 14; twelve bits makes the probability representation cheap in *quality*, not yet in instructions. These held windows have been inspected repeatedly and do not measure quantized-upstream language loss. No Bonsai binary, GPU or resident service changed.

`measure.py` regenerates `/path/to/workspace/data/kelana-subbit/value-integer-consumer/layer{00,14}.json`. The receipts retain per-window errors and source, model, capture, factor and frozen-nibble-receipt hashes. From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-integer-consumer/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-integer-consumer/measure.py --layer 14
```
