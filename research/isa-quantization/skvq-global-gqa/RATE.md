# Context length changes the paid rate comparison

The [complete-layer measurement](README.md) has **256-token windows**. At that horizon the fixed SKVQ arm has both larger cache state and larger complete-O error than KIVI. That is not a long-context method rejection: SKVQ pays a larger full-precision window but **801 bytes per aged layer token**, versus **1,280 bytes** for the KIVI arm. Their actual serialized state curves cross. The quality measurements do not extend beyond256.

This note counts the existing immutable formats and causal schedules. It neither fits a new configuration nor concatenates independent windows into a fictitious causal source. [`rate.py`](rate.py) pins the actual global descriptor, derives801 from its unequal packed cluster widths and fields, and checks the formula against8,192 steps of integer state counting. [`rate.json`](rate.json) retains exact counts. No activations, quantizer, source projection or observer is rerun.

## Exact causal state formulas

Let `t>=1` be the number of available tokens, counting the arriving token. There are8 KV groups with128 K and128 V coordinates each, or **4,096 BF16 bytes per full-layer token**. The32 global clusters per K/V side use545 code bytes plus256 field bytes per aged SKVQ token. Its descriptors cost `d=4228` bytes once per model layer.

SKVQ ages the oldest nonsink token **before the current query**. With5 sinks and64 recent tokens, the temporary pre-aging state contains up to70 full tokens and the query/final state up to69. Therefore

```
S_peak(t)  = d + 4096 min(t,70) + 801 max(t-70,0)
S_final(t) = d + 4096 min(t,69) + 801 max(t-69,0).
```

The first expression increases with `t`, so it is also the high-water over the complete prefix. For `t>=70`, these are **801t+234878** and **801t+231583** bytes.

KIVI flushes K slabs and the oldest V **after the query**. Each encoded token uses80 bytes on each side of each KV group; a full vector uses256. Just before the query,

```
rK(t) = 1 + ((t-1) mod32)
rV(t) = min(t,33)
K_before(t) = 8 [80(2t-rK-rV) + 256(rK+rV)].
```

After the query, use `rK=t mod32`, `rV=min(t,32)` in the same byte expression to obtain `K_final(t)`. Its cumulative high-water is

```
K_peak(t) = max(K_before(t), K_before(32 floor(t/32))),
K_before(0) = 0.
```

Why just these two positions? Within a K-slab period the before-query state increases. Each completed period's endpoint is larger than every earlier period endpoint. Thus only the current partial period and the most recent completed period can supply the maximum. The discontinuous32-token flush matters: a current resident size is not always the historical allocation peak.

At aligned `t=32m>=64`,

```
K_peak(t)  = 1280t + 91520
K_final(t) = 1280t + 45056.
```

At every fixed residue modulo32 after saturation, either SKVQ-minus-KIVI gap decreases by **15328 bytes** per additional32 tokens. This gives an all-length crossover calculation, rather than extrapolating a finite table of experiments.

## Actual crossovers and rates

| Tokens | SKVQ peak | KIVI peak | SKVQ final | KIVI final |
|---:|---:|---:|---:|---:|
|256|439,934|419,200|436,639|372,736|
|320|491,198|501,120|487,903|454,656|
|4096|3,515,774|5,334,400|3,512,479|5,287,936|

For **cumulative peak**, SKVQ is first strictly smaller at315, ceases to be smaller at333–338 because KIVI's historical peak plateaus, and is smaller at **every length from339 onward**. For **final resident state**, the first strict crossover is314, but subsequent K slab flushes reverse the ranking until it becomes permanently smaller at **386**. The arithmetic is exact for these two frozen formats and schedules; no quality at those new lengths is measured.

Asymptotic serialized bits per K/V coordinate, including fields and padded codes but excluding finite-window overhead, are

- SKVQ: `8*801/(2*1024) = 3.12890625`;
- KIVI: `8*1280/(2*1024) = 5`.

Thus the2-bit and4-bit names alone do not give either effective rate. At256, SKVQ's69 full tokens overwhelm much of its lower aged-token rate; at long context the latter dominates.

For `N` equal-length independent sequences sharing the model layer, the SKVQ descriptor is counted once: `N*(S_peak(t)-4228)+4228`, not `N*S_peak(t)`. KIVI has no comparable group descriptor in this format. Each sequence still owns its own causal cache. Runtime descriptors/counters, prepared copies, decoding scratch, model weights, rotary work, native code and latency remain separate axes; these formulas do not price them away.

## Consequence for the experiment

The256-token comparison answers a **nearby-size, short-context, full-layer output question**. Its fixed SKVQ arm is unfavorable there. It neither certifies poor quality at4096 tokens nor makes the two methods equal-rate at4096. A future long-context comparison needs an actual contiguous source at that horizon, original causal history, and a separately specified matched-rate control. Repeating these256-token receipts or projecting their relative errors would not provide that evidence.
