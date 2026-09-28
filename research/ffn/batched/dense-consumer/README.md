# Dense five-trit bytes as a direct operand coordinate

This construction consumes dense five-trit labels directly into IU4 operand bytes. A second construction stores two-trit selector codes in nibbles. Both reproduce `arith-iu4-a4`'s output bits on the tested rows. They still use that candidate's approximate A4 quantizer, not the deployed A8 quantizer.

The dense construction wins at 32 rows. At 128 and 256, the wide-load two-bit control is faster. The control is useful in its own right: it improves the arithmetic A4 baseline by 1.26–1.73x in the initial layer-0 run, without changing its outputs.

## The construction

A HALO label is `b = ceil(256*q/243)` for

```
q = 81*t0 + 27*t1 + 9*t2 + 3*t3 + t4,   t_i in {0,1,2}.
```

Read q as `27*A + 3*B + c`, where A and B are nine-valued two-trit codes and c is the remaining trit. Their selectors come directly from the stored label:

```
m = 9*b;       A = m >> 8;    r = m & 255
m = 9*r;       B = m >> 8;    r = m & 255
m = 3*r;       c = m >> 8
```

`A` and `B` become `v_perm_b32` selector bytes. The permutation produces pairs of int4 operand nibbles without first reconstructing either trit as a separate value. The remaining c values are paired to make later operands. This path does form c as an individual trit label; it does not reconstruct all five scalar weights.

Packed 16-bit multiplication evaluates two source bytes together. The written peel contains three multiplies, three shifts and two masks per pair. This is a construction, not a proved minimum instruction count.

The code alphabet is `mu(0)=-1, mu(1)=+1, mu(2)=0`. Selectors 0..7 name eight source bytes, and selector 8 supplies the ninth outcome by sign replication. Code 1 is the weight pair `(-1,+1)`, stored as byte `0x1F`, and code 8 is `(0,0)`, which needs `0x00`. The native selector-8 probe confirms this table on gfx1151. The extended probe now covers all 256 selector values against twelve source vectors, including eight independent byte-sign probes. `results/perm-semantics.json` records the raw outputs, source and binary hashes, device and compiler versions.

With source bytes 0..3 in argB and 4..7 in argA, selectors 0..7 copy the corresponding byte. Selectors 8..11 replicate the sign of source byte `2*(selector-8)+1`. Selector 12 returns zero; 13..255 return `0xff`.

Ten corresponding literal-operand and runtime-operand cases agree. `results/perm-folding.s` contains no permutation instruction in the folded kernel and one in the runtime kernel. The initial report's compiler-discrepancy claim was wrong: it confused operand order. No compiler discrepancy was observed. `extract_kernels.py` regenerates the assembly evidence.

### Layout

The chosen layout distributes five-trit groups across K16 slices and reads each block in wide pieces. Per 16-row tile and 128-block:

| section | offset | bytes per lane |
|---|---:|---:|
| S0 | 0 | 16, one `uint4` |
| S1 | 256 | 8, one `uint2` |
| S2 | 384 | 2, one `ushort` |

Twenty-four bytes hold five trits each; two hold four each. The 128 weights occupy 26 code bytes, or 1.625 code bits per weight. Adding the two-byte block scale gives 1.750 bits per weight, the same total as the deployed HALO block. The two-bit control uses 32 code bytes plus that scale, or 2.125 total bits per weight. Tables below quote code bits only.

Each of the first six dwords supplies a K16 slice through its A and B codes. Its c labels contribute to slices 6 and 7. `check.hip` checks all 243 reachable triples on the host and the complete packing/operand path on 655,360 random weights on the GPU.

The nibble-code control stores the same nine-valued pair code in four bits. `dc-paircode-a4` keeps the arithmetic kernel's per-slice load layout. `dc-paircode-wide-a4` gives each lane 32 contiguous bytes for its block, loaded through two `uint4`s. This separates changing the code alphabet from changing the load layout and scheduling.

## What the small bounds actually exclude

For the radix integer q, before HALO's relabeling to b, ordinary linear accumulation obeys

```
sum_k q_k*v_k = 81*S0 + 27*S1 + 9*S2 + 3*S3 + S4.
```

Independent signed digits in `[-1,1]` separate in radix 3. Allowing all digits in `[-2,2]` creates collisions, for example `3*0+2 = 3*1-1`. Thus this fixed-radix construction cannot independently recover arbitrary larger channel sums. This argument does not apply unchanged to multiplying the stored b, does not require a downstream consumer to recover every channel, and does not rule out other labelings or compositions.

An independently bit-aligned two-trit code needs at least four bits because it has nine states. That proves a two-bit-per-weight floor for that specific field layout. It proves no multiply requirement below two bits per weight. Lookups, Boolean maps, overlapping fields, reachable-domain restrictions and whole-consumer representations remain outside it. The current peel has not been proved optimal.

## Measurements

Initial runs use gfx1151, real rows at layers 0 and 10, 24 calls per candidate in 12 randomized rounds after a two-second workload ramp. The ramp is outside the reported samples. The resident server is outside the research lock. All raw samples and telemetry are in `results/place-layer0.json`, `results/layer0.json` and `results/layer10.json`.

Layer-0 medians in milliseconds:

| candidate | code bpw | 32 | 128 | 256 |
|---|---:|---:|---:|---:|
| `dc-dense5-a4` | 1.625 | 0.503 | 1.741 | 3.369 |
| `dc-paircode-wide-a4` | 2.000 | 0.566 | 1.246 | 2.551 |
| `dc-paircode-a4` | 2.000 | 0.921 | 1.602 | 3.009 |
| `arith-iu4-a4` | 2.000 | 0.980 | 1.701 | 3.223 |

These four have identical output hashes at all three sizes. Layer 10 repeats the pattern: dense5 takes 0.502 / 1.844 / 3.428 ms and paircode-wide 0.568 / 1.311 / 2.614 against arithmetic IU4 at 0.977 / 1.776 / 3.292.

Other numerical maps were present in the layer-0 comparison:

| candidate | 32 | 128 | 256 |
|---|---:|---:|---:|
| `arith-paired-a4` | 0.894 | 1.541 | 3.207 |
| `gs-control-iu4-a4` | 0.935 | 1.581 | 3.082 |
| `hc-rowpair-a4-tt8-down1-rne` | 0.944 | 1.528 | 2.803 |
| `cs-scaled-f16-a8` | 1.072 | 2.246 | 4.062 |
| `arith-iu8-a8` | 1.085 | 2.243 | 4.457 |

This second table is context, not an assertion of equal outputs or model quality. In particular the A8 and half-carrier maps are different numerical objects.

The integration run in [scale-carrier/results/wide-layer0.json](../scale-carrier/results/wide-layer0.json) repeats the result with the header-aware source fingerprint and 40 calls over ten rounds. Dense5 is 1.903x arithmetic A4 at 32 rows, 95% interval [1.895,1.912]. Paircode-wide is 1.356x at 128 and 1.257x at 256, intervals [1.343,1.368] and [1.246,1.267]. All win ten of ten rounds and retain the A4 output hash. The analysis is `results/integrated-layer0-paired.json`.

Integration also repairs row tails by selecting a tile width dividing the padded token axis. `results/tails-layer0.json` records matching outputs among all three candidates at 88 and 200 rows. It is a correctness run, not the source of throughput claims. The measured 32/128/256 dispatches are unchanged.

### Separating the changes

On layer 0, nibble codes with the original load layout improve the arithmetic baseline by about 1.06–1.07x. Moving those same codes to wide loads improves that matched control by about 1.63x / 1.29x / 1.18x at 32 / 128 / 256. The combined gains against arithmetic are 1.73x / 1.37x / 1.26x. Calling the entire combined gain a load-shape effect would mix two changes.

Dense5 improves the wide-code control by 1.13x at 32 rows and loses above, at speed ratios 0.72x and 0.76x. It changes both storage and operand construction, so this pair does not isolate a pure bandwidth effect.

`count_instructions.py` counts the compiled TT4 fused kernels:

| weight path | IU4 WMMA | VALU | permutations | packed integer ops | VALU per WMMA |
|---|---:|---:|---:|---:|---:|
| dense5 | 64 | 1234 | 76 | 152 | 19.28 |
| paircode wide | 64 | 901 | 32 | 0 | 14.08 |

The difference is 5.2 VALU per WMMA in these compiled bodies. It does not predict a 32% runtime penalty by dividing by a WMMA issue interval. That would omit the control's own VALU work, dependencies, overlap, loads and residency. No traffic counter or isolated instruction-capacity experiment here proves what bottleneck causes the crossover. Fewer code bytes help one batch size while the extra operand work accompanies losses at larger sizes.

## Open directions

- Batches below 32 and mixed storage across the two projections remain unmeasured.
- A batch-size switch is a valid candidate under the common API. Any extra weight image must be counted in resident bytes; all input-dependent selection belongs inside `run`. No switched candidate was built here. Holding both code images would add the full second image, not merely their size difference.
- The A/B/c selector construction may feed other consumers. A scaled IU8 byte needs one value per output byte rather than two nibbles, so it needs its own lane-placement and table construction, not an assumed free table swap.
- Prefix values give the algebraic identity `sum_i t_i*a_i = sum_i P_i*(a_i-3*a_(i+1))`, with final `a_(i+1)=0`. Here `P_i=floor(b*3^(i+1)/256)`. Prefixes reach 242 and transformed A4 activations can reach 28. Mixed unsigned/signed IU8 can represent those ranges. Its slower matrix issue rate is a cost to price, not a proof that the complete map loses. This variant was not built.

No packing family or whole FFN optimum is proved here. The positive results are the actual operand maps and measured equal-output candidates.

## Reproduce

```sh
cd research/ffn/batched/dense-consumer
mkdir -p build results
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -I. -I.. -I/path/to/workspace/projects/bonsai-halo/src \
      -Wno-unused-value check.hip -o build/check
../hardware-run ./build/check

cd ../bench && make
../hardware-run ./build/batch-bench \
    --dataset /path/to/workspace/data/kelana-ffn/ptq1_0-batch/bench/layer00 \
    --rows 32,128,256 --iters 24 --warmup 4 --ramp-ms 2000 --rounds 12 \
    --candidate dc-dense5-a4,dc-paircode-wide-a4,dc-paircode-a4,arith-iu4-a4 \
    --reference-candidate arith-iu4-a4 --json ../dense-consumer/results/layer0.json

cd ../dense-consumer
hipcc --offload-arch=gfx1151 -O3 -std=c++17 -I. -I.. -I/path/to/workspace/projects/bonsai-halo/src \
      --cuda-device-only -S candidates/dense_maps.hip -o build/dense_maps.s
python3 count_instructions.py build/dense_maps.s results/instruction-counts.json
```

All GPU work uses `hardware-run`. Build products are disposable. Kelana owns the sources and recorded results.
