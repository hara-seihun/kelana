# One dot for the whole 2×2 ternary map

The exact map `D = AB + C` for ternary 2×2 matrices has a **one-instruction online core** when its consumer accepts a radix-64 column code. The previous two-instruction core returns two radix-7 column codes in separate bytes. This construction changes that output label; it does not beat the old core at its fixed byte-pair endpoint. No GPU timing or inference speedup follows from the opcode count alone.

Let the entries of output column `j` be `d0j,d1j ∈ [-3,3]`. Encode the column as `pj = (d1j+3) + 7*(d0j+3)`, so `0 ≤ pj ≤ 48`. Return `P = p0 + 64*p1`. Decoding uses `p0 = P & 63`, `p1 = P >> 6`, then `d0j = pj//7-3`, `d1j = pj%7-3`. `P ≤ 3120`, with no column overlap. This uses the normal orientation for every weight matrix; no sign metadata is needed.

Prepare four signed byte coefficients from the reusable matrix A:

```
k = (a10 + 7*a00, a11 + 7*a01, 7, 1)    # each in [-8,8]
bias = 24 - sum(k)                          # in [0,48]
```

The runtime input has eight two-bit trit codes `u=t+1`, ordered as in [the original experiment](../README.md). Its A-independent wire puts two codes in each unsigned byte lane: column 0 at bits 0–1, column 1 at bits 6–7. Thus `lane_i = u_i0 + 64*u_i1 ≤ 130`. A single `V_DOT4_I32_IU8(k, lanes, 65*bias)` returns `P`. The factor 64 is in the *input coordinate*, not in the weight or another multiply: the second column's bit positions are copied into the upper two bits of each lane. No addition or carry belongs to the free wire operation.

[`Kelana/Toy2Radix64.lean`](../../../Kelana/Toy2Radix64.lean) proves the integer endpoint, signed-byte and unsigned-byte legality, radix decoding, and dependence on prepared A. [`check.py`](check.py) replays exact signed-byte/unsigned-byte dot semantics on all 531,441 ternary triples and compares the decoded result with the independent ordinary matrix computation and the prior byte-pair code. It observes 2,089 reachable codes and a maximum of 3,120. [`online.s`](online.s) assembles to exactly one 8-byte `v_dot4_i32_iu8` on gfx1151, followed by `s_endpgm`; its SHA-256 is `ce42f79df81eafb99497f1dc2a498f4aa86981f3e2870b27fb951de90febbd99`. Those facts are opcode legality and semantic proof, not a cycle measurement.

The zero-instruction competitor cannot work in the declared interface: output wiring is independent of A, but fixed B and C produce distinct outputs for `A=0` and `A=I`. Thus **one is optimal for the family of online arithmetic cores with free A-independent input bit wiring, A-prepared constants and the specified radix-64 output**. This lower bound does not cover a precomputed answer for fixed dynamic B/C, a more capable free packing operation, or a consumer with a different endpoint.

## Boundary cost and next experiment

The radix-64 code is not the previous byte-pair code. With both in normal orientation, byte-pair output is `P + 192*(P >> 6)`, which adds a shift and a multiply-add after the dot. Some old matrices use flipped sign orientations, so converting to their exact selected byte-pair word also needs orientation work. Conversely, a consumer that accepts two six-bit fields can keep `P` and avoid conversion. Output is still held in a 32-bit register; 12 instead of 16 occupied bits is not a storage claim by itself.

The regular input wire is not free on hardware either. It spreads four low-column codes into bits 0–1 of consecutive bytes and four high-column codes into bits 6–7. The prior core uses *two* input wire registers, but its six-instruction expansion already has an implemented native schedule. Price this new wire schedule and a downstream consumer that stays in radix-64 labels together. If producer packing plus consumer conversion costs two more instructions than the old two-dot core, the one-dot result remains a structural identity and loses as a native program.

Reproduce from the Kelana root:

```
lake build Kelana.Toy2Radix64
python3 research/toy2/radix64/check.py
llvm-mc -triple=amdgcn-amd-amdhsa -mcpu=gfx1151 -filetype=obj research/toy2/radix64/online.s -o /tmp/toy2-radix64.o
llvm-objdump --disassemble --mcpu=gfx1151 /tmp/toy2-radix64.o
```
