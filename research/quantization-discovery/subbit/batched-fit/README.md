# Batched NanoQuant ADMM initialization on gfx1151

The 196 Qwen3-0.6B projection matrices have packed ADMM-only binary images in `/path/to/workspace/data/kelana-subbit/full-model/binary055/`. All 14 task groups finished with 400 outer iterations, five SVID power iterations per projection/update, linear rho, rank allocation from the pinned `.55` BPW rule, and FP16 pre/post scales. The 196 solves used **284.49 seconds of measured GPU solve time** across bounded foreground reservations. This is an initializer and packing route, not a claim about NanoQuant's trained full-model quality. The [complete task receipt](full-model-receipt.json) names every run; each output directory retains its input/source identity, per-chunk timings, clocks and every image hash.

The failed first attempt to fit 16 matrices in a single batched Cholesky workspace produced `HIPBLAS_STATUS_ALLOC_FAILED` in `hipblasStrsmBatched`. The repaired CLI automatically fits at most eight matrices together, frees that graph and its allocator state, then fits the next eight in the same invocation. It limits an invocation to 16 inputs, so the existing GPU wrapper's 45-second deadline remains useful at the measured `.55` rank. The first failed invocation and log are retained as evidence at `binary055/2048x1024-00/`; the recovered successful task has a separate `recovery-invocation.json`, source hash and clock. We recovered all 16 images from that exact input group instead of redoing them after repairing the queue.

## Solver contract

[`fit.py`](fit.py) exposes `fit_group(weight, i_norm, o_norm, rank, outer_iters=400, inner_iters=5, graph=True, sync_every=10)`. Its inputs are CUDA FP32 tensors `weight[B,N,K]`, squared input-channel norms `[B,K]`, squared output-channel norms `[B,N]`, with `N >= K`. It returns `A[B,R,N]`, `B[B,R,K]`, `scale_pre[B,K]`, `scale_post[B,N]` and timings. The CLI transposes wide weights, swaps their norms, batches by the resulting shape and rank, then swaps A/B and scales back before saving the original orientation. A caller can feed weight/norm NPZs without a calibration fixture:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
D=/path/to/workspace/projects/kelana/research/quantization-discovery/subbit/batched-fit
/path/to/workspace/projects/bonsai-halo/tools/run-batch-compare --runtime-max 45s --memory-gib 12 \
  --exec env OPENBLAS_NUM_THREADS=4 "$P" "$D/fit.py" --graph --rate .55 \
  --out OUTPUT_DIR INPUT_1.npz INPUT_2.npz
```

Each input NPZ has `weight[N,K]`, `i_norm[K]`, and `o_norm[N]`, in that order's original orientation. Norms are **squared** nonnegative channel moments. Group inputs by identical shape after transposing any wide matrix; no more than 16 per invocation. The `.55` allocator rounds ranks down to 32, yielding 256 for 1024×1024, 352 for 2048×1024, and 384 for 3072×1024. Each output `STEM-gpu.npz` has the same NanoQuant field contract as the CPU comparator: `U[N,ceil(R/8)]`, `V[R,ceil(K/8)]` low-bit-first signed planes, `scale_pre[K]` and `scale_post[N]` FP16, and `dimensions[N,K,R]`. A set bit is +1. `run.json` records each source/input/image SHA-256, complete or partial state and per-chunk setup, graph capture, solve, output and total wall seconds. It commits the receipt atomically after each completed chunk. Duplicate input stems, inconsistent shapes, non-finite inputs and failed Cholesky stop rather than publishing a claimed complete group.

The implementation matches the upstream initializer's sequence: sqrt input/output norms; normalize W; random A/B; sign-value-independent rank-one initial Z; alternating stabilized FP32 normal-equation Cholesky solves; SVID projection through five power iterations on each updated factor; dual update; and balancing and mean-absolute scale extraction. The positive-definite stabilizer is `max(rho * mean(abs(diag(XᵀX))) + .03, 1e-12)`. It retains the upstream FP32 mathematics but not its precise random draw stream or bitwise output. Unlike the upstream CUDA-enabled module's `allow_tf32=True`, this run uses PyTorch 2.14 ROCm's default `allow_tf32=False`. Packed signs and rounded scales define the quality comparison, not latent continuous `W_final`.

One graph captures a batched iteration with resident state, GPU-indexed linear rho and GPU power-iteration random draws. Replaying without a device sync for more than about 20 steps crashed the HIP process during a 100-step panel; a sync every ten graph replays completed 400 steps across all groups. The code requires a graph sync interval of 1–10, never an unbounded queue. A one-matrix graph capture also failed inside hipSOLVER Cholesky; the CLI visibly dispatches a one-matrix group to the eager solver instead. These are measured ROCm constraints, not silently skipped solves. Cholesky `info` accumulates on the device and is checked once at the end rather than synchronizing for every item at every iteration.

## Bounded panel and CPU comparison

The first 16 existing WikiText projection fixtures provided a separate quality check. Run `fit.py --fixtures --graph --out DIR` on two groups of eight: Q with transposed attention O, and MLP up with transposed down. This option computes each input norm from its train activations with 0.4 diagonal shrinkage, sets output norms to ones and evaluates on its distinct 1,024-row validation activations. The images and run manifests are retained under `/path/to/workspace/data/kelana-subbit/batched-fit/fixture-panel/`. [`fixture-quality.json`](fixture-quality.json) names the paired CPU initializer receipts, source images, SHA-256 and all 16 response errors.

| Group of eight | Normalized matrix | GPU solve, s | Full CLI wall after Python start, s | CPU solver sum, s |
| --- | --- | ---: | ---: | ---: |
| Q and attention O | 2048×1024, rank 352 | 11.40 | 12.74 | 36.67 |
| MLP up and down | 3072×1024, rank 384 | 15.99 | 17.11 | 56.02 |
| Both | 16 matrices | 27.39 | 29.86 | 92.70 |

Across those 16, median held-out response relative squared error is **0.314878** for GPU output and **0.314845** for published CPU initializer output. Median absolute per-projection difference is **0.000764**. Layer-0 Q is 0.09812 against CPU 0.09666; layer-27 MLP down is 0.03432 against CPU 0.03420. These are same-fit-budget sample comparisons, not bit equivalence or a full-model NLL receipt. Both large groups were measured under the shared Bonsai GPU reservation, with device clocks and host contention in their data manifests. An eager batch-one Q solve took 2.68 s under an earlier source revision; batching eight 2048×1024 matrices takes about 11.4 s versus 8×2.68=21.4 s if run singly, about 1.9x more matrices per GPU second. The CLI reports graph capture and export separately from the solve.

## Full-model custody and operations

The input source is `/path/to/workspace/data/kelana-subbit/full-model/fit-inputs/manifest.json`, which pins weights and squared input norms for 196 matrices. `run_task.py --task INDEX --source IMMUTABLE_FIT_PY` executes one indexed group through `run-batch-compare`, records `invocation.json`, `run.log`, `clock.json`, verifies input and output hashes, and skips an already complete group whose outputs still match. The measured immutable source is `/path/to/workspace/data/kelana-subbit/full-model/fit-sources/fd8ed3ef6b9c14ed8b5e6267e5b4ffebb042830d4e8f88b277cc3c97e0a9c949/fit.py`. The full-model image quality and adoption belong to the programme coordinator's separate owner; these reports establish solver cost and the packed factor contract.

The fixture panel was measured from the earlier source snapshot `fe1354ef00ce9bc311599cae1f3acd7e16c5a276b4b784614452acbbe9c86c5c`, retained under the same `fit-sources/` directory. Its mathematics and eight-way graph path are unchanged; the later source adds bounded chunking, one-matrix dispatch and partial progress custody. The `full-model-receipt.json` points at every production image without copying weights into Git. Stop or retry one task rather than running all 196 in an unbounded shell command. No new service, runtime route or GPU resource was provisioned.
