# Kelana

Kelana studies exact and approximate model computation: packed representations, ISA-level map search, quantization, expert routing, speculative decoding, and the proofs and measurements that distinguish a construction from a realized speedup. [The research catalogue](research/catalogue/README.md) indexes results by scope and evidence; [the lessons](LESSONS.md) explain the underlying approach.

## Headline results

- **2×2 ternary matrix multiply-add on gfx1151:** [a nine-instruction packed construction against a 13-instruction baseline](research/toy2/README.md), with the [full derivation and boundaries](research/toy2/PROOF.md). [`Kelana/Toy2.lean`](Kelana/Toy2.lean) proves the algebra, encoding, bounds and cost comparison; [`research/toy2/check.py`](research/toy2/check.py) exhaustively checks **531,441** ternary A/B/C inputs. [`kernels.s`](research/toy2/kernels.s) and [`assembly-results.json`](research/toy2/assembly-results.json) show the gfx1151 opcode counts. This is an instruction-count improvement over that baseline, not a claim of global optimality or a measured 13/9 latency ratio.
- **Beyond a fixed decomposition:** [one-dot radix-64 mapping](research/toy2/radix64/README.md), [composition proofs](research/composition/README.md), and [whole-map observer search](research/discovery/observer-search/README.md) study programs acting directly on packed labels. The one-dot core grants input wiring and does not price a downstream radix-64 consumer.
- **Wider model research:** [ISA-aware quantization](research/isa-quantization/README.md), [complete-model ternary work](research/ternary/README.md), [MoE](research/moe/README.md), [speculative maps](research/speculative-maps/README.md), and [FFN work](research/ffn/full-map/harness/README.md) retain their own measured claims and qualifications.

## Reproduce the toy result

The Lean project pins its toolchain in [`lean-toolchain`](lean-toolchain) and uses the dependencies in [`lakefile.toml`](lakefile.toml) and [`lake-manifest.json`](lake-manifest.json).

```sh
lake build
lake env lean research/Audit.lean
python3 research/toy2/check.py --output /tmp/kelana-toy2-check.json
python3 research/toy2/assemble.py --output /tmp/kelana-toy2-assembly.json
```

The assembler check requires the LLVM AMDGPU assembler/disassembler. The native GPU scripts require a gfx1151 device and HIP. The finite Python check and Lean proof are independent of the GPU. See [the proof handoff](research/toy2/PROOF.md) for the exact cost boundary.

## Bonsai inference and proof coverage

[Bonsai Halo](https://github.com/hara-seihun/bonsai-halo) publishes the single-stream, speculative, batched and serving implementations, measured reports, native operand checkers and [historical measurement receipts](https://github.com/hara-seihun/bonsai-halo/tree/main/evidence). This repository publishes all **162 tracked Lean files** from the recovered Kelana source, together with the pinned toolchain and research checkers. The [Bonsai contracts](BONSAI.md), [ternary FFN](Kelana/TernaryFFN.lean), [ternary algebra](Kelana/TernaryAlgebra.lean), [SIMD consumer](Kelana/SimdTernaryConsumer.lean) and [Toy2 proof](Kelana/Toy2.lean) are useful entry points. This coverage statement is about the recovered source files, not a fresh proof build.

The research index is refreshed through local source `a7e11746`. Newer external programme citations point to their original owners; their full workspaces are not copied into this repository.

## Snapshot scope

This public snapshot exports source, proofs, research notes and compact receipts from the local research tree without its commit history. Large datasets, model images, raw measurements and generated binary artifacts are not included; some research reports refer to those separately held inputs by hash. The public repository is not a complete reproduction package for every model-scale experiment. AMD's ISA documentation is available from AMD; the large vendor source dumps are not redistributed here. Files originally referring to local paths use `/path/to/workspace/` as a neutral placeholder, not a public data URL. Related implementations: [Bonsai Halo](https://github.com/hara-seihun/bonsai-halo) and [Map Optimizer](https://github.com/hara-seihun/map-optimizer).
