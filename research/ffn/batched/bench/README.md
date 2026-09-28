# Batched FFN dataset, reference and baselines

This directory owns the shared comparison for the batched investigation: the real batched inputs,
the exact reference, the native integer and float baselines, and the driver every worker's candidate
is measured by. Candidates live in each worker's own directory and are discovered from here.

[Measurement protocol and interleaved results](MEASUREMENT.md) explains the randomized rounds, telemetry, shared-GPU limits and same-round analysis. New runs use format `kelana-batch-bench/2`; earlier result files retain their original sequential protocol.

## Build and run

```sh
cd research/ffn/batched/bench
make                                   # build/batch-bench, build/build-batch-dataset, build/wmma-rates
../hardware-run ./build/batch-bench \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,64,128,256 --iters 40 --warmup 10 --json results/mine.json
./build/batch-bench --list             # every registered candidate, its claim and its description
make list-candidates                   # which sources the build picked up
```

`make` needs `bonsai-halo` built (`make -C /path/to/workspace/projects/bonsai-halo`) only for
`build-batch-dataset`, which links the engine objects the shipped binary was built from.
Build products stay in `build/`.

Before measuring each batch size, the driver runs candidates for `--ramp-ms 2000`
by default. This is untimed GPU work, not a sleep or a clock override. It prevents
millisecond call-count warmups from putting the first measured rounds inside the
idle-to-load clock ramp. The requested duration is recorded as `ramp_ms`; telemetry
covers both the ramp and measured windows. `--warmup` still controls first-round
candidate warmup calls, and later rounds rewarm each candidate for two calls.
A timed ramp does not guarantee fixed clocks or exclude other GPU clients.

`--reference-candidate NAME` adds an untimed checked evaluation of a selected
candidate. Each result keeps `error_vs_engine` and also records
`error_vs_candidate` and `candidate_reference_sha256`. The reference must be in
`--candidate`; nonfinite reference outputs abort the comparison. This measures
actual vector differences rather than subtracting two engine-relative RMS errors.

## Adding a candidate from another worker directory

Drop a `.hip` file in a sibling research directory's `candidates/` folder.
The Makefile globs `../*/candidates/*.hip`, so no shared file changes. Implement the
[`api.hpp`](../api.hpp) contract and register it:

```cpp
#include "../../api.hpp"
namespace {
void * prepare(const kelana_batch::Weights & w, int max_batch);  // untimed, sees no activations
void run(void * state, int rows, const float * input, float * output, hipStream_t);
void release(void * state);
size_t resident_bytes(void * state);
kelana_batch::Candidate mine() {
    kelana_batch::Candidate c{};
    c.name = "mine";
    c.claim = kelana_batch::Claim::approximate;   // or exact_reference
    c.description = "one line, printed and recorded in every result file";
    c.prepare = prepare; c.run = run; c.release = release; c.resident_bytes = resident_bytes;
    return c;
}
}
KELANA_BATCH_REGISTER(mine)
```

What the driver guarantees and requires:

- `prepare` is called **once per process**, before any input exists, with `max_batch` equal to the
  largest requested batch. Both activation buffers are filled with `0x7f7f7f7f` at that moment, so
  preparation that peeks at activations sees signalling garbage, and one preparation has to serve
  every batch size. Weight repacking, allocation and upload belong here.
- `run` receives row-major FP32 `[rows][width]` input and a separate `[rows][width]` output. It owns
  everything input-dependent: quantisation, packing, projections, nonlinearity, the residual write.
  The output buffer is poisoned before the checked pass, so a candidate must write every element.
- `run` is called back to back within randomized timing blocks on one stream. Anything the candidate needs zeroed between launches
  it must handle itself; the driver does not reset scratch between intervals.
- `resident_bytes` is reported so a table-heavy or expanded-weight candidate is comparable against a
  candidate that reads the deployed 58.5 MB of ternary tiles.

The `Weights` fields map onto the deployed FFN as: `gate`/`up` are HALO tiles `[FF][D]`, `down` is
`[D][FF]`, `norm_*` is the post-attention norm weight already folded with the width-`D` sign vector,
and `signs_*` is the width-`FF` Hadamard sign vector. Host and device copies hold the same bytes, so
a `prepare` can build any layout it wants on the host.

## The dataset

`/path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00`, described by
[its own provenance file](/path/to/workspace/data/kelana-ffn/README.md). 256 real contextual rows: tokens
0..255 of one document, each at its own position with the real attention and recurrent state of
every preceding token. A batch of N rows is the first N/8 captured chunks concatenated in document
order.

The deployed kernel carries 8 rows per pass, so a 256-row batch cannot come from one pass. It does
not need to: the FFN is row-independent once the incoming residual is fixed. That is not an
assumption here, it is measured — `deployed_chunk8` reproduces the engine's own captured output
**bit for bit** at 32, 64, 128 and 256 rows, which is only possible if the concatenated rows are the
rows the engine actually computed.

## Reading a result file

Every interval is kept in `ms_samples`. The resident `bonsai-halo` server shares the GPU, so a
minority of intervals land in a much slower regime; those samples stay in the file and
`stalled_samples_over_2x_median` counts them, rather than being filtered out. `ms_median` describes
the uncontended regime and `burst_wall_ms` gives the end-to-end cost including dispatch.

Errors are measured against the residual the engine itself produced for those rows:
`rel_rms` is RMS error over reference RMS, `bias` is the mean signed error (an unbiased local error
can become biased through a nonlinearity, so it is recorded separately), and `worst_row_rel_rms`
shows whether error concentrates in a few rows.

## Results

gfx1151, 20 CUs, layer 0, 40 intervals per point, resident `bonsai-halo` server sharing the GPU.
Full records in [`results/baselines-layer0.json`](results/baselines-layer0.json) and
[`results/baselines-layer10.json`](results/baselines-layer10.json).

Median ms per batch, and rows per second:

| candidate | 32 | 64 | 128 | 256 | rows/s at 256 | rel_rms vs engine |
| --- | --- | --- | --- | --- | --- | --- |
| `deployed_chunk8` | 4.086 | 7.063 | 14.153 | 29.458 | 8 690 | 0 (bit exact) |
| `native_iu8` | 1.451 | 1.880 | 3.590 | 7.043 | 36 349 | 1.8e-05 |
| `native_i4` | 1.108 | 1.790 | 3.337 | 6.716 | 38 116 | 1.8e-05 |
| `native_fp16` | 2.718 | 3.032 | 5.172 | 10.153 | 25 213 | 1.1e-04 |

The deployed schedule is flat in rows per second, because it re-reads all 58.5 MB of ternary weights
once per 8 rows: 32 times over a 256-row batch. That flat line is the headroom the batched
investigation is aiming at, and it is why a batched candidate should be compared against the native
baselines rather than against `deployed_chunk8` alone.

The native baselines are not flat either, for the opposite reason. At 32 rows `native_iu8` moves its
267 MB of int8-expanded weights in 1.45 ms, about 184 GB/s, which is close to what this machine's
memory gives; it is bandwidth bound and the batch size barely matters. By 128 rows the weight read
is amortised and the limit moves to the matrix unit, at roughly 19 TOPS against the 55.7 TOPS the
IU8 WMMA issues in isolation. The remaining gap is the prep phases, the operand feed and the fact
that one workgroup here reuses a weight operand only four times.

`native_i4` is the same arithmetic with half the weight bytes, so its advantage is largest exactly
where the weights dominate (24% at 32 rows) and smallest once compute dominates (5% at 256 rows).

### Everything registered, on one dataset, through one driver

[`results/combined-layer0.json`](results/combined-layer0.json), 20 intervals per point, with the
arithmetic worker's candidates discovered from `../arithmetic/candidates`. Median ms:

| candidate | 32 | 256 | rel_rms at 256 |
| --- | --- | --- | --- |
| `deployed_chunk8` | 4.048 | 29.062 | 0 |
| `native_iu8` | 1.467 | 7.000 | 1.8e-05 |
| `native_i4` | 1.108 | 6.618 | 1.8e-05 |
| `native_fp16` | 2.722 | 10.215 | 1.1e-04 |
| `arith-iu8-a8` | 1.138 | 4.389 | 1.2e-04 |
| `arith-iu4-a4` | 1.035 | 3.318 | 9.6e-03 |
| `arith-paired-a4` | 0.897 | 3.070 | 9.6e-03 |
| `arith-iu4-a4-down8` | 1.069 | 3.590 | 6.5e-03 |
| `arith-paired-a4-down8` | 1.557 | 7.565 | 6.5e-03 |
| `arith-paired-a8` | 2.104 | 13.881 | 1.2e-04 |

Read the error column before the time column. `arith-iu8-a8` keeps eight-bit activations and lands
at 1.2e-04, the same order as the FP16 baseline; it is 1.6x faster than `native_iu8` because it
reads ternary weights at two bits instead of expanding them to int8. The `-a4` variants narrow the
activations and pay two orders of magnitude more error for roughly 30% more speed, which is a lossy
trade and belongs to the lossy acceptance work, not to this baseline table.

### Raw instruction rates, measured not assumed

[`results/wmma-rates.txt`](results/wmma-rates.txt), from `build/wmma-rates`:

| instruction | TOPS |
| --- | --- |
| `wmma_i32_16x16x16_iu8` | 55.7 |
| `wmma_i32_16x16x16_iu4` | 111.0 |
| `wmma_f32_16x16x16_f16` | 55.6 |
| `sudot4` (`v_dot4_i32_iu8`) | 29.4 |

IU4 really is twice IU8 on this target, and FP16 matches IU8 rather than halving it. The deployed
dot4 path issues at about half the IU8 WMMA rate, which is why the deployed kernel switches to WMMA
at 8 rows.

### What actually differs between the baselines

Every baseline keeps the deployed input semantics exactly. All of them call the engine's own
`prep_chunk_r` for the post-attention RMS norm, the folded sign vector, the 1024-point Hadamard and
the per-128 int8 quantisation, at both the input and the hidden activation. Only the projection
changes. So the error column is a property of the projection, not of a different pipeline.

- `native_iu8` and `native_i4` accumulate in int32 within each 128-wide block, exactly as the
  deployed matvec does, then in FP32 across blocks. The arithmetic is identical; what differs is the
  order in which the FP32 block partials are summed, because a different schedule visits them in a
  different order. That alone accounts for the 1e-05 relative RMS, and it is symmetric noise rather
  than a systematic shift: at 256 rows the mean signed error is 2.3e-10 against a reference RMS of
  0.138, and the worst single row is 2.5e-04 relative.
- `native_i4` matches `native_iu8` on every error statistic at every batch size measured, including
  the mean signed error and the worst row. It has to be: the
  4-bit values are the same ternary weights, unpacked to int8 before the same IU8 WMMA. Nothing is
  requantised, and this is a storage and bandwidth comparison, not a comparison between a ternary
  and a four-bit model.
- `native_fp16` does reassociate. The per-128 block scale is folded into the weight, so the whole K
  is summed in one FP32 accumulator instead of being rescaled every 128 elements, and both operands
  carry FP16 rounding. Its 1e-04 relative RMS is that real numeric difference. It also costs more,
  not less: FP16 weights are 534 MB against 267 MB for int8 and 134 MB for 4-bit storage, and the
  FP16 WMMA issues no faster than IU8.

Resident device bytes at `max_batch` 256, reported by each candidate: `deployed_chunk8` 11.7 MB on
top of the engine's own HALO tiles, `native_iu8` 323 MB, `native_i4` 190 MB, `native_fp16` 594 MB.
Preparation, which is untimed, costs 2 ms, 191 ms, 188 ms and 1594 ms respectively; the FP16 case
is dominated by host-side conversion of 267 M weights.

One detail worth knowing before writing a 4-bit kernel: the IU4 WMMA needs *both* operands 4-bit.
A baseline that also narrowed the activations to 4 bits would be a different numeric object and
belongs with the lossy work, not here. The 111 TOPS IU4 figure above is what such a kernel could
aim at; `native_i4` deliberately does not claim it.
