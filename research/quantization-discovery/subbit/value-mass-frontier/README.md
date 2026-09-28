# Shorter conserved mass for the signed-byte value reader

The [paid signed-byte narrow-V cache](../value-int8-consumer/README.md) uses 4,095 integer probability units and two byte dots. [Sparse overflow](../value-mass-overflow/README.md) already removes the second dot: one unsigned-byte/signed-byte dot over `min(n,255)` and a bounded list of corrections recover the complete integer response. The question here is whether 4,095 is an unnecessarily long count coordinate for that reader. It is, at least on these frozen original-producer captures. Using 2,047 units nearly retains its held two-head post-O response while substantially shortening the correction list.

For a causal probability row `p_t`, let `P_t = Σ_{k≤t} p_k`, `N_t = round(M P_t)` and set the final cumulative count to `M`. Counts `n_t=N_t-N_{t-1}` are nonnegative and sum to `M`. For the signed-byte value row `c_t ∈ [-127,127]^28`, the exact integer map is

```
Σ_t n_t c_t = dot_u8_i8(min(n_t,255), c_t)
                + Σ_{t:n_t>255} (n_t-255)c_t.
```

At most `floor(M/256)` keys can overflow, regardless of context. Thus `M=2047` needs at most seven corrections per head/query instead of fifteen at `M=4095`; `M=1023` needs at most three. The signed dot is bounded by `127M`, so int32 suffices. These are full nonnegative conserved-count-domain claims, not statistical claims about the captured attention rows. Scaling by the existing FP16 coordinate scales divided by `M`, then applying the paid O factors, gives the intended real-valued reader. It is not a bit-identity claim for the original floating attention or an FP32 reassociation claim.

There is also a deterministic error certificate relative to the supplied floating probabilities. Put `d_t=N_t/M-P_t` and `d_{-1}=d_{L-1}=0`. Summation by parts gives

```
Σ_t (n_t/M-p_t)c_t = Σ_{t=0}^{L-2} d_t(c_t-c_{t+1}).
```

Nearest cumulative rounding yields `|d_t|≤1/(2M)`, so the norm of the post-O response error for head `h` is at most `Σ_t ||O_h diag(s_g)(c_t-c_{t+1})||/(2M)`. Sum these bounds over heads for a layer. This bound applies to the exact real map given the probabilities and cached labels; it does not bound damage already in the frozen paid V/O image. The variation term makes explicit why simply saying that 255 units are enough for a smooth probability row is unsafe when neighboring code rows jump. Computing a tight output-space certificate itself costs work, so it is not a free runtime selector.

## Frozen Qwen3-0.6B panel

The [CPU receipts](/path/to/workspace/data/kelana-subbit/value-mass-frontier/README.md) use the same four previously inspected, separate 256-token original-producer validation windows per layer, pinned model/captures, paid rank-28 V/O factor image, FP16-rounded train-selected per-coordinate signed-byte scales and 224-byte logical V row as the parent. All sixteen heads and every causal query contribute. Cumulative rounding is rerun for each mass. Outputs are scored against the original Qwen V/O response. The 255 and 4,095 endpoint scores reproduce the parent receipt. For intermediate masses the script checks exact integer low-dot-plus-excess replay on every group/head/query.

| Count mass | Guaranteed correction keys/head/query | Layer 0 post-O teacher relative squared error | Layer 0 correction keys across panel | Layer 14 error | Layer 14 correction keys |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 255 | 0 | .37897280 | 0 | .33121461 | 0 |
| 511 | 1 | .37891225 | 7,378 | .32778622 | 8,762 |
| 1,023 | 3 | .37889449 | 11,277 | .32673219 | 15,346 |
| 2,047 | 7 | .37889079 | 19,491 | .32643168 | 24,666 |
| 4,095 | 15 | .37889031 | 38,246 | .32640127 | 40,770 |

Against the 4,095 response itself, 2,047 has relative squared difference .000003512 at layer 0 and .000120212 at layer 14. The latter is a real quality cost, not a rounding-equivalent map. Per-window teacher scores and correction counts are in each receipt. Every arm has the same 58,949,632 causal byte products across the panel, or 117,440,512 if a native reader pads each query to 256 keys. At 2,047 units the correction products are 545,748/690,648 instead of 1,070,888/1,141,560 at layers 0/14, a 49.0%/39.5% reduction. The paid image, static scales, cache row bytes and output-factor work do not move.

There is no native time, quantized-producer model loss or full-model result. Counting unlike byte products and irregular scalar corrections as equal cycles would be misleading. Count construction still needs softmax and a cumulative scan, and overflow discovery, compaction, gather, scale/O, occupancy and append remain in the native bill. The informative branch is a complete direct consumer at `M=2047` versus `M=4095` on an occupied context, including a head/query quality budget on fresh quantized-producer text. If the sparse list dominates, the seven-slot bound matters; if byte dots or O dominate, this change has little speed headroom. `M=1023` is a distinct quality/correction point rather than a generic replacement for 4,095 at late layers.

Run from a Kelana checkout with the parent's stored paid images and captures:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=research/quantization-discovery/subbit/value-mass-frontier/measure.py
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" "$D" --layer 14
```
