# The remaining E8P table is a combinatorial byte program

The [residual-root program](../e8-root-program/README.md) removed the 4,096-byte E81B table while preserving the QuIP# map. The remaining main E8P magnitude table has additional structure: its 256 rows are **complete small-subset families plus only 29 exceptions**. Recode the main word's high byte to these families, keep its low sign/parity byte, and the 1,024-byte table becomes a 29-byte generic exception list plus a decoder program.

The actual full 128×1,024 image is now **49,327 bytes**, down from 50,322 for residual-root-only and 54,418 for the original standalone RVQ image. All **65,536 main codewords**, all **524,288 main standard-basis dot identities**, and the full decoded weight matrix agree exactly with the old reader. The separately invoked image replay gives unchanged train/held raw-Q error **.0038422293/.0131097901**. No coefficient was fitted or approximated.

This is **not a speed claim or repeated per-matrix BPW gain**. The saved table is generic and paid once per reader pool. The combinatorial decoder has real instruction cost; alternatively preparing a lookup restores 1,024 bytes of runtime state. The [compile-only complete-reader screen](../quip-combinatorial-native/README.md) now prices two realizations: direct decoding adds 649 bytes of resident data plus device code; preparing a new-label table adds 9 bytes before its host preparation code. Neither straightforward lowering earns the static pool-scale saving, and neither was run on GPU.

## The source alphabet

Let v_i be a source packed nibble minus8, in original packed-slot order i=0..7. Every magnitude is1,3 or5. All signs are positive except slot7, which is negated exactly when the number of threes is odd. This makes `sum v_i` divisible by4. The absolute patterns are:

| Family | Count |
| --- | ---: |
| k-of-8 threes, all other magnitudes1, for k=0,1,2,3,4 | 1+8+28+56+70 = **163** |
| One5, no3 | **8** |
| One5 and one3 at a distinct coordinate | **56** |
| A selected five-of-eight three-mask, all other magnitudes1 | **29** |
| Total | **256** |

The 29 selected masks are not treated as a free combinatorial family. Their **actual bytes** remain in the image, sorted numerically. They have five set bits, are distinct, and are pinned by the image hash. The generic exception list is independent of model weights; another matrix sharing the codebook pays it once, not again.

## An executable high byte

For new high byte c:

* `0<=c<163`: determine k from offsets `(0,1,9,37,93,163)` and interpret `c-offset[k]` as the colex combinatorial rank of a k-subset of eight positions. Set those magnitudes to3, the rest1.
* `163<=c<192`: read one of the 29 five-three masks. No full magnitude vector is stored.
* `192<=c<256`: let `i=c&7`, `j=(c>>3)&7`. Put5 at i; put3 at j if j differs from i, otherwise no3. The remaining magnitudes are1.
* Negate slot7 iff the three-mask has odd cardinality.

The combinadic decoder scans eight possible bit positions using small binomial counts; this is a familiar subset coordinate system, not a new unranking algorithm. Its binomial operations/constants and branches are **reader code**, not nonexistent work. A native implementation need not use Python's `math.comb`, but must realize an equivalent program and count any retained constant table.

[`build.py`](build.py) recovers the source alphabet from the old image, constructs every new magnitude byte, proves the finite bijection against all256 original rows, and rewrites only the high bytes of 16,384 main words. The original source is pinned by SHA256 `d39500d3a5fbfd3260f4139d064ab00654582e15e4fc461fc923502d841f907a`. Root indices, input/output signs and global FP16 scale are copied unchanged. Its [receipt](image.json) records the bijection, full codeword comparison, dot checks and position counts: 12,785 ordinary subset cells, 687 exceptional cells and 2,912 one-five cells in this image.

## Whole-dot interpretation, not compulsory coefficient recovery

For an original low byte s, let p be its bit parity and let e be `s xor p` (only bit0 flips when p=1). Thus e has even parity. In packed-slot coordinates define `sigma_i=(-1)^bit_i(e)`, `tau=(-1)^p`, three/five masks t_i,f_i, and `m_i=1+2t_i+4f_i`. Let o be the parity of the three-mask. The original coefficient is

```
a_i = sigma_i * m_i * (-1)^(o*[i=7])/2 + tau/4.
```

For live input z in packed-slot order its complete dot is therefore

```
a dot z = (1/2) sum_i sigma_i z_i
          + sum_(i in three-mask) sigma_i z_i
          + 2 sum_(i in five-mask) sigma_i z_i
          - o * m_7 * sigma_7 * z_7
          + (tau/4) sum_i z_i.
```

The slot7 correction is indispensable: merely adding selected3/5 terms to an even-sign base gives the wrong parity family. The first term is an even-sign half-root dot, potentially sharing a live signed-sum representation with the residual-root continuation. The last plain input sum can be shared across output codes at that input block. Neither reuse is free until its lane placement, communication and lifetime are realized. Output-slot order is the original fixed permutation `[0,4,1,5,2,6,3,7]`; the independent direct-dot routine permutes inputs inversely rather than change the target map.

[`replay.py`](replay.py)'s `dot_four` computes four times this expression using selected coordinates and integer arithmetic. Its standard-basis results are compared to **independently decoded old packed-table coefficients**, not only to its own coefficient helper. Both maps are linear in arbitrary z. The new Lean foundation `Kelana/E8MainProgram.lean` proves the finite whole-dot algebra and required parity correction; source-table correspondence, combinadic bijection and the actual image remain the separate exhaustive evidence. No emitted floating-point kernel identity follows from rational linearity alone.

## Actual image and complete behavior

[`quip-combinatorial-standalone.bin`](quip-combinatorial-standalone.bin) has SHA256 **`6b2f5c60ed0ef30139a824263711264550b4f2ec03a8abe2b2835f47ba782e8d`**:

| Field | Bytes |
| --- | ---: |
| 16,384 two-byte main codes | 32,768 |
| 16,384 one-byte residual-root codes | 16,384 |
| Packed input/output sign vectors | 144 |
| Global FP16 scale | 2 |
| Shared exceptional subset masks | 29 |
| **Total** | **49,327** |

The **model-specific payload remains 49,298 bytes**; only generic representation changes. The current slab's data-only effective rate is **3.01068115234375 BPW**. Relative to original RVQ, 5,091 generic data bytes disappear once per reader pool; the new step accounts for995 of that. This is not a5,091-byte saving at every model matrix, and it is not necessarily a code-inclusive saving.

Independent image-only replay reconstructs the same full weight array bit-for-bit in FP64 as the accepted root-only reader, so the prior **dense-decoded CPU** complete-head behavior is unchanged as well: root-H held attention KL .02416825 and post-O .02784225 under that numerical contract. Those are still worse than the **larger** 50,320-byte scalar image's .01821224/.02185195, at a different rate. The frozen QTIP3INST image has 49,298 data bytes,29 fewer than this image, and held KL .04472285; its code/work is also a different axis. Neither comparison licenses a whole-model/native superiority claim. A newly lowered direct-dot kernel may round differently and must be checked separately.

### Two legitimate realization routes

1. **Direct program:** read29 exception bytes, unrank ordinary subset codes, evaluate the whole base/root dot. This minimizes generic resident data but adds control, combinatorial work and possibly instruction bytes beyond the995-byte table saving.
2. **Prepared lookup:** reconstruct the256×32-bit main magnitude table once in the *new byte order*, retaining1,024 runtime bytes, then use an ordinary table reader. Model distribution/storage shrinks but prepared RAM does not. The preparation program and time also count. The residual-root can similarly retain its direct reader or generate a residual lookup, with distinct costs.

The earlier native wave experiment lost to direct root even before this change. The new [compile/resource comparison](../quip-combinatorial-native/README.md) finds direct main decoding adds 1,644 device-body bytes to save 995 generic bytes; the prepared variant restores a 1,024-byte resident table and adds 962 bytes of host preparation/release code. All complete readers retain the same transforms and residual path. This ends these two implementations before GPU timing, while preserving the exact smaller serialized representation. A materially different approximation/program family, rather than more tuning of this exact unranking loop, is the next question.

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/e8-main-program/build.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/e8-main-program/replay.py
```

Each call completes under a minute. The source matrices, original captures and all previous successful images remain with their existing owners. No training, additional compute or inference deployment was introduced.
