# Interleaved measurement

The first grouped-scale investigation caught an apparent 28% layout gain that disappeared under rotating comparisons. A resident server and changing GPU clocks make sequential candidate runs unsafe for small claims.

The driver now measures randomized candidate blocks within repeated rounds. It warms each candidate after switching to it, enqueues several calls back to back, and retains every sample. Each block records its round, order, sample range and host timestamps. `--iters` is still the total timed calls per candidate; `--rounds` divides those calls into blocks. The first block uses `--warmup`, later blocks use two unmeasured calls.

The [carrier comparison](../carrier-comparison/README.md) caught a further problem:
20 warmup calls did not outlast the clock ramp. Measured windows at batch 32 still
spanned reported clocks of 0.7 to 2.2 GHz. The driver now runs an untimed workload
ramp before each batch size, default `--ramp-ms 2000`, rotating through candidates.
The result records `ramp_ms`, and the sensor trace includes the ramp. First-round
warmup and per-switch rewarming remain separate. Results without `ramp_ms` used
the call-count-only protocol; their raw samples remain unchanged.

GPU benchmarks require the marker set by [hardware-run](../hardware-run), which acquires the common file lock. This is operational coordination, not security isolation. The lock excludes participating research jobs, not the Bonsai server, browser clients or host CPU power competition.

A background recorder samples the PCI device's sysfs sensors approximately every 5 ms: reported shader clock, temperature, power and GPU busy percentage, plus host load. Missing readings are `-1`. These are asynchronous sensor snapshots, including intervals between kernels. They are not instruction-cycle measurements and must not be multiplied into a claimed exact cycle count. Sensor update rates can be slower than the polling interval.

Visible processes with DRM devices open are recorded before and after timing. An open device is not proof of active GPU work. Unreadable process FD directories are counted, so absence from this list does not prove exclusivity.

[Processor geometry](../GEOMETRY.md) corrects a separate reporting issue: this target's HIP count is WGPs. Earlier per-SIMD probes assumed 40 SIMD32 units instead of 80. This does not change whole-device elapsed times or matched speed ratios.

## Run and analyze

From this directory:

```sh
make build/batch-bench
../hardware-run ./build/batch-bench \
  --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
  --rows 256 --iters 160 --rounds 20 --warmup 20 --seed 19073 \
  --candidate gs-control-iu4-a4,gs-control-iu4-a4-rowscales,gs-absorb1024-iu4-a4-clip800 \
  --json results/interleaved-layout-scales-layer0.json
python3 paired_analysis.py results/interleaved-layout-scales-layer0.json \
  --baseline gs-control-iu4-a4 \
  --out results/interleaved-layout-scales-layer0-analysis.json
```

`paired_analysis.py` compares arithmetic-mean elapsed times within each round. It reports the geometric mean of the round speed ratios, total-mean speed ratio, wins by round, per-block telemetry and a round-bootstrap interval. No samples are discarded. The bootstrap treats rounds as independent observations; autocorrelation and external clients can violate that assumption. Its interval describes this experiment, not every deployment condition. Randomization reduces time-order confounding but does not prove an idle GPU or remove cache/scheduling effects of the comparison protocol.

## Standalone instruction and projection probes

Use [`probe_measure.hpp`](probe_measure.hpp) rather than copying a timing loop.
It adapts named launch callbacks to this driver's existing randomized scheduler,
duration ramp and telemetry recorder. Each callback must do the same declared
amount of work. The adapter records input provenance, source and executable
hashes, client snapshots, sensor traces and every timing block in the same
`kelana-batch-bench/2` format. `paired_analysis.py` reads it directly.

[`probe_measure_smoke.hip`](probe_measure_smoke.hip) is a complete example with
two identical kernels and output checking:

```sh
hipcc -O2 --offload-arch=gfx1151 -std=c++17 probe_measure_smoke.hip -o build/probe-measure-smoke
../hardware-run ./build/probe-measure-smoke /tmp/probe-measure-smoke.json
python3 paired_analysis.py /tmp/probe-measure-smoke.json --baseline copy-a --out /tmp/probe-measure-analysis.json
```

The adapter does not infer work counts or correctness. Check emitted instructions,
compare outputs separately, and derive per-SIMD rates using physical geometry and
actual resident waves. A workload label is not an occupancy measurement.

## Recorded results

All ratios below compare against `gs-control-iu4-a4`. They are throughput ratios, not percentages of time removed.

| Run | Rows | Candidate | Round speed ratio | Round bootstrap 95% interval |
|---|---:|---|---:|---|
| layer 0, first seed | 256 | grouped scales, clip 0.8 | 1.0627 | 1.0604 to 1.0649 |
| layer 0, second seed | 256 | grouped scales, clip 0.8 | 1.0779 | 1.0685 to 1.0877 |
| layer 10 | 128 | grouped scales, clip 0.8 | 1.0633 | 1.0537 to 1.0726 |
| layer 10 | 256 | grouped scales, clip 0.8 | 1.0833 | 1.0748 to 1.0914 |
| layer 0, second seed | 256 | row-major scales instead of tile-major | 0.9729 | 0.9661 to 0.9800 |

The grouped candidate wins all 20 rounds in each listed experiment. Its error is also higher: at layer 0, residual relative RMS rises from 0.9646% to 1.038%; at layer 10 with 256 rows, from 1.678% to 1.758%. These are isolated FFN errors, not full-model quality acceptance.

The scale-layout pair has identical output hashes. Tile-major scales are about 1.028x faster than row-major scales in the second layer-0 run. That is much smaller than the confounded 28% observation.

Absolute timing moved substantially across runs. The first layer-0 control median was 4.049 ms; the later layer-0 control was 3.331 ms. Shader-clock snapshots varied widely, and visible clients included the Bonsai server and a headless browser. This supports comparing candidates within randomized rounds, not combining absolute timings from different experiments. It does not identify which client or power-management event caused each change.

Raw runs and analyses:

- [Layer 0, first seed](results/interleaved-scales-layer0.json), [analysis](results/interleaved-scales-layer0-analysis.json).
- [Layer 0, second seed and layout pair](results/interleaved-layout-scales-layer0.json), [analysis](results/interleaved-layout-scales-layer0-analysis.json).
- [Layer 10, two batch sizes](results/interleaved-scales-layer10.json), [analysis](results/interleaved-scales-layer10-analysis.json).

The first run exercised the new schedule and telemetry before process snapshots were added. Its JSON has no client snapshot. The later runs include them. No service was stopped, no clock was forced, and no experiment here claims exclusive use of an otherwise idle GPU.
