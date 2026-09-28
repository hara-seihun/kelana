# Integer position shifts as a RoPE quantizer gauge

A phase for every selected Q/K plane can improve rounded scores, but composing those phases at inference costs arithmetic. One shared integer offset `d` for both observing query heads and their key replaces `R(p)` with `R(p+d)`. The existing position-angle calculation can take `p+d` instead of `p`. This is a restricted, cheap subfamily of the [RoPE commuting phases](../rope-commutant/README.md), not an extra rotation after RoPE. We tested whether the existing paid signed-nibble Q/K image benefits from that subfamily. Layer 0 gains a little causal quality; layer 14 loses on held text despite a train gain.

## Identity and cost

For real vectors and orthogonal RoPE matrices, `R(p+d)=R(d)R(p)` and

`(R(p+d)q)^T (R(t+d)k) = (R(p)q)^T (R(t)k)`.

The identity holds for both query heads sharing one GQA key, at every query and key position. Their unrounded score and causal softmax are unchanged. Rounding the shifted post-RoPE keys into signed nibbles and the dynamically rescaled queries into signed bytes moves their code cells and changes the approximate map. A fixed post-RoPE key center `c` must become `R(d)c`, so its score remains a constant across keys and cancels from causal softmax. We rotate that center in the replay. This is a real-arithmetic theorem; independently rounded BF16 projections, transcendental approximations and different FP32 contractions do not promise bitwise identity.

The position offset is one integer per GQA group/layer, 32 bytes/layer at eight 32-bit offsets. Across 28 layers this is 896 bytes, about 0.0000120 bits per 596,049,920 unique weights. The existing 128-byte packed key cache/token/layer, 512-byte key steps/layer, selected centers, 1,024 nibble products/key/layer across two heads, dynamic query rounding, full raw K norm and paid Q/K factor remain. A native consumer adds one position-offset integer operation for each group at append/query preparation, or folds it into the existing position address. If RoPE angles come from a table, the table must cover positions through `context-1+max(d)`; an on-the-fly angle computation reuses its existing sin/cos evaluations. The Qwen quality replay recomputes FP64 angles and does not measure native time, table behavior or model loss. The source/model hashes are in the receipts.

## Frozen Qwen result

`measure.py` loads the Qwen3-0.6B paid binary Q/K projection and BF16 group K affine, the existing 16-plane/group mask, the train-selected raw/centered per-coordinate key steps and original-producer 256-token captures. It rotates both paid Q heads, the paid K and the frozen center by `R(d)` on selected planes. The teacher uses original Q/K. For each group it chooses the smallest sampled train causal KL over integer offsets 0 through 31 at sixteen strided query positions per each of eight train windows; then it evaluates every causal query in four separate, previously inspected validation windows. The actual candidate uses the maximum-absolute 119-step dynamic query scale, integer-rounded signed-byte queries and signed-nibble keys, with scores formed from integer products. The two-dot split produces the same integer score.

| Layer | Shift 0 held KL | Train-selected shifts held KL | Sampled train KL, zero to selected | Per-window held direction |
| --- | ---: | ---: | ---: | --- |
| 0 | .275431 | .274167 | .241600 to .236052 | three improve, one worsens |
| 14 | .332396 | .333612 | .310882 to .309503 | two improve, two worsen |

Layer-0 group 2 alone falls .377913 to .368992, while layer-14 groups 1 and 4 reverse their train gains by .006247 and .004854 on held text. The zero-offset replay agrees with the earlier direct-query control to the shown digits. The eight selected offsets in each layer and every train/held group/window loss are in `data/kelana-subbit/rope-integer-shift/layer{00,14}.json`; the adjacent 73 MB NPZ files preserve paid/original Q/K activations for replay without another projection pass. These are fixed-image, original-producer attention losses on already inspected text. The layer-0 conditional gain is too small and inconsistent to select a native reader, and layer 14 rejects train-only offset choice on this image.

The next experiment should fit offsets *with* paid Q/K labels and steps on quantized-upstream, broader text, rather than search more shifts on these frozen coordinates. The offset is a very cheap degree of freedom, but choosing among different rounded maps overfits even with eight train windows. A future winner must retain matched held causal/post-O or gold quality before pricing a native complete append/query/score path. No GPU, Bonsai binary, service or default changed here.

From a Kelana checkout, use `/path/to/workspace/data/fish-s2-pro/venv/bin/python` with `OPENBLAS_NUM_THREADS=1`:

```sh
P=research/quantization-discovery/subbit/rope-integer-shift/measure.py
D=/path/to/workspace/data/kelana-subbit/rope-integer-shift
/path/to/workspace/data/fish-s2-pro/venv/bin/python "$P" capture --layer 0 --output "$D/layer00-input.npz"
/path/to/workspace/data/fish-s2-pro/venv/bin/python "$P" fit --layer 0 --input "$D/layer00-input.npz" --output "$D/layer00.json"
```

Repeat with layer 14. The command uses the stated Python interpreter rather than the system Python; capture and fit each finish within a bounded foreground call on this host.
