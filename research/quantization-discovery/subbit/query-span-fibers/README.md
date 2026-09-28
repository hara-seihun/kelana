# Captured queries do not create a lossless narrow-key quotient

The paid signed-nibble Q/K observer has 32 cached key codes per GQA group, shared by two heads. Could its actual query codes observe a smaller exact key coordinate than the unrestricted basis queries in the [two-key quotient](../nibble-score-quotient/README.md)? On the frozen original-producer validation captures, no: each head reaches full rank over the 32 key coordinates in its first 32 causal queries. Every measured 32-query future block also has full rank. This settles the *lossless linear observation* question for this frozen score map; it does not say that a lossy, learned key coordinate cannot win.

## Finite causal observation and proof

Fix one group, one head and an externally supplied 256-query sequence. The frozen direct integer consumer rounds each step-scaled query to 32 signed-eight-bit coordinates `z_t`. The score for key code `c_j` is `a_t z_t·c_j`, where `a_t` is a nonzero per-query scale. Causal softmax at row `t` sees keys `0..t`. Assume real arithmetic after exact integer dots. Equal positive softmax distributions imply equal pairwise log-odds, so two histories `c` and `c'` have the same observation only if

`z_t·[(c_j-c_0)-(c'_j-c'_0)] = 0` for all `t >= j`.

For every `j <= 224`, the captured future queries contain a full-rank 32-row integer matrix. Its rows are among `t >= j`, so the bracket vanishes. Thus all first 225 key vectors in two observationally equal histories differ by *one common coordinatewise translation*. Conversely a common translation of every key in the history is invisible to every query. This implication uses the causal triangle, rather than treating an earlier query as if it could score a future key. The later 31 keys have fewer than 32 future query rows, so this proof makes no exact-fiber claim for them.

The rank certificates are over the prime field `F_65521`. A nonzero modular determinant proves nonzero integer and real determinant. Each 32-row window starts at positions `1,17,...,209,224`; for every `j <= 224`, one of those windows starts at or after `j`. On four validation windows at each of layers 0 and 14, all 1,920 group/head/window matrices have rank 32. All 128 first-32-query matrices also have rank 32; no later row is needed for the earliest keys. The checked receipts retain all 255 integer code rows and the independent first-32 witnesses. `check.py` replays the 1,920 modular ranks without a model dependency.

For the **full independent** signed-nibble alphabet `A={-7,...,7}`, the first `T=225` key vectors have at least `(15^225 - 14^225)^32` distinct observations. Normalize each coordinate's minimum to zero to count its translation orbits: there are `15^T - 14^T` sequences with at least one zero. Different orbits cannot share the captured observation by the rank argument. A fixed-length joint history coder therefore needs at least `ceil(32 log2(15^225 - 14^225)) = 28,130` bits **per group** even if it may encode all 256 keys together. Independent base-15 coding of the same 225 vectors needs 28,129.612288 bits before rounding, so the removable common-translation gauge is only about 0.00000837 bit/group at this length. This bound counts no claim about the last 31 keys; their own observation can only raise it. At two keys, by contrast, the gauge saves 94.586 bits/group. The comparison to the 4-bit physical cache also includes its separate `4-log2(15)` bit/symbol coding slack. Do not attribute that slack to softmax invariance.

The theorem's domain is all independent `15^32` code vectors per key, with captured queries held fixed as an external consumer. It does not establish that every such key history is reachable through the paid K producer, nor that later model queries remain fixed after counterfactual key changes. A rank-32 real query span does not prohibit a one-scalar *unbounded-precision* mixed-radix injection of finite key codes; the fixed-length information bound is the relevant restriction. These are real-score observations, not a promise of bit-identical FP32 softmax or final logits. No GPU, native code or serving state changed.

## Receipts and next experiment

`span.py` reconstructs the paid binary Q, selected RoPE coordinates and the exact dynamic signed-eight-bit query codes of the frozen nibble-key consumer on the four previously inspected 256-token original-producer validation windows per layer. Its per-window JSONs, model/capture/image/parent/source hashes and all integer query rows live in `/path/to/workspace/data/kelana-subbit/query-span-fibers/`. Regenerate and check them with:

```sh
cd /path/to/workspace/projects/kelana
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  for window in 0 1 2 3; do
    OPENBLAS_NUM_THREADS=4 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/query-span-fibers/span.py --layer "$layer" --window "$window" --output "$(printf /path/to/workspace/data/kelana-subbit/query-span-fibers/layer%02d-window%d.json "$layer" "$window")"
  done
done
python3 research/quantization-discovery/subbit/query-span-fibers/check.py /path/to/workspace/data/kelana-subbit/query-span-fibers/*.json
```

Change the **lossy** query/key family next. Train a rank-reduced, two-head score coordinate with the paid Q/K producers and its actual softmax/post-O consumer on quantized-upstream text; compare fresh gold loss and total stored rate against the 128-byte nibble and 112-byte mixed cache. A rank-reduced codec must price the query transform, producer and key-cache traffic. Another lossless gauge search over these sampled query rows cannot remove a coordinate from early keys.
