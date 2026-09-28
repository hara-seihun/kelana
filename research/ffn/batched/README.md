# Batched FFN investigation

## Full-model adoption

The adopted kernels now live in [Bonsai Halo](/path/to/workspace/projects/bonsai-halo/tools/batch-compare/README.md). Its full-model driver compares independent sequence generation and document prefill, with all recurring work timed. Automatic A8 routing delivers 159.4 aggregate tok/s against 132.8 at 32 sequences; the eight-sequence case uses the original FFN under the layer-wise schedule and reaches 142.5 against 133.1. The [ramped comparison](/path/to/workspace/projects/bonsai-halo/tools/batch-compare/results/auto-a8-ramped.md) records throughput, clocks and numerical checks. Floating evaluation order changes under the wide A8 path; it is not bit-identical to the original model. The original FFN under the sliced schedule matched all recorded logits and continuation tokens.

## Research boundary

The [integrated accumulation-search results](RESULTS.md) compare the newest candidates in one executable on layers 0 and 10. Equal-output gains include 9–14% for IU8/A8 scheduling, 3–24% for scaled-FP16/A8 depending on batch size, and 29–98% for the selected A4 dense/pair-code maps. These are whole-FFN gains; the full-model numbers above have not changed.

The primary sizes are 32, 64, 128 and 256 real token inputs. Report throughput and latency per batch, all recurring producers and conversions included. Input-invariant weight preparation and allocation are outside timing. The current one/eight-token results are in [whole-FFN maps](../full-map/README.md).

[api.hpp](api.hpp) gives independent implementations one comparison boundary: row-major FP32 residuals in and out. It imposes no intermediate representation. Preparation receives weights and a maximum batch size, never activation values. The reference is the deployed Bonsai FFN applied to the same input rows. A four-bit storage/kernel baseline on the same ternary weights is a hardware comparison, not a quality comparison between separately trained models.

[Processor-unit correction](GEOMETRY.md): HIP reports 20 WGPs on gfx1151, corresponding to 40 CUs and 80 SIMD32 units. Earlier per-SIMD probe labels used the wrong factor; whole-device timing ratios are unchanged.

Use [hardware-run](hardware-run) for GPU experiments, including probes and data capture. It serializes participating research workers with a process-owned file lock, leaves the machine's disabled GPU admission unchanged, and returns 75 if another experiment holds the lock for 15 seconds. CPU work and compilation remain parallel. The existing server is outside this lock; retain all timing samples and distinguish dispatch waits from kernel execution.

## Work ownership

- [bench/](bench/README.md): real batched inputs, reference, strong native integer/FP16/four-bit baselines, build and acceptance driver.
- [arithmetic/](arithmetic/README.md): four-bit activations give a measured speed rung; IU4 issues at half the cost of FP16 and IU8 on this device.
- [grouped-scales/](grouped-scales/README.md): one scale over eight 128-blocks lets the integer
  accumulator run 1024 columns and deletes seven eighths of the per-block epilogue, worth 12.9% at
  256 rows; carrying the per-block ratio in an int4 multiplier gives back half of that, so the
  delivered trade is 7.2% faster for 7.6% more relative RMS error. Its original IU8 operand construction loses; the direct palette below removes that cost.
- [scale-carrier/](scale-carrier/README.md): direct packed-code-to-scaled-byte operands make grouped IU8 1.08–1.16x faster with identical outputs. A whole-K integer carrier is 1.17–1.19x the compact A8 control and about 1.04x compact-scaled at 256 rows on layers 0 and 10, at 0.113%/0.167% residual RMS error against the engine. All producer work is timed; no full-model quality or TPS measurement yet.
- [compact-scaled/](compact-scaled/README.md): two-bit ternary storage expanded to its scaled FP16 value in registers, with one FP32 accumulator across the whole K and no per-block epilogue. 1.12x the compact eight-bit control at 256 rows and 1.02x at 128 on layer 0, repeating at 1.11x and 1.00x on layer 10, at 0.011-0.019% relative RMS against that control and 2.5x the expanded FP16 baseline. Loses at 64 rows. The measured lever is the tile width: FP32-only accumulators fit eight token tiles without spilling, where the integer maps carry a second accumulator set, spill at eight and so run at four. Capping this kernel at four turns the win into a loss.
- [tile-ownership/](tile-ownership/README.md): shared-tile wave ownership crossed with load layout. The integrated IU8 candidate is 1.09–1.14x its existing A8 baseline with matching output hashes; scaled-FP16 gains are batch-dependent. Each wave still loads and constructs its own operand, so cache sharing is a hypothesis rather than a free broadcast.
- [dense-consumer/](dense-consumer/README.md): five-trit bytes feed two-trit selector codes directly into IU4 operands. The 1.625-code-bit layout is 1.90x arithmetic A4 at 32 rows; at 128/256, a two-bit wide-load pair-code control wins instead, 1.36x/1.26x. All retain arithmetic A4 output hashes on the tested rows. The density gain is batch-dependent, and these are not A8-quality replacements.
- [lookup/](lookup/README.md): materialized LDS tables lose in the measured family. The traffic accounting does not exclude other shared-addition programs.
- [register-observer/](register-observer/README.md): exact ternary projection sums from register-resident
  V_PERM_B32 lookups, four output rows per instruction, no weight expansion and no table traffic.
  PERM alone issues slightly faster than the IU4 matrix instruction per useful MAC; the tested
  schedules still reach only 0.27-0.37 of it, because each lookup needs an accumulate, plus a
  byte-lane drain and online table construction. Interleaved rounds against a chain-swept IU4
  baseline. No candidate registered.
- [spanning/](spanning/README.md): representations across projection, nonlinearity, transform and quantization. Its observed bit-exact family wins at 32 rows; its larger-batch layouts are still slower than the arithmetic family.
- [deferred-carrier/](deferred-carrier/README.md): paired FP16 accumulation across shared-scale groups. The ramped comparison finds 1.11–1.16x at 256 rows against its matched per-block control. Online integer-range certification reduces that to 1.03–1.05x and nearly ties grouped-scale IU4. Shared scales increase approximation error; no full-model acceptance yet. Tested integer-multiplier fits lost too much range for deferral.
- [triple-packing/](triple-packing/README.md): three ternary weight rows in one FP16 WMMA. The tested independent-channel radix family must separate after every instruction and loses to IU4. Its compiled decoder exceeds the measured compute savings; this is not a lower bound on other consumers.
- [half-carrier/](half-carrier/README.md): packed FP16 persistent accumulators reduce register use and permit wider token tiles. The RNE variant is about 1.16x faster than its IU4 control at 256 rows, but nearly tied with the improved paired-FP16 per-block control. Its [whole-model experiment](half-carrier/model-quality/README.md) measures real half accumulation. Captured replay still differs from the standalone half kernel by 0.1635%, so exact numerical transfer remains open.
- [direct-consumers/](direct-consumers/README.md): proved product, downstream sum and polynomial-derivative maps that consume packed words without reconstructing gate/up. Includes real-model nonlinear approximation probes; no whole-FFN speedup yet.
- [carrier-comparison/](carrier-comparison/README.md): combined half and deferred-carrier measurements with a timed clock ramp, matched numerical comparisons, and Lean range/separation proofs.
- [consumer-polynomial/](consumer-polynomial/README.md): native half-precision SiLU-product arithmetic, fitted coefficients and full-model quality measured against both original and matched four-bit references.
- [seven-product/](seven-product/README.md): one level of Strassen on the deployed projection.
  Keeping the K split inside a 128-scale block makes it bit-exact against the eight-product control,
  and the five sum operands compile into offset two-bit codes with no extra weight traffic. At
  matched tiling it wins 1.13–1.21x in every round; against the fastest eight-product shape it wins
  1.13x at 32 rows and 1.04x at 64 and 128 but loses 1.17x at 256, where seven accumulators per 32
  tokens forbid the wider token tile. Its unscaled sum operands need A3, at 2.3x the projection
  error of A4. Its shared-tile wave mapping is worth 1.11x to the eight-product map at 256 rows.
- [lossy/](lossy/README.md): main-thread error contracts, native full-model logit measurements and selected lossy constructions.

Workers can replace their experimental designs, use native hardware, and bring back negative results. Common API changes should be coordinated so implementations remain comparable. Build products belong in a `build/` directory so workspace release can reclaim them.

## Lossy exploration is not a blanket error allowance

"Five percent incorrect" is not one metric. Record relative RMS and bias of local errors, code and scale changes, final residual error, and eventually logit divergence, held-out loss and generation effects. No numeric approximation budget has been accepted yet. Sweep budgets and report the speed/behavior frontier.

An unbiased local error can acquire bias through a nonlinearity. Independent zero-mean errors can also grow under an expansive Jacobian; correlated errors can add coherently. A claim that error cancels needs measurements of bias, covariance and accumulation across repeated applications and layers, not just one-layer RMS.

Begin with lossy changes that remove hardware work, such as reducing activation planes. Include deterministic and seeded stochastic rounding where appropriate. Compare a single modified layer with the same modification across layers. Calibration inputs and acceptance inputs must be distinct. Keep exact and approximate candidates labelled separately.
