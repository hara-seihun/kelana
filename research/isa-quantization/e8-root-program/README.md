# Replace a residual table with a byte-labelled root program

The [packed-dot study](../quip-packed-dot/README.md) exposed the integer geometry of the fixed E81B residual table. The parent followed that geometry rather than retaining the source index labels: **the entire residual codebook is exactly representable by a one-byte executable root label, with no residual table**. Re-encoding the existing image preserves its decoded full 128×1024 weight map bit for bit in the independent float64 readers. Its standalone data falls from **54,418 to 50,322 bytes**—all 4,096 residual-table bytes removed, not amortized to hypothetical consumers.

The 16,384 residual indices remain one byte each. The main E8P indices, signs, FP16 scale and **1,024-byte main absolute table** are unchanged and still paid. The resulting rate is **3.071411 BPW** over 131,072 original coefficients. Train/held response errors remain **.003842229/.013109790**. This is an exact representation/reader change to the named QuIP# control, not a new quantizer fit or a whole-model accuracy win.

The saving is **once per reader pool**, not per matrix: model-specific indices/signs/scales occupy exactly the same bytes before and after recoding, while shared generic table data changes from 5,120 to 1,024 bytes. The BPW reduction is `32768 / total_original_coefficients` over the entire collection (0.25 BPW for this one slab); it is not a repeated full-model compression gain.

The subsequent [complete native comparison](../quip-full-native-root/README.md) measures a tradeoff: root 31.120 µs versus old table 22.440 µs and this scalar about 62.1 µs at batches 1/8. The hot table wins execution despite its larger data. Root code is 312 bytes larger, so measured data-plus-code savings versus the old reader are 3,784 bytes, paid once per pool. Data-image size and single-arm image-plus-code footprint are reported separately.

## The full alphabet, not a sampled coincidence

Read every vector g from the pinned upstream E81B FP16 table. Its 256 vectors are:

* 112 integer roots `±e_i ±e_j`, i<j;
* 128 half roots `(±1/2,…,±1/2)` with an even number of minus signs;
* 15 signed axes `±2e_i`, omitting `−2e_7`;
* the zero vector replacing that omitted axis.

These are the usual E8 root geometry plus the stated axial/zero extension; no novelty of the lattice is claimed. [`build.py`](build.py) checks this entire set exactly using `2g` integer coordinates, verifies that the new labels give 256 distinct vectors, and constructs the bijection from the source byte indices. The index conversion is quantization/preparation work. It is not retained in the inference image or a hidden generic runtime dictionary.

## An eight-bit executable coordinate system

For a new byte c<128, let

```
i = c & 7,       j = (c >> 3) & 7,
s = 1 - 2*((c >> 6) & 1).
```

If c=127, output zero. Otherwise

```
g(c) = s(e_i+e_j)  when i<=j,
g(c) = s(e_i-e_j)  when i>j.
```

The ordered pair distinguishes same-sign from opposite-sign roots. Equal indices give the axes; c=127 is the deliberately omitted negative seventh axis and instead encodes zero. Thus all 128 lower-half bytes are useful without a separate selector field.

For c>=128, use the lower seven bits as seven signs; the eighth sign is their parity. Let `s_k=(-1)^bit_k(c)` for k<7 and `s_7=(-1)^popcount(c&127)`. Then

```
g(c) = (s_0,…,s_7)/2.
```

This gives all 128 even-parity half roots exactly once. The high bit selects the two code families and is part of the existing residual byte, not extra model metadata.

## Evaluate the whole residual dot

For any real dynamic vector z, the low-half branch returns

```
s*(z_i+z_j)  or  s*(z_i-z_j),
```

with zero special-cased. The high-half branch returns `sum_k s_k*z_k / 2`. There is no reason to first reconstruct eight residual scalar weights or load eight FP16 table entries. The original residual scale `1/2.04`, global image scale, main E8P contribution, signed input Hadamard and output Hadamard/signs remain necessary.

The low-half reader needs two indexed activation accesses, comparison/sign logic and one addition/subtraction; the high-half reader needs the eight activation contributions with sign/parity logic and a half scale. That is an operation-level construction, **not** an instruction count or a speed claim: lane placement, indexed loads, divergence between the two branches, reductions and register pressure determine the native result. On this full-row image the positions split into **8,798 half roots, 7,533 nonzero integer/axis roots and 53 zero codes**. Their spatial arrangement matters as well as their count. The main E8P reader is not removed.

Unlike the prior integer-dot proposal, this residual-only program accepts the existing floating-point post-Hadamard input directly. It introduces no activation quantization or per-block input scale. It therefore avoids that proposal's additional response loss and input packing, while making no assertion about which complete kernel is faster.

## Stored evidence and controls

[`quip-root-standalone.bin`](quip-root-standalone.bin) is the actual 50,322-byte image, SHA256 `d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a`. Its independent reader parses no residual table. The builder checks all 256 code vectors, all eight standard-basis dot inputs for each code, and equality of the complete decoded old/new weight matrices. Because both dot expressions are real-linear in z, those basis checks cover arbitrary real inputs algebraically, not merely a finite input sample. [`Kelana/E8RootProgram.lean`](../../../Kelana/E8RootProgram.lean) proves the arbitrary-rational-input direct-dot identity for every `Fin 256` byte, including equal indices, zero code 127, and the parity half-root branch, through actual finite-sum algebra. Source-table equality is the exhaustive integer check, not a claimed Lean import of the binary file.

The new [50,320-byte scalar control](../quip-root-matched-scalar/README.md) is independently decoded, with 833 Q3 and 191 Q2 groups, the same paid field/mask accounting, train-only whole-input response-sensitive allocation, and joint FP16 field refit. It scores **.012346793 train / .014627799 held**, against the root image's **.003842229 / .013109790** at 50,322 bytes. Thus the exact root representation has about **10.4% lower held error** at two additional bytes in this bounded local comparison. The earlier 54,416-byte scalar still has lower error .010423200 at its *larger* rate; that ranking does not apply at the new byte boundary. Neither scalar fit nor this named-method adaptation is asserted globally optimal. The subsequent [complete-head observer](../quip-complete-head-observer/README.md) reverses the held quality ranking after Q RMSNorm and causal attention: root-H KL .02416825 versus scalar-H .01821224, post-O .02784225 versus .02185195. The lower raw-Q error is therefore not a complete-attention quality win; the exact representation and measured data/code/work tradeoff remain valid.

The next exact [live signed-sum encoding](WAVE.md) prepares 26 input-dependent coordinates so a root dot selects at most three values. All byte/basis identities are checked before native realization; lane preparation and shuffles are paid, not assumed free.

The exact real-number map does not guarantee identical FP32 native rounding when residual sums are rearranged. That boundary must be checked if a native reader is adopted. Generic machine code is a separate deployment asset for both readers; this report measures the eliminated table data and the complete model-specific image, not compiled code footprint.

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/e8-root-program/build.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/e8-root-program/replay.py
```

Both commands take seconds, use the unchanged pinned source image/fixture, and require no GPU or new source capture. [`image.json`](image.json) records the bijection and physical accounting; [`results.json`](results.json) records independently decoded complete train/held response.
