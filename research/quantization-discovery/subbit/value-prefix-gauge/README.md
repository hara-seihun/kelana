# A prefix-code gauge buys a wider exact value-mass radix

The direct signed-nibble narrow-V consumer already converts each causal probability row into 4,095 conserved integer units. Its radix-128 program has one dense signed-byte dot and sparse high corrections. A running sum of the **value codes**, shared by both query heads in each GQA group, lets the dense dot use a biased signed byte. The high correction then starts at count 256 rather than 128, without changing the integer attention coordinate or decoding a value vector.

For every count `n` in `[0,4095]`, define `l=(n mod 256)-128` and `h=floor(n/256)`. Then `l` is a signed byte, `0<=h<=15`, and `n=l+256h+128`. If `c_tj` is a signed nibble code and `S_qj=sum_(t<=q)c_tj`, the **complete causal integer map** is

```
  sum_(t<=q) n_qt*c_tj
    = sum_(t<=q) l_qt*c_tj + 256 sum_(t<=q, h_qt>0) h_qt*c_tj + 128*S_qj.
```

The same `S_qj` serves the two heads that share GQA value codes. Update its 28 coordinates when writing each group's narrow V cache and keep it as per-sequence state. On a monotone decode step there are 224 signed int32 additions and 896 bytes of live prefix state per layer, plus a read and an `128*S` integer addition for each of the 448 observing head coordinates. To process several prefill positions in parallel, compute or store each needed prefix; treating that scan as free would invalidate the cost. The existing dense low dot still visits *every* causal key, including zero-mass keys, since their low digit is `-128`. The high list has at most 15 keys per row, from `sum n=4095`. Code centers move after attention as before. The final 4,095 divisor and paid O consumer do not change.

This is an integer identity on the full code/count domain, not an FP32 scheduling claim. The low sum has magnitude at most `896*T` at context `T`; the prefix correction has the same bound, and the high sum before multiplication is at most `7*15=105`. At the engine's 32,768-token cap, each separate term fits signed int32 (`29,360,128`, `29,360,128`, `26,880`), as do their intermediate and final sums under a schedule that combines the cancellation without overflow. The exact target sum is at most `7*4095=28,665`. Accumulate in int32 and convert the *final* integer once to reproduce the preceding integer mass coordinate before its scale. A program converting partial dots to floating point first can round differently.

The [radix-128 result](../value-mass-radix/README.md) is optimal only when low digits are unsigned nonnegative. Within `n=l+Bh+a` with one shared constant-bias code sum, one contiguous remainder interval of width `B`, signed-byte `l`, unsigned-byte `h`, and power-of-two `B`, no radix exceeds 256. The offset `a=128` realizes all 256 signed-byte values and puts `h>0` exactly at `n>=256`. This is not an optimality claim over position-dependent codes, extra dot passes, or different instructions.

## Frozen probability panel

`measure.py` uses the predecessor's original-producer Q/K and prefix-rounded 4,095-count function on eight train and four repeatedly inspected 256-token validation windows. It checks the digit identity on every count and the full code-prefix identity at four causal positions with independently generated signed-nibble histories. The table reports held validation, 2,105,344 causal key/head pairs per layer:

| Layer | Radix-128 high pairs | Biased radix-256 high pairs | 4-lane high-dot issued slots, 128 → 256 | 32-lane row issued slots, 128 → 256 |
| --- | ---: | ---: | ---: | ---: |
| 0 | 75,633, 3.59% | 38,246, 1.82% | 176,736 → 98,848 | 524,032 → 503,840 |
| 14 | 68,350, 3.25% | 40,770, 1.94% | 153,760 → 102,208 | 524,288 → 524,224 |

The four-lane fixed schedule [defined here](../value-high-scheduling/README.md) reduces its high correction slots 44.1%/33.5%. With 28 coordinates and four lanes per row, seven coordinate positions per lane, that saves 545,216/360,864 issued coordinate slots across the held windows. Maintaining prefixes serially for their 1,024 value tokens requires 229,376 int32 additions per layer, plus up to 458,752 output-coordinate corrections for the 1,024 queries, before state traffic, compaction and subgroup costs. These are scalar additions, not interchangeable with signed-byte dot slots. The compulsory dense low pass retains 2,105,344 key/head slots. Thus the modeled **total dot slots** fall only 3.41%/2.28%; the shared prefix update is not a free 2x attention speedup. At one 32-lane row per wave the layer-14 issued-slot improvement is effectively zero. Native work should only proceed with the small-lane complete fused count/scan, prefix maintenance, cache gather and O program against the radix-128 and E4M3 controls at occupied contexts. The frozen nibble V/O image still loses E4M3 quality on these original-producer captures; this exact mass rearrangement cannot repair that.

Receipts under `/path/to/workspace/data/kelana-subbit/value-prefix-gauge/layer{00,14}.json` bind model, capture, parent and source hashes and keep both train and held counts. No GPU, native timing, new model quality or Bonsai executable changed. The more valuable parallel question remains fitting the shared V/O basis and paid codes against quantized-producer complete-model loss, then pricing this integer consumer if its quality survives.

From a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-prefix-gauge/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-prefix-gauge/measure.py --layer 14
```
