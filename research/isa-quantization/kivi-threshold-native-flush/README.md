# Ordered finite-grid threshold in a complete KIVI metric K-flush kernel

**Result: an exact observed CPU byte map and a compile-only division/code tradeoff, not a speed claim.** Replacing **only** the continuous FP64 quotient/rint nearest-code selection in the frozen [`../kivi-metric-native-flush/`](../kivi-metric-native-flush/) 128-thread metric K-flush placement by four ordered FP64 threshold comparisons reproduces all **96/96 saved metric K events (245,760/245,760 bytes)** on eight train/four inspected-held windows. The common original KIVI control also reproduces all 96 original events byte for byte. On `gfx1151`, the complete metric kernel's static FP64 division/reciprocal opcode sites fall **5→0**, while body grows **9,164→9,236 B** (+72), SGPR **12→14**, VGPR stays **62**, LDS **4,608 B**, scratch zero and one static barrier site. Total body+64-B descriptor+original 2,304-B immutable model-group FP16 metric is **11,604 B**, versus quotient kernel **11,532 B**. **No GPU execution or elapsed-time comparison**: removing a division site does not establish faster flush, native byte parity or a better complete attention endpoint.

## Fixed decision and unchanged obligations

The distinct exact finite-grid map and dyadic source proof are owned by [`../grid-threshold-decision/`](../grid-threshold-decision/), which establishes the adjacent-cost criterion for arbitrary rational positive curvature/step and documents observed 74-bit exact threshold magnitudes. This is one **FP64** realization of that mathematical map, not an exact-integer native implementation. Before parity we declared this specific evaluation order in [`encoder.h`](encoder.h): preserve original min/max and nearest-even initial codes **in FP32**, actual stored FP16 origin/step and frozen FP16 `U[128,8],D[128]` asset, FP64 `s`, `u2`, `us`, `diag`, `error`, `a=diag+u2`, `grad=diag*error+us`, and the update `s+=delta*U` in the donor order. Only the code selection becomes:

```
hb = a * step;
twog = 2.0 * grad;
T(j) = twog + hb * double(2*(j-current)+1);   // j=0..14
lo=0; hi=15;
while (lo<hi) {
    mid=(lo+hi)/2;
    if (T(mid)<0) lo=mid+1; else hi=mid;
}
if (lo<15 && odd(lo) && T(lo)==0) lo++;
next=lo;
```

The lower-bound binary search requires at most four ordered boundary comparisons, then one possible equality/tie check; exact-zero adjacent minima select the **even** code. `step==0` skips the coordinate and retains the original nibble. No precomputed curvature table, alternative precision/tiling, rank/bitwidth change, re-fit, or fallback. C++ FP64 expression contraction/rounding can change threshold signs near ties versus exact integer thresholds or the original FP64 quotient; host parity is an observed test on the saved finite panel, **not** an arbitrary-input floating equivalence theorem. The saved exact-integer subset proof does not certify compiled device rounding. If a future GPU launch changes a code, the donor quality cannot be inherited without new complete-output acceptance.

[`encoder.hip`](encoder.hip), [`encode_cpu.cpp`](encode_cpu.cpp), [`parity.py`](parity.py) and [`build.sh`](build.sh) retain the prior complete one-block-per-completed-32×128 BF16 key-chunk boundary. Lane `d<128` computes FP32 min/max and nearest 0…15 original KIVI codes, writes 4,096 codes +256 FP16 fields to **4,608 B LDS**, synchronizes once, then 32 token lanes independently assemble eight FP64 `s` components and run the same **128-coordinate serial Gauss–Seidel chain**; each packs 64 nibble bytes and all 128 lanes write the 512-B field tail. The original KIVI baseline kernel omits the metric sweep; all source BF16 key projection, K norm/RoPE, causal recent-buffer flush scheduling, actual FP16 D/U **2,304-B group-specific asset**, K/V reader, two-head softmax, V and complete 1,024-column O are unchanged. This study does not load/prepare an expanded K matrix. The metric lives **once per model group** and is shared across sequences; the per-sequence K/V cache remains 52,400 B peak and each K flush repeats the threshold sweep. No persistent extra threshold table or scratch buffer is introduced. The 8,192-B completed recent K slab is a common upstream input, not an added cache copy.

[`parity.py`](parity.py) loads the original source BF16 K chunks and both frozen chronological K-event donor logs, invokes the same source arithmetic as the HIP kernel through a standalone Clang21 host executable, and compares all **2,560 bytes per event**: 2,048 packed nibbles and 512 FP16 origin/step bytes. All eight training and four inspected-held receipts, complete encoded/donor SHA and any first mismatches are preserved in `PANEL-WINDOW-parity.json`; [`results.json`](results.json) requires all12. Both conventional and threshold arm have **zero differing field and code bytes**. The metric source image remains SHA256 `2d4837028c2e04fb61b3f554eb409b4ff450374634b54febabe451cd846cadc9`; original source capture/checkpoint and unchanged full causal quality are the owners' existing reports. This is not another held loss selection or source image.

## Emitted resource and execution ledger

[`assembly-gfx1151.s`](assembly-gfx1151.s), [`compile-receipt.txt`](compile-receipt.txt) and `results.json` preserve HIP7.2.3 Clang22 emitted labels, actual symbol body/64-B descriptor sizes, resources and static opcode counts. `aggregate.py` compares these directly with the frozen quotient kernel's assembly and receipt. The static counts include instruction **sites** in the complete bodies; they are not per-flush executed counts.

| Complete K flush | Body | VGPR/SGPR | LDS | Scratch | Static FP64 div/reciprocal sites | All static FP64 sites |
|---|---:|---:|---:|---:|---:|---:|
| Original scalar KIVI | 7,684 B | 36/9 | 4,608 B | 0 | 0 | 0 |
| Frozen metric quotient/rint | **9,164 B** | **62/12** | 4,608 B | 0 | **5** | 105 |
| Frozen metric ordered thresholds | **9,236 B** | **62/14** | 4,608 B | 0 | **0** | 96 |

Each metric flush still does the original 32×128 per-channel FP32 min/max and 4,096 initial FP32 divisions/rounds: **only the additional 4,096 FP64 coordinate-selection quotients disappear**. It still loads/reduces FP16 U/D and actual fields, prepares 8 rank components for 32 tokens, and performs 128 serial coordinate updates/token. The threshold decision computes `hb,twog` then **up to four FP64 multiplies/adds and ordered comparisons per coordinate** plus an equality check when `lo<15` and odd; its register/control dependence may outweigh saved division at `gfx1151`. The original metric producer's ~131,072 per-chunk rank-dot/update terms, 128-step dependency chain/token, one LDS barrier, 8 source chunks/window, repeated per-sequence flush and all original unchanged Q/K/V/O reader work remain. Fixed model storage is unchanged **2,304 B U/D**; `11604−11532=72 B` is compiled body growth only, not another per-matrix nibble payload or per-sequence copy. Any runtime prepared metric copy, lane register state or decoded CPU arrays would be additional to serialized cache; here emitted LDS/VGPR/scratch are recorded separately. No GPU job admission was taken because no device was launched; a later measured native endpoint would need its own authorized admission and complete producer+consumer boundary.

Reproduce with `./research/isa-quantization/kivi-threshold-native-flush/build.sh`; run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/kivi-threshold-native-flush/parity.py PANEL WINDOW` for train0…7/held0…3; then `aggregate.py`. Each individual command finishes under one minute. Generated binaries/input chunks are ignored; committed assembly/receipts remain. Parent owns catalogue/synthesis and exact finite-grid mathematics.
