# Ternary lookup and shared-addition maps at 32-256 tokens

Negative result for the implemented LDS lookup family. Its bandwidth accounting does not bound all lookup or shared-addition programs.

At one and eight tokens the [whole-FFN table map](../../full-map/README.md) lost because it traded
arithmetic for table traffic. The open question was whether batching reverses that: at 32-256
tokens a table entry serves many tokens at once, so each lookup should buy far more work. It does
buy more work. The measured implementations still lose; LDS traffic and table construction explain much of the cost.

## The roof

A packed lookup map delivers **two tokens times the group size, for every four bytes it reads out
of LDS**. This assumes each fetched entry supplies two token sums to one consuming row, with no additional reuse of that fetch. Broadcast reuse, another storage level or another encoding changes the accounting.

Using an LDS bandwidth model of 128 bytes per clock per work-group processor, this family's ceiling is

```
64 * G   MAC per clock per work-group processor
```

for group size `G`. The reported rates below divide elapsed time by an **assumed 2.9 GHz**, not a measured cycle count. Group-3 probe work also counts the padded 129th product of a 128-input block. The small apparent roof exceedance is not proof of a hardware violation. With the table already resident and no weight traffic:

| group | entries | roof `64*G` | measured |
| --- | --- | --- | --- |
| 3 | 27 | 192 | 194.9 |
| 4 | 81 | 256 | 253.9 |
| 5 | 243 | 320 | 305.6 |

The native int8 WMMA path on the same ternary blocks, one HALO peel per row-block feeding four
16-token WMMA groups, sustains **303-310 MAC/clk/WGP at 64, 128 and 256 tokens**. So the best
group size that fits anywhere near LDS reaches the native rate only when the table costs nothing
to build and nothing to read weights for. Group 3, the size the deployed map uses, cannot reach it
at all.

Two tokens per dword is the chosen encoding. A signed five-term ternary/int8 dot ranges from -640 to 640 and needs 11 bits. Three independent such values cannot fit losslessly into 32 bits. The implemented chain uses 16-bit fields to retain headroom over a whole scale block. [check.cpp](check.cpp) shows the
accumulated field lands near 32768 for every group size from 2 to 10, because the number of groups
falls exactly as fast as the per-group range grows. The packed channel is never the binding
constraint, and widening the group never widens the channel.

## Why a bigger group does not escape it

`64*G` rises with `G`, but the implemented materialized-table schedule faces rapidly growing storage and construction costs. This is not an impossibility result for larger groups.

A group table holds `3^G` entries of `tokens/2` dwords. The consumer needs the whole 128-input
scale block's tables or a staged subset. Materializing all tables gives, for a 64-token tile, 148 KB at group 3, 331 KB at group 4 and
808 KB at group 5 against 64 KB of LDS, so the implemented block is staged in slot groups.
What is not fine is that the build is amortised only over the rows one workgroup holds:

- building group 5 for a 64-token tile writes 243 x 32 = 7776 dwords;
- consuming it for a 256-row workgroup reads 256 x 32 = 8192 dwords.

Those are the same number. The build is not a startup cost that the batch amortises away, it is a
recurring cost of the same order as the work it enables. Registers are what caps the row count:
64 tokens need 64 float accumulators plus 32 packed integer accumulators per lane before any
addressing, so rows per lane cannot rise to where `3^G` would disappear. **A larger token tile
does not amortise the build, it competes with it for the registers that rows need.** That is the
reason this schedule does not gain the hoped-for amortization.

Group 3 keeps the build small (27 entries against 256 rows) but its roof is 192, already below the
native rate. Group 5 reaches the native roof but pays a build of the same size as its consumption.
None of the measured group sizes provides both a high consume rate and cheap construction.

## Locality does change the exchange rate, by 2.3x, and it is still not enough

This is the one positive finding. The map's gather is divergent by construction: lane = output row,
and each row's selector picks its own entry. With planes laid out contiguously per entry, every
entry begins on the same LDS bank and the 32 lanes serialise. Rotating the plane index by the lane
makes the 32 lanes touch 32 distinct banks at every step, whatever their selectors are, and the
lane simply owns a rotated token order afterwards, which costs one permuted scale read per block
and nothing in the inner loop.

Group 5 at 32 tokens, same kernel, same data:

| LDS layout | MAC/clk/WGP |
| --- | --- |
| planes contiguous | 65.8 |
| entry stride padded by one dword | 144.3 |
| plane index XOR lane | 151.2 |

The rotation only takes `NP` distinct values, so it is conflict-free only once the token tile fills
all 32 lanes' worth of planes: 64 tokens. That is why the roof measurements above use a 64-token
tile, and why a 32-token tile sits at half the roof. Padding on top of the rotation loses again
because the odd stride breaks the four-dword vector reads.

## Consuming HALO's own bytes works, and does not rescue it

[halo5.hip](halo5.hip) implements the group-5 map that reads the deployed weights unchanged.
HALO already packs five trits into each of 24 `qs` bytes and four into each of 2 `qh` bytes, and
`pack5` is injective over all 243 patterns ([check.cpp](check.cpp) verifies it, along with the peel
round trip), so **the stored byte is the table index**. The consumer does no bit-field extraction,
no weight expansion and no repacking, and it loads 26 bytes per row per block through the deployed
`uint4 + uint2 + uint` vector load. Weight bytes are exactly HALO's 26, against 26.9 for the
deployed 43-group five-bit selector format and 28 for a group-4 seven-bit format.

That removes every weight-side cost the earlier map paid. The rates, gate/up geometry, real
schedule:

| tokens | table group 5 on HALO bytes | same kernel, build removed | native int8 WMMA |
| --- | --- | --- | --- |
| 64 | 41.1 | 124.3 | 303.3 |
| 128 | 41.4 | 131.3 | 306.5 |
| 256 | 42.0 | 128.9 | 306.0 |

MAC/clk/WGP, medians of 12 intervals, all samples in
[results/halo5-vs-wmma.json](results/halo5-vs-wmma.json). The build-removed row is arithmetic
nonsense kept only to split the cost; it is never a candidate.

The build takes two thirds of the fused time, as the dword counts predict. The consumer reaches
124-131 rather than the isolated 305 because at 238 VGPRs it spills: 64 float accumulators, 32
packed accumulators, the HALO block registers and the build's temporaries do not coexist. Group 4
would cut the build by three and the roof by a fifth; group 3 would cut the build by nine and the
roof by two fifths. Neither crosses 305.

Selector traffic confirms the layout point from the other side. A byte-per-slot selector array,
read one byte per lane per group, sustains only 14-27 GB/s and halves the map's rate on its own,
because each group's load is a separate dependent access with nothing to hide its latency. HALO's
three vector loads per block do not have that problem. Anyone building a lookup consumer should
read weights the way the engine already does.

## What was measured, and what was not

- [probe.hip](probe.hip) measures the consume roof per group size and token tile, the LDS layout
  comparison, the selector-load cost and the build cost, on the real gate/up geometry
  (K = 5120, 34816 fused rows). Results in [results/rate-probe.json](results/rate-probe.json).
- [halo5.hip](halo5.hip) measures the group-5 HALO-byte map end to end for the projection against
  an int8 WMMA baseline at the same token tiling, so both pay the same weight re-reads.
- [check.cpp](check.cpp) is a CPU proof-of-arithmetic: packed channel bounds for every group size,
  exhaustive decode over the reachable range, and `pack5`/`pack4` injectivity.

These are rate probes over the projection. Operands are shaped like the real ones but carry probe
data, so **no bit-exactness is claimed here** and no candidate is registered with the shared
[bench driver](../bench/README.md). Building a bit-exact batched FFN candidate around a projection
that is already 7x off the native rate, with a ceiling that ties it at best, would not change the
conclusion. If the ceiling argument is ever broken, the candidate is the next step and the
[api.hpp](../api.hpp) contract is the place for it.

The comparison is against a WMMA baseline written here, not against the bench directory's native
batched baselines, which were still in progress. That baseline sustains 303-310 MAC/clk/WGP flat
across 64-256 tokens on the deployed HALO tiles; a stronger one only widens the gap.

## Shared-addition DAGs remain open

These probes do not synthesize a shared-addition DAG from the real weights. A DAG can retain values in registers, exploit repeated subexpressions, broadcast values or change the row grouping. Such programs need not pay one LDS load for every two-token partial sum, so `64*G` is not their lower bound.

The full group-8 table has 6561 entries, which makes materialization expensive. That fact alone does not decide sparse tables, hierarchical sharing, register-resident subexpressions or reuse across workgroups. No actual-weight pattern census or end-to-end DAG candidate is reported here.

## Run

```sh
cd research/ffn/batched/lookup
make                                    # ../../../../localbuild/lookup/{probe,check}
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -o ../../../../localbuild/lookup/halo5 halo5.hip

../../../../localbuild/lookup/check
../hardware-run ../../../../localbuild/lookup/probe  --iters 15 --warmup 3 --json results/rate-probe.json
../hardware-run ../../../../localbuild/lookup/halo5  --iters 12 --warmup 3 --json results/halo5-vs-wmma.json
make resource                           # per-kernel VGPR and LDS occupancy from the compiler
```

Build products stay in `localbuild/`, which workspace release can reclaim. Every GPU run goes
through [hardware-run](../hardware-run); nothing here changes machine-wide GPU admission.
