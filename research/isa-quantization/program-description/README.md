# A paid program description for small ternary maps

A compressed weight image can be a program's operands rather than a list of approximate weights. Here the operands are a four-trit template and four two-bit rotation selectors. The reader applies the selected template directly to the input; it never reconstructs a 4-by-4 matrix. Charging the reader's compiled code still leaves a small exact capacity win over a densely packed scalar-plus-scale control. This is a constructed reuse family, not evidence that trained matrices have this structure or that its CPU reader runs faster.

## Endpoint and image

There are 64 independent 4-by-4 integer maps. Each map has a positive integer scale `s` in `1..7`. For each output row `r`, an independently selected rotation `k_r` determines

```
y[r] = s * sum(c=0..3) template[(c+k_r) mod 4] * x[c].
```

The template has four trits in `{-1,0,1}`. For this witness all four row rotations occur once per tile, in a randomly selected order. The 64 templates and orders come from Python seed 240924. Inputs are signed 16-bit integers, outputs signed 32-bit integers; the replay uses inputs in `[-3,3]`. For arbitrary signed-16-bit inputs, the absolute output is at most `7*4*32768 = 917504`, so both readers have identical exact integer endpoints without overflow. The 64 inputs and outputs are independent, not overlapping convolution windows.

Two physical images encode the *same* matrices and scales:

| Reader | Per-tile image | Bytes for 64 tiles | x86-64 reader `.text` | Image plus code |
| --- | --- | ---: | ---: | ---: |
| Independent scalar trits | A little-endian base-3 index for 16 trits in four bytes, one scale byte | 320 | 161 | 481 |
| Shared-template program | A base-3 index for four trits in one byte, four rotation selectors in one byte, one scale byte | 192 | 193 | 385 |

`experiment.py` compiles both generic C readers with `clang -Os -fno-inline -fno-unroll-loops` and reads their symbol sizes from the relocatable object with `nm -S`. Both readers receive the same tile count, input/output layout and no pre-expanded weights. It runs both on a separately generated input and checks 256 outputs against ordinary matrix multiplication. The compiled reader functions are charged once per image; neither image needs a model-specific compiled function, side table or uncharged instruction immediate. The 32 additional bytes of program-reader code are paid. The scale is one byte in *both* images, not a free multiplier in one arm. At 64 tiles this gives 96 fewer static bytes, or 3.008 versus 3.758 static bits per original weight when code is included. Within these two fixed physical formats the strict break-even is 17 tiles: `2*n > 32`.

The scalar format is already stronger than ordinary two-bit/trit storage, which would use four bytes here too but could not make a smaller tile. A still stronger *optimistic* scalar control packs all 1024 independent ternary digits across tile boundaries into `ceil(1024 log2(3)/8) = 203` bytes. Give it the same 161-byte reader code for free despite the changed addressing. Keeping its 64 scale bytes yields 428 bytes, still above the program's 385. Even crediting it an ideal 23-byte joint encoding of 64 seven-way scales yields 387 bytes. That last two-byte margin is a capacity comparison with a gifted decoder, not a physical reader measurement. A general compressor that detects and codes the same rotation structure is no longer an independent-scalar codec; it may match or improve the program. A more efficient encoding of the program's permutation selectors could improve it too.

The source is intentionally structured. For a uniformly random 4-by-4 ternary matrix, at most `81*24/3^16 < 0.000046` of possibilities have four rows that are distinct rotations of a common template. No exact gain on unstructured matrices follows. A scalar-plus-scale conversion that fits arbitrary real teachers should optimize its scale and codes under the same observed loss, rather than use naive rounding. This witness compares *exact images* and thus has zero error in both arms; fitting offers neither arm a distortion advantage.

## The accounting rule

Let `I` be the serialized model bytes, `C` the installed reader code bytes, `T` model-specific tables and constants outside `I`, and `W` resident preparation or scratch. Compare `(distortion, I+C+T, W, online work)` at one declared endpoint. If a codebook is stored in `I`, do not also charge it in `T`, but do not omit it either. A literal immediate in specialized machine code belongs in `C`. A selector or immediate loaded from the model belongs in `I`. Installed ISA instructions are fixed hardware, but an instruction *sequence*, its dispatch and its prepared operands are not free. A reusable code path costs `C` once across its actual users; charging it per tile is just as misleading as charging it nowhere. Address directories, alignment, exceptional paths and code duplication at call sites belong in the same ledger.

For a family of templates `S`, a useful joint search minimizes something like

```
loss(F, decoded execution) + lambda*(reader_code(S) + tables(S)
    + sum tile_description_bytes) + mu*online_cost(S, routing, layout),
```

subject to the input/output contract and available machine states. `reader_code(S)` is a *union* charge, not a sum of per-tile code costs. Adding a specialization is worthwhile only when the bytes and execution it saves on all its actual users exceed its code, dispatch and table costs. Exact byte packing gives a discontinuous objective: ceil each physical stream at its real restart boundary, not after summing fractional per-tile entropies. A search state can retain its selected templates, assignments, code-path set and shared metadata alongside the consumer response. Two equal output responses cannot be deduplicated if they leave different code-path sets or future legal continuations. This is the joint-description analogue of paid consumer-state search, not a claim of a solved global search algorithm.

The one-byte selector is an executable coordinate. It describes which four trit rotations to apply, rather than an entropy-coded symbol requiring a separate expansion into 16 trits. But it still executes four four-term dot products and adds template extraction and indexed reads. The 96-byte saving is **static capacity**, not reduced memory traffic or latency. On a small image the template reader loses code bytes until enough tiles share it. Runtime, caches, instruction issue, layout, distribution of real weights and complete-model quality are open.

## Relation to current work and replay

[Additive programs](../../quantization-discovery/representations/additive-programs/README.md) already showed a model-specific template/residual image that wins on planted correlated rows and loses on real Qwen rows. [Coupled codebooks](../../ternary-toys/coupled-codebooks/README.md) and [MoE code sharing](../../moe/code-sharing/README.md) supply further warnings about assuming motif prevalence. This experiment's distinct point is the *compiled generic reader plus model description* ledger and an exact break-even against an independently encoded scalar control. The [quantization search notes](../../quantization-discovery/MATHEMATICS.md) already allow arbitrary paid block-code menus, but their fixed menu charge does not by itself pay the union of installed program variants selected across blocks. The [radix-64 toy](../../toy2/radix64/README.md) gives a one-dot structural identity whose input wire and consumer still need pricing; here byte accounting is explicit, but native speed is not established.

From the Kelana root:

```
python3 research/isa-quantization/program-description/experiment.py
```

The script prints byte counts and checks all 256 integer outputs for its seeded input. `readers.c` is the complete executable reader source. The mathematical exactness follows from the serialization formula and index identity above, not from one random-input check. Recompile when changing compiler or target, since code bytes are target-specific. The example has no full-model loss result and should not displace a trained scalar conversion.
