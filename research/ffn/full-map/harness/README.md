# FFN-spanning benchmark harness

A complete residual-to-residual Bonsai FFN for one layer, runnable on real PTQ1_0 weights and real
activations, with a callable interface a changed map can be dropped into.

The baseline is the deployed code, not a re-derivation: `candidates/baseline.hip` calls
`ph_prep` and `ph_matvec_auto` from `bonsai-halo/kernels/phases.hpp` with the flags, segment
geometry, block splits, device barrier and row dispatch of `kernels/halo_rows.hip` lines 206-215.
It reproduces the engine's own output bit for bit at 1 and 8 rows, including the intermediate
gate/up projections and the quantised hidden activations.

## Scope of a timed interval

One `run` call covers the whole layer FFN: post-attention RMS norm, sign, Hadamard and int8
quantisation, the gate and up projections, `SiLU(gate) * up`, sign, Hadamard and quantisation
again, then the down projection accumulated into the residual. Prep, conversions, nonlinearities,
the residual write and all weight traffic are inside it. Static weight transformation and model
loading belong in `prepare`, which is untimed.

The input residual lives in an immutable device copy and is restored into the mutable `x` between
intervals, outside them, so repetitions never iterate the FFN.

## Build and run

```sh
make                                     # ffn-bench and build-dataset
./build-dataset --layer 0 --out /path/to/workspace/data/kelana-ffn/ptq1_0/layer00
./ffn-bench --dataset /path/to/workspace/data/kelana-ffn/ptq1_0/layer00 \
            --rows 1,8 --iters 300 --warmup 50 --json results/baseline-layer0.json
./ffn-bench --list                       # registered candidates
```

`build-dataset` links the engine objects the shipped binary was built from, so it needs
`bonsai-halo` built (`make -C /path/to/workspace/projects/bonsai-halo`). Other layers only need
`--layer N --out .../layerNN`; the barrier arithmetic and every file are layer-general.

## Where the data comes from

`build-dataset` runs real tokens through the deployed multi-row kernel and stops it at a barrier.
`k_forward_rows` takes 2 barriers before the layer loop and 10 per layer, so layer L's incoming
residual is live after barrier `8 + 10L` and its FFN output after `12 + 10L`. The 1-row case is a
single-token pass, the 8-row case an 8-token prefill pass of the same prompt, both from reset
state; neither duplicates a token nor uses noise. `input_kind` in the manifest names the origin of
every case, and a synthetic case would have to say so there.

The dataset directory holds the layer's HALO weight tiles exactly as the engine uploads them, the
folded norm and sign vectors, and per case: `x_in`, `x_out`, `gate`, `up`, the post-norm int8
quantisation (`xq_d`, `xs_d`, `xsum_d`) and the hidden int8 quantisation (`xq_ff`, `xs_ff`,
`xsum_ff`). `manifest.json` records the model, the `bonsai-halo` commit, the barrier indices, the
tokens and every file.

## Adding a candidate

Drop a `.hip` file in `candidates/`; the Makefile globs it and `KFFN_REGISTER` registers it, so no
shared file changes. Implement `prepare` (untimed: repack weights, allocate, upload), `run` (one
launch, residual in `Work::x` and out through `Work::x`), `grid`, and optional `release`.

The harness hands over `Work::x/xq/xs/xsum/gu`, a 64 MB `scratch` block, and `bar`/`work`/`prof`
slices that are already zeroed for this launch, so nothing inside the timed interval has to reset
barrier state. `prof` takes `nstages + 1` `wall_clock64` stamps (100 MHz) and the harness reports
each stage from them. `Weights` exposes both device and host pointers to the HALO tiles, so a
candidate can build its own layout on the host in `prepare`.

Set `emits_gate_up` or `emits_ff_quant` when the candidate leaves those intermediates in `Work` and
the harness checks them against the engine's capture. A fused candidate leaves them false and is
checked on the final residual alone.

## Reading the results

Every sample is kept in the JSON: `ms_samples`, per-stage `stages_us`, and the burst wall time.
Roughly a quarter of the intervals land in a ~5x slower regime while the GPU is shared with the
resident `bonsai-halo` server process; those samples are in the file, and the median describes the
uncontended regime. `weight_gbps_at_median` divides the layer's 58.5 MB of ternary weights by the
median interval.
