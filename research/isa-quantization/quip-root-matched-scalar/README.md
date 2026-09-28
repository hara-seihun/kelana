# Two-byte-near scalar control for the root-coded full-row QuIP# image

This is a **complete stored-image scalar control** on all 1,024 inputs and the first 128 outputs of the captured Qwen3-0.6B layer-00 q-projection. Its **50,320-byte** group128 mixed Q2/Q3 image scores full-panel relative squared train/held response errors **.012346793 / .014627799**. The parent root-coded QuIP# E8P12RVQ3B image is **50,322 B** when the exact E81B root decoder replaces the 4,096-byte residual table; its output is identical to the independently replayed [54,418-byte table image](../quip-full-row-slab/README.md), whose full-panel train/held errors are **.003842229 / .013109790**. Therefore the named structured reader wins this *near-equal-standalone-byte* held comparison against this scalar fit, despite losing to the prior **54,416-byte Q3/Q4** scalar at a different rate (.010423200 held). These are separate finite achievable controls, not global method rankings or model NLL results. The root-code format and exactness are owned and independently checked by the parent study; this directory owns **only** the fresh scalar control.

## Source, budget, and fit

The fixture is `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz`, SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`. Its `weight[:128,:]`, all 2,048 training producer rows and all 1,024 held rows are used without cropping input coordinates. The metric is `||X (Ŵ−W)ᵀ||²/||X Wᵀ||²` separately on train and held. **Only training states** enter Q2 fitting, group selection, and field refitting; held states enter only the final independent replay.

[`fit_q2.py`](fit_q2.py) adds eight independently bounded Q2 group128 fits through the same [`matched-rate-frontier/fit.py`](../matched-rate-frontier/fit.py) machinery as the prior Q3/Q4 control: full within-group response covariance, 1% mean-diagonal damping in inverse-Cholesky sequential error compensation, three clipping starts, four affine grid alternations, and FP16 rounded scale/origin fixed-code response refit. The eight actual Q3 group-code and field records are **reused unchanged** from [`../quip-full-row-slab/group-{0..7}.npz`](../quip-full-row-slab/README.md), not recomputed or weakened for this comparison. Each new [`group-q2-N.npz`](group-q2-0.npz) retains the Q2 codes and FP16 fields and is preparation state, not read by the inference decoder.

[`assemble.py`](assemble.py) begins with all 1,024 Q3 groups, builds the **whole 1,024-coordinate train Gram**, and evaluates every Q2 downgrade's actual group and cross-group response interactions. It greedily selects exactly **191 Q2 groups** under the byte budget, updating same-row gains for preceding choices. Those choices and fields are in [`selection.npz`](selection.npz). With codes fixed, it solves the 16-field full-input train-response normal equations for each output row, FP16-rounds all fields and accepts only a strict train-error decrease; **128/128 rows** improved. Four `refit-*.npz` chunks retain those preparation choices. Code search itself does not jointly revisit codes across groups. Other scalar optimizers or row partitions might do better.

| Field | Bytes |
| --- | ---: |
| 833 Q3 groups ×48 coefficient bytes | 39,984 |
| 191 Q2 groups ×32 coefficient bytes | 6,112 |
| 1,024 FP16 scale/origin pairs | 4,096 |
| One 1,024-bit mode mask | 128 |
| **Complete scalar image** | **50,320** |

The effective rate is `8×50320/(128×1024)=3.0712890625` bits/original coefficient; exact root-coded standalone QuIP at 50,322 B is 3.0714111328125. The scalar image SHA256 is `e41d273bd2d5ea7ef497e6c2749bf6ac5b1529124f8e24d2ea2448132dfdfd15`. The parent QuIP model-specific fields remain 49,298 B plus 1,024 B of once-billed generic E8P absolute table; the root-code residual decoder has no persisted 4,096-byte residual table. No code/cache/weight expansion is hidden in either paid serial image. These are still different readers: QuIP requires both dynamic Hadamards, index/sign arithmetic and reductions, while scalar extracts packed codes and applies per-group affine fields. Native full-row execution, register use and throughput are not measured here. A model-specific predecoded FP32 matrix would add 524,288 B live and is not either of these readers.

[`replay.py`](replay.py) imports **none** of the fitting or packing functions. It verifies the fixture and image hashes, unpacks the mode mask and every 2-/3-bit digit directly from the stored image, verifies positivity/finiteness of each FP16 field, exact payload exhaustion and 191/833 group counts, reconstructs all 128×1,024 weights, and computes complete train/held scores. [`results.json`](results.json) binds the image fields and scores. The older QuIP table image is scored by [`../quip-full-row-slab/replay.py`](../quip-full-row-slab/replay.py); the root-code owner establishes its mathematical output equivalence rather than this scalar study asserting it from an absent root image.

```sh
cd /path/to/workspace/projects/kelana
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
PY=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for g in 0 1 2 3 4 5 6 7; do $PY research/isa-quantization/quip-root-matched-scalar/fit_q2.py "$g"; done
$PY research/isa-quantization/quip-root-matched-scalar/assemble.py select
for s in 0 32 64 96; do $PY research/isa-quantization/quip-root-matched-scalar/assemble.py refit "$s" "$((s+32))"; done
$PY research/isa-quantization/quip-root-matched-scalar/assemble.py finish
$PY research/isa-quantization/quip-root-matched-scalar/replay.py
```

Every fitting or scoring invocation is individually bounded below a minute with single-threaded BLAS. No GPU or held-set choice is involved.
