# Fit the nibble value step against both output heads

The frozen rank-28 shared V/O image uses one signed-nibble value cache per GQA group, observed by two heads and their paid output factors. Its original per-coordinate nibble step was chosen by value-coordinate MSE. I changed the *step* selection objective to squared error after the complete causal attention and O response, including all eight groups in the residual. This recovers much of the frozen half-byte cache's layer-14 deficit without changing its stored bytes or online program. It does not catch the one-byte E4M3 cache.

For group `g`, coordinate `i`, candidate step `s`, let `a_h(q,s) = sum_{t<=q} p_{q,h,t} s clip(round(z_{t,i}/s),-7,7)`. Both heads share the cache code. Relative to the current complete response residual `R`, changing from the original step gives `D(q) = sum_h (a_h(q,s)-a_h(q,s0)) L_{g,h,:,i}` and the **exact real-valued squared-error change** `2<R,D>+||D||²`. This charges cross-head and cross-group interactions, not isolated coordinate reconstruction. In group/coordinate order, one deterministic train pass chooses the best of eight FP16-rounded multiples of the original FP16 step, retaining the incumbent if none improves the complete response. No local or global optimum beyond this finite one-pass choice is claimed.

The eight original-producer WikiText train windows fit steps; four previously inspected validation windows score the frozen choices against original dense V/O. Q/K probabilities and paid rank-28 factors are the same for all arms. Error is squared complete post-O deviation divided by teacher squared norm.

| Layer | Raw nibble train | Fitted train | Raw nibble held | Fitted held | E4M3 held | Changed steps / 224 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | .232400 | .231194 | .386704 | .386631 | .379186 | 132 |
| 14 | .214402 | .195754 | .365386 | .348247 | .326527 | 166 |

All four layer-14 held windows improve, by .022144, .019213, .015259 and .012645 relative squared error. At layer 0, only one window improves and the aggregate gain is .000072. Layer 14 also beats the preceding frozen raw/centered post-O toggle's .356487, but remains .021720 behind E4M3. Step choice matters to the downstream map; it cannot rescue this frozen basis at layer 0, and even the larger layer-14 improvement does not justify a native half-byte path over E4M3 yet.

The chosen image keeps the paid .53060 V/O weight BPW, 112 logical or 128 padded V-cache bytes/token/layer, and 448 FP16 step bytes/layer. The producer still divides, rounds and clamps 224 coordinates per token; the floating replay decodes steps before attention. A direct integer mass consumer still pays count preparation and 448 nibble-coordinate products per key across both heads, plus the narrow O projection. The study does not measure that consumer's native latency, integer-probability rounding, quantized-producer model loss or new basis training. E4M3 pays 256 padded V-cache bytes and 16 static scale bytes/layer instead.

The next experiment should change the narrow V basis and paid O codes with the nibble term in a quantized-producer complete-model objective. A second pass over these original-producer step candidates is less useful than finding an image whose fresh model loss can justify the cheaper cache.

The CPU [source](measure.py) and source/model/capture/paid-factor/frozen-cache-hashed receipts live in `data/kelana-subbit/value-nibble-response-step/layer{00,14}-8x4.json`. Each includes selected FP16 steps, every train choice and all held-window errors. Reproduce either bounded layer command from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-response-step/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-nibble-response-step/measure.py --layer 14
```

CPU only; Bonsai executable and resident service did not change.
