# A two-layer sparse input circuit: priced selected fit

**Comparable-size scope:** the measured 8,672-byte circuit loses accuracy to an 8,704-byte local Q4 image, while reducing nominal contributions. That is useful near-size evidence for this selected support, not universal family exclusion or a measured joint size/error/work dominance. A named matched-rate structured control remains required by the [benchmark contract](../BRIEF.md#comparable-size-state-of-the-art-is-the-target).

The [disjoint signed-pair certificate](../input-programs/README.md) rules out matching its larger Q4 control's accuracy using one particularly cheap rank-96 input programme. This study instead allows **480 overlapping, freely weighted input edges** and a low-bit paid output readout. Sixteen edges mix the 32 coordinates being eliminated; 464 edges fan those mixed coordinates into 96 surviving live lanes. The resulting rank-96 input subspace is not a disjoint pair subspace. It reduces the number of output coefficient contributions by 4,096 on the same real Qwen3-0.6B layer-0 `q_proj` 128-input/128-output subprojection, but its **best fitted image loses** to the exported 8,704-byte scalar Q4 control on both captured panels.

## Circuit and response objective

Write the original input as `x=(x_K,x_R)` after reordering, with 96 retained coordinates `K` and 32 removed coordinates `R`. First form 32 intermediate coordinates `u=x_R S`, where `S=I+16 sparse FP16 shears`. Then form 96 live coordinates `z=x_K+u A`, where `A` has 464 sparse FP16 entries. Finally compute all 128 outputs from `z B`, where `B` is a row-affine four-bit grid: each output row stores 96 nibbles and one FP16 origin/step pair. This is a genuine two-layer input computation (`x_R → u → z`) feeding a paid readout, not an unpaid free rank-96 factor. The affine origin multiplies the sum of the 96 live coordinates; it is not a free output bias. All computations are linear and preserve zero.

The producer-weighted fit minimizes `||X(Wᵀ-TB)||²/||XWᵀ||²`, where `T=[I;SA]` after input reordering. `study.py` greedily removes 32 coordinates by the **exact conditional response increase** at each removal, then greedily selects edges by full 128-output response gradients. Fixed-support block updates minimize the real-readout objective one sparse input row at a time and refit all 128 outputs. `deep.py` adds the sixteen input shears, repeats fixed-support block minimization, rounds every stored edge to FP16, refits the real readout to the rounded input transform, then fits each affine nibble row against the **full train carrier covariance**. Only the 2,048 train states select fields; 1,024 held states are scored after export. These are deterministic local search choices, not global optimization or a universal family lower bound.

| Fixed candidate, relative squared complete-response error | Train | Held |
| --- | ---: | ---: |
| Two-layer circuit, **free real readout** following its FP16 input edges | **.0056632132** | — |
| Two-layer **stored/decoded affine-Q4 image** | **.0095978807** | **.0119358666** |
| One-layer 480-edge fan-out, stored/decoded | .0101820687 | .0123165495 |
| Existing scalar affine-Q4, stored/decoded | **.0051736144** | **.0051736150** |

The two-layer image has a `.0004895988` train gap **even with arbitrary real readout** after the selected, rounded input circuit; grid fitting adds another `.0039346675`. Its actual decoded train error is 1.855 times the scalar Q4 error. This is a **failed concrete circuit**: another support, a different two-layer topology, joint input/readout code optimization, nonlinear computation or a different producer can still win. In particular, a free-real readout score for one circuit is not a lower bound over all 480-edge circuits. The 128 outputs are a local boundary, not full-attention behavior or model NLL.

## Exact paid description and online ledger

The two-layer image [`two-layer-q4.bin`](two-layer-q4.bin), SHA256 `dcccf2e2c93b05edac51c0e367a945a7c842f62f82597da3f22aafb8623d53c6`, uses exactly **8,672 bytes**:

- 96 bytes: retained original input indices (u8 each); the removed indices are their sorted complement.
- 16 first-layer edges × 4 bytes = 64 bytes: removed-source index (u8), removed-destination index (u8), FP16 coefficient.
- 464 second-layer edges × 4 bytes = 1,856 bytes: intermediate-source index (u8), live-destination index (u8), FP16 coefficient.
- 128 output rows × (48 nibble bytes + 2 FP16 fields) = 6,656 bytes.

The comparator [`affine-q4.bin`](../producer-screen/affine-q4.bin) is 8,192 nibble bytes plus 512 FP16 row fields = **8,704 bytes**. Both contracts omit shared decoder code/framing and input/output array storage; no hidden model-specific table, gain, bias, or residual is used. Circuit savings are **32 stored bytes**, not a win in response quality. Relative to 16,384 direct coefficient products/accumulations, the circuit has **12,288 four-bit output coefficient contributions** plus **16 + 464 = 480 FP16-scaled input additions**. That is 12,768 scalar contributions versus 16,384 (3,616 fewer, 22.1%), but FP16 multiplies/adds, nibble decode, intermediate loads, output scale/origin handling, register pressure and instruction scheduling have different costs. It also reads 128 input coordinates, initializes 96 live lanes, and carries 32 intermediate lanes. The numbers are an operation/byte ledger, **not native gfx1151 instructions or latency measurements**; direct Q4 and the circuit have different arithmetic types. Even before native costing, this selected image loses the captured response comparator.

[`replay.py`](replay.py) separately parses the serialized first-layer and second-layer edges and affine rows, forms the complete 128-output linear map, independently decodes the original scalar Q4 image, and scores both train and held states. It agrees with the optimizer's exported-image scores. [`study.py`](study.py) also retains the simpler one-layer 480-edge control [`circuit-q4.bin`](circuit-q4.bin) and its complete receipt [`results.json`](results.json). [`two-layer-results.json`](two-layer-results.json) contains the chosen coordinate indices, optimization trajectory, operation ledger and image hash. The mathematical fixed-program free-readout floor is a least-squares projection; the numerical scores and optimization trajectory are FP64 computations, not exact-arithmetic certificates or Lean theorems.

## Reproduction

The original BF16 weights, train and held states are in `/path/to/workspace/data/kelana-subbit/fixtures/qwen3-0.6b-wikitext/layer00-self_attn_q_proj.npz`, SHA256 `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`. The comparison image belongs to producer-screen. From Kelana root, with one CPU BLAS thread (each computation takes well under one minute):

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/sparse-input-circuit/study.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/sparse-input-circuit/deep.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/sparse-input-circuit/replay.py
```

`deep.py` imports `study.py`, so run from its own directory path as above. No fixture duplication, training, GPU work or full-model image is involved. The result is a train/held captured-panel diagnosis of a *specific sparse-circuit search*, not a certificate excluding deeper or differently allocated circuits.
