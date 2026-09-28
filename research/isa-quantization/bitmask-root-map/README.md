# Literal-bitmask main alphabet + signed-root residual at a complete Q-head boundary

**Result.** A changed, inexpensive arithmetic alphabet was fitted at the exact 50,322-byte standalone size of the table-free QuIP# root control. It has no generic codebook or preparation table, and its complete gfx1151 reader compiles with the same registers/LDS and only 88 B more kernel body than the existing root reader. But the one predeclared train-only fit loses to both the same-byte root and two-byte-smaller scalar controls on held full-input raw response and held complete causal attention. It is **not** an improvement to the measured quality/static-size frontier. No GPU execution or runtime ordering is claimed; a cheaper dynamic main decode might still change execution cost.

## One fixed question, image, and fit

This is a new *approximate map*, not a lossless recoding of QuIP# E8P. Each transformed eight-block has a 16-bit main word and one root byte. The main word's high byte directly selects eight independent magnitude bits (each `1` or `3`, multiplied by `1/2`); its low byte chooses an even-parity signed vector plus a quarter-unit common offset through the original QuIP sign/parity rule. The root byte uses the exact signed E8-root program (including zero code 127); its contribution is divided by the frozen 2.04 residual scale. For each transformed output row, four additional FP16 gains apply to consecutive **256 transformed-Hadamard-input** coordinates, before output Hadamard and signs. The original global FP16 scale and 128-B input/16-B output sign fields were frozen from the root-H source image. These gains do **not** multiply four original-coordinate input groups: the complete program is `diag(SV) H128 [scale × (gains ⊙ (main + root/2.04))] H1024 diag(SU)` with gains indexed in each transformed row.

| Paid field | Bytes |
|---|---:|
| Main low sign/parity + literal high magnitude byte, 16,384 blocks | 32,768 |
| Signed root residual, 16,384 blocks | 16,384 |
| Frozen packed SU/SV signs, frozen FP16 global scale | 146 |
| Four FP16 transformed-input-range gains per each of 128 output rows | 1,024 |
| Generic table / descriptor / expanded weights | 0 |
| **Total standalone stored image** | **50,322** |

The resulting [`bitmask-root-standalone.bin`](bitmask-root-standalone.bin) has SHA-256 `3f4d8ba94bc67a9fe7801b77975918c996e075b304dc0d7651bb9a68d81e9cce`, effective `3.0714111328125` bits/original weight. Here **all 50,322 B are model-specific**, unlike QuIP root's 49,298 B model-specific + once-billed 1,024 B generic table. If several model matrices share one reader pool, replacing N root images costs an extra `1,024N−1,024` stored/resident data bytes before the new kernel body, not a repeated per-matrix table saving. Nothing is predecoded offline for runtime. Input128×1024 weight is from the fixed Qwen3-0.6B layer-00 q-projection fixture SHA `389e5f8c17ac151070b12094849f450130ab9c1684f51b402d59fd4e7ac2008f`. The frozen root image SHA is `d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a`.

Before inspecting candidate held scores, the rule was sent to the coordinator and fixed: source SU/SV/global scale, initial zero-root and four gains=1; **exactly two** rounds of nearest eight-coordinate source-teacher block assignment `main → nearest of 256 root bytes → main`, with the main assignment enumerating 128 even-sign patterns × two quarter-offset parities and independently selecting the closer `1/3` magnitude per coordinate. Each round ends with a **train-only joint 4×4 least-squares gain solve for every row** on the *entire* 2,048×1,024 training producer-state panel, then FP16 rounding. No held choice, downstream loss, damping or extra coordinate-search iteration affects labels/gains. Assignment itself is Euclidean in transformed teacher coordinates rather than full cross-block response covariance; the gains are response-fitted across all four transformed ranges. The 16 separate eight-row chunks per round each finish within a minute. `fit.py` is preparation only; its `emit/` records are regenerable, not inference state.

[`replay.py`](replay.py) imports no fit/packing function. It checks image and fixture hashes, independently parses every code, gain, residual and sign/scale, reconstructs all 128×1,024 weights and scores all 2,048 train/1,024 held source states. `check_fit.py` compared the independent decoded matrix with the 32 retained train-only chunk preparations **elementwise, max absolute difference 0**, and checked the frozen source field bytes. Ideal relative squared full-Q response errors:

| Image | Bytes | Train | Held |
|---|---:|---:|---:|
| Literal bitmask + root + gains | **50,322** | .021703667 | .022234612 |
| Frozen root-H QuIP# | 50,322 | .003842229 | .013109790 |
| Frozen scalar-H group128 Q2/Q3 | 50,320 | .012346793 | .014627799 |

## Complete causal observer, with common state paid

The frozen new image was passed without refit through the **same canonical 8 train + 4 held windows**, original source model Q-head identity check, BF16-rounded Q/K/V projections, Q/K RMSNorm and gamma, position-dependent RoPE, causal softmax, shared V/O and peer GQA Q head as [`../quip-complete-head-observer/`](../quip-complete-head-observer/). `observer.py` adds one independent image decoder to that exact observer; root-H/scalar-H/root-M/scalar-M baselines are all replayed in the same calls and match their published aggregates. Original K/V/peer-Q/O/gamma total **1,311,232 common bytes** in every arm, plus the changed Q image; the other heads/layers are unchanged. This is CPU BF16/Torch observer approximation, not an emitted GPU BF16 rounding assertion.

| Panel/image | BF16 raw-Q rel sq | normalized-Q rel sq | head-0 causal KL | head-0 post-O rel sq | shared two-head post-O rel sq |
|---|---:|---:|---:|---:|---:|
| Train bitmask | .02170629 | .03856219 | .02990230 | .02637746 | .00235192 |
| Train root-H | .00384632 | .00650720 | .00577451 | .00603990 | .00053854 |
| Train scalar-H | .01234937 | .01510696 | .01320982 | .01510679 | .00134698 |
| Held bitmask | .02224389 | .04081650 | **.03361544** | .02724179 | .00279764 |
| Held root-H | .01310947 | .02141683 | .02416825 | .02784225 | .00285930 |
| Held root-M | .01261853 | .02097905 | .02312622 | .02603103 | .00267330 |
| Held scalar-H | .01462970 | .01812619 | **.01821224** | **.02185195** | **.00224412** |

It is notable that bitmask slightly improves held post-O versus *root-H* even as its KL and normalized-Q deteriorate; its post-O is still worse than root-M and scalar-H. Thus raw-Q alone must not stand in for complete causal behavior. Full per-window error numerators/denominators and fixed-source checks are in `train-*.json`, `held-*.json`, [`observer-results.json`](observer-results.json); exact ideal response in [`results.json`](results.json). These observations do not imply a general impossibility for literal masks under different quantization fits or native lowering.

## gfx1151 compile-only complete reader and work boundary

[`reader.hip`](reader.hip) has the original root magnitude-table arm and the new literal-bitmask arm in one source unit. Both dynamically apply input signs, full 1,024-wide Hadamard, 128 blocks per row and direct signed-root residual, full 128-wide output Hadamard, output signs and global scale; the bitmask additionally reads four FP16 gains per output lane (512 logical per full response), chunks its 128 block reductions in four spans and reads **no** generic magnitude table. The input Hadamard costs 5,120 butterflies/10,240 add-sub; output Hadamard 448/896. Both read 16,384 main words and 16,384 residual bytes per response. This image has 7,278 sparse signed-root codes (34 zero), 9,106 half-root codes; main high labels use 254/256 possible literal masks. One block of 128 threads computes one Q response for each distinct live dynamic input; no expanded FP32 matrix is supplied. Source-based CPU parsing proves coefficient meaning, but actual GPU FP32 accumulation and numerical endpoint were **not** run.

`./build.sh` compiles `hipcc -O3 --offload-arch=gfx1151 -save-temps -c` and retains [complete emitted assembly](assembly-gfx1151.s), [symbol/resource receipt](compile-receipt.txt). `llvm-nm -S` on the device executable gives original table kernel body **3,056 B**, bitmask kernel body **3,144 B (+88)**, shared out-of-line input-transform helper **10,872 B** (output transform inlined). Both need 44 VGPR, 33 SGPR, 4,608 B LDS, zero scratch and 24-B kernel args; each also has its own 64-B descriptor and host launch wrapper outside the differential device-body ledger. At this one-image static boundary original root `50,322+3,056+10,872=64,250 B`; bitmask `50,322+3,144+10,872=64,338 B`, before common runtime/descriptors. At N matrices sharing one reader, the generic data is charged once and the new extra model-specific gains N times. Native time has **not** been measured: the bitmask removes one hot 32-bit magnitude load per block but pays bit extraction, 512 FP16 gain loads, four reduction boundaries and the same root branches and Hadamards. Emitted body size, nominal registers and count of loads do not establish the actual time ordering against the observed old root **31.120 µs** or hot residual-table **22.440 µs** reader; those prior timing receipts concern different frozen programs/images.

Reproduce with `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1` and `/path/to/workspace/data/fish-s2-pro/venv/bin/python`: invoke `fit.py chunk FIRST FIRST+8 ROUND` for FIRST=0,8,…,120 and ROUND=0 then 1, one sub-minute invocation per chunk; `fit.py finish`, `replay.py`, `check_fit.py`; `observer.py train WINDOW` for 0…7, `observer.py held WINDOW` for 0…3, `observer.py aggregate`; then `./build.sh`. No GPU reservation or GPU call occurs. The offline source model and fixture are owned by the Kelana Qwen capture documentation, and the canonical parent owns the QuIP/source decoder and common catalogue.
