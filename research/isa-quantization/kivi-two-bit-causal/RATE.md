# Context and sharing limits of the smaller KIVI2 comparison

The [measured comparison](README.md) uses one full-layer sequence at256 tokens. KIVI2 is **304,768B peak /249,856B after flush**, versus the two frozen TurboQuant images' **385,040B** cache plus literal prepared program. KIVI2 has much lower complete-O error on that panel. This is a genuine two-axis improvement for that single-sequence state contract, not a claim that KIVI2 is smaller for every context or batch.

## Exact chronological count

Let t be the number of arrived tokens. Aged K and V each cost48B/token/KV head (including fields); a recent BF16 vector costs256B. For `t>0`, immediately before the query's after-query flush:

```
rK(t) = 1 + (t-1) mod32,
rV(t) = min(t,33),
K_before(t) = 8[48(2t-rK-rV)+256(rK+rV)].
```

Set `K_before(0)=0`. The largest live count through t is

```
K_peak(t)=max(K_before(t), K_before(32 floor(t/32))).
```

After the query's flush, replace `rK` by `t mod32` and `rV` by `min(t,32)` in the count. For a multiple of32 at least64:

```
K_peak(t) = 768t +108160,
K_final(t) = 768t +53248.
```

The frozen TurboQuant reader has no recent buffer and costs

```
T(t)=196624+736t
```

when all three literal FP32 matrices and the four-centroid table are charged once. It has a slightly smaller asymptotic per-token rate,736 rather than768B. The generic matrices are not per-sequence state.

[`rate.py`](rate.py) verifies the formulas against a separate token-by-token flush count through8192 positions and derives the exact affine crossing in each of32 residues. [`rate.json`](rate.json) contains all residue certificates. These are integer arithmetic checks, not new model evaluations.

| One full-layer sequence | KIVI2 cumulative peak B | KIVI2 after-flush B | TurboQuant program+cache B |
|---:|---:|---:|---:|
|256|304,768|249,856|385,040|
|1,024|894,592|839,680|950,288|
|2,048|1,681,024|1,626,112|1,703,952|
|4,096|3,253,888|3,198,976|3,211,280|
|8,192|6,399,616|6,344,704|6,225,936|

Turbo first becomes smaller than cumulative KIVI2 peak at **t=2784**, with subsequent reversals across flush phases; it remains smaller at every integer **t>=3255**. For after-flush state, the first smaller point is **2879**, and the permanent crossing is **4481**. No output quality past256 tokens was measured.

## Exchanging key and value precision is not an exactly equal byte swap

Keep the K group length and recent-V threshold equal to G, with the same after-query flush order. After t arrivals and the query's flush, quantized-position counts are

```
nK_post = G floor(t/G),       nV_post = max(0,t-G).
```

Before that flush they are the same functions of `max(0,t-1)`. For t>=G,

```
nK_post - nV_post = G - (t mod G).
```

Before warm-up both counts are zero. Consequently K has at least as many quantized positions at every phase; their gap is at most G. This is caused by whole-chunk K aging versus one-at-a-time V aging, not by the source values.

Let low/high be the code bytes per quantized vector; all identical metadata/recent bytes are common. Arm A spends low on K, high on V; arm B reverses them. Their exact difference per KV head is

```
B - A = (high-low) (nK-nV) >= 0.
```

[`Kelana/KVPrecisionExchange.lean`](../../../Kelana/KVPrecisionExchange.lean) proves the general natural-number phase counts, gap/order/bound and the integral byte-exchange law, plus the rational factorization. Thus value-heavy A is never larger in this payload ledger when G equals the recent threshold. This says nothing about attention quality, query work, different metadata layouts or unequal thresholds.

For the fixed128D KIVI2/KIVI4 exchange, low/high code sizes are32/64B; the unchanged metadata contributes16B per aged vector on both sides. At t256 before flush, nK/nV=224/223, so the eight-head **K2/V4 versus K4/V2 difference is only256B**:361,856 versus362,112B. After flush nK/nV=256/224 and the difference is8,192B:307,200 versus315,392B. Both arms' causal high-water through256 occurs before the last K flush. These are near-rate, not exactly equal-state programs; the larger final-state gap must not be replaced with their peak gap. No dead padding is introduced to manufacture equality, and this rate law is not a claim that value-heavy precision must improve quality.

## Share the program once, not N times

For N independent256-token sequences sharing these same generic matrices and source model:

```
KIVI2 peak =304768 N,
Turbo peak =196624+188416 N.
```

At N=2, Turbo's represented peak is **573,456B** versus KIVI2 **609,536B**. Thus the one-sequence storage dominance cannot be copied unchanged into a multi-sequence conclusion. If a generic sketch program is already resident for other layers, its incremental charge also differs; document that pool explicitly rather than deleting it from a standalone comparison.

Source weights, code, counters common to the readers and transient decoded/scratch arrays remain separate. The literal CPU readers both use large expansion scratch; this arithmetic does not establish native total residency or latency. It changes none of the fixed measured quality numbers. The original sketch still loses to zero output on that observer, whereas the gauged sketch beats zero but loses to KIVI2 on single-sequence quality and counted state at256.
