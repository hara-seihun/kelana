# Guaranteed local mass conservation without a key prefix scan

The previous [local-rounding result](../value-mass-local/README.md) gave the signed-nibble value consumer independent nearest-even 4,095-unit counts, a sum reduction and one correction at the largest-probability key. It reproduced a cheap candidate map on every inspected row, but its one-key repair can make a negative count. Here is an always-valid extension. It leaves the fast path's integer observation unchanged, and it makes the invalid path explicit rather than silently switching to a scan. An unconditional floor-and-owner map is a still simpler, always-valid alternative with a different quality trade.

For a finite nonnegative probability row with positive total `p_k`, mass `M=4095`, and owner `j=argmax p` with deterministic tie breaking, set `r_k=round_even(M p_k)`, `S=sum r_k`, `D=M-S`. If `r_j+D>=0`, emit `n=r+D e_j`. If not, necessarily `S>M>0`. Set `t_k=floor(M r_k/S)` using **integer multiplication and division**, `R=M-sum t_k`, and emit `n=t+R e_j`. This correction is nonnegative and exactly sums to `M` even if a floating softmax row does not sum to exactly one. Zero-probability keys stay zero on the positive-total domain; no original value coordinate or int4 expansion appears. The failed branch needs a second reduction and one integer division per active key. The branch rate, divergence, reductions, softmax preparation and direct low/high nibble dots must all be included in a native measurement.

Proof: in the failed branch `S>M`, so `0<=t_k<=r_k`; `sum t_k<=floor(M sum r_k/S)=M`, and `R>=0`. Moreover `R<N`, since the sum of the `N` fractional parts of `M r_k/S` is the integer `R`. In the fast branch the guard itself proves the only changed count is nonnegative. Both branches conserve mass and keep zeros zero, because a positive-mass row's maximum-probability owner is not a zero key. For a signed-nibble code `c_k` in `[-7,7]`, each coordinate `sum n_k c_k` is bounded by `7M=28,665`, so the radix-128 low digit and sparse high digit still reproduce this *integer* attention map exactly in int32. This is not an identity with real attention or with prefix-rounded FP32 attention.

There is also a guaranteed **one mass-sum reduction plus an owner argmax** construction on an exact probability simplex: `f_k=floor(M p_k)`, `F=M-sum f_k`, `n=f+F e_j`. Since `sum p=1`, `F=sum (M p_k-f_k)` is an integer in `[0,N-1]`. The count error against real mass-weighted value `v` is `sum_{k!=j} frac(Mp_k)(v_j-v_k)`; its coordinate absolute value is at most `14(N-1)` for signed-nibble `v`. This is a bound on count/code arithmetic, not on the learned output matrix's error. With finite softmax inputs that do not sum to exactly one, the formula requires either explicit normalization or the integer-proportional repair above. The CPU panel checks its observed floor arm for valid counts rather than asserting the exact-simplex theorem about floating data.

## Frozen consumer replay

[`measure.py`](measure.py) retains source, parent source/receipt, model, capture, paid factor and nibble-fit hashes in `/path/to/workspace/data/kelana-subbit/value-mass-repair/layer{00,14}.json`. Each row is a Qwen3-0.6B original-producer causal query on four previously inspected 256-token validation windows, sixteen heads per layer. The same paid rank-28 V/O factors and signed-nibble cache, direct 4,095-unit integer attention and original V/O teacher apply to all arms. The response was computed on CPU; no native consumer or whole-model loss was run.

| Layer | Safe nearest fast rows | Prefix post-O relative squared error | Safe nearest | Floor plus owner | Mean count L1 / M versus prefix, nearest / floor | High-digit pairs, nearest / floor |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 16,384 / 16,384 | .386705 | .386787 | .387427 | .005361 / .016624 | 75,634 / 75,359 |
| 14 | 16,384 / 16,384 | .365405 | .365548 | .364701 | .007774 / .022974 | 68,355 / 68,180 |

All four held layer-0 windows lose slightly under floor, and all four layer-14 windows improve slightly; neither fact makes floor the chosen quantizer on fresh quantized-producer text. Its mean count distance from prefix is roughly triple nearest's. On the prior explicit 256-key adversary, independent nearest overdraws by 113 units against an 18-unit largest key, so the fast branch fails; integer-proportional repair and the floor construction both return valid 4,095-unit rows. Their adversarial count L1 distance to prefix is recorded, not hidden by the zero failure rate in the model captures.

This settles a useful implementation prerequisite. The prefix scan is not needed for **validity** of a direct 12-bit mass/nibble consumer. It does not prove the replacement is faster: the conditional branch, extra reduction on invalid rows, owner update, key compaction and scattered high-digit reads have no native timing. A fused panel should time scan, guarded nearest, and unconditional floor with the same softmax and complete radix-128 dots at occupied contexts. Longer causal rows can change the fast-path failure rate. Before selecting a map for the engine, fit the narrow V/O codes against quantized-producer model loss; its frozen half-byte cache still loses to E4M3.

Run one bounded CPU panel per layer from a Kelana writer checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-repair/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-mass-repair/measure.py --layer 14
```
