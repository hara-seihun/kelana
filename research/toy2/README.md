# Exact 2×2 ternary matrix MAC

The [self-contained proof handoff](PROOF.md) gives the complete derivation and a worked example for another agent.

The map is `D = AB + C`, with all twelve input entries in `{-1,0,1}`. Output entries lie in `[-3,3]`. This experiment compares two implementations of the same pure map with the same packed input and output contracts. It does not require either implementation to construct an unpacked D matrix.

## Result

The elementwise int4 baseline uses **13 vector instructions**. The packed construction uses **9**. It removes two `V_DOT8_I32_IU4` and two `V_MAD_U32_U24`, without adding an instruction of another kind.

| Instruction | Baseline | Packed |
| --- | ---: | ---: |
| `V_LSHL_OR_B32` | 4 | 4 |
| `V_AND_B32` | 3 | 3 |
| `V_DOT8_I32_IU4` | 4 | 2 |
| `V_MAD_U32_U24` | 2 | 0 |

Let S, A, D and M be their nonnegative unit-cycle charges in the chosen resource model. The two bills are

```
baseline = 4S + 3A + 4D + 2M
packed   = 4S + 3A + 2D
saving   = 2D + 2M.
```

The saving is strict whenever a dot instruction has positive charge. We do not assume different opcodes cost the same, and 13 versus 9 is not a measured cycle ratio. This is a componentwise improvement over the specified baseline, not a global minimum over all GPU programs.

The construction still expands input trit codes into native nibble operands. Its first improvement is in the arithmetic: one instruction computes two logical outputs in an encoded form, without materializing the individual int32 results.

## Input, output and reusable preparation

A is an arbitrary ternary matrix supplied to a load transformation. Its representation and coefficients may be prepared once and reused indefinitely. B and C change on each invocation. No weight value is hardcoded into the correctness theorem.

Encode a trit t as the two-bit code `u=t+1`. The dynamic input is one 16-bit word, in this order from least significant to most significant field:

```
b00, b10, c00, c10, b01, b11, c01, c11.
```

Thus each byte describes one B/C column. Bits above bit 15 are zero. Both programs use the same six-instruction bit expansion to place these eight codes into unsigned int4 lanes. The baseline already folds C into dot-product lanes and its offsets into prepared biases; it does not pay avoidable per-element casts or separate C additions.

The output is one word with a byte per column. Each byte encodes two output entries in radix 7. Two weight-dependent sign bits are part of the prepared representation and define how both implementations' output is interpreted. These are explicit static codec metadata, not per-use work or an unreported dynamic side channel. A consumer demanding a different output format must pay the same decoding cost for either implementation.

Input loads, output stores, launch overhead and termination are common and outside the listed arithmetic cores. The assembly assumes the prepared weight words and biases are already in registers. If preparation must repeat for each invocation, that is a different reuse regime. [Amortization.lean](../../Kelana/Amortization.lean) proves why every finite one-time loading bill disappears from the selected infinite-reuse comparison.

## The construction

For one output column, write

```
d0 = a00 b0 + a01 b1 + c0
d1 = a10 b0 + a11 b1 + c1.
```

Choose signs h and l from `{+1,-1}` and encode the two results as

```
p = (l d1 + 3) + 7(h d0 + 3).
```

Both parenthesized digits lie in `[0,6]`, so `0 ≤ p ≤ 48`. They decode exactly:

```
d0 = h(floor(p/7) − 3)
d1 = l((p mod 7) − 3).
```

Expand p in the *input* trit codes rather than first computing d0 and d1:

```
k0 = l a10 + 7h a00
k1 = l a11 + 7h a01
bias = 24 − (k0 + k1 + 7h + l)

p = k0(b0+1) + k1(b1+1) + 7h(c0+1) + l(c1+1) + bias.
```

That is one native signed-i4 × unsigned-u4 dot instruction with four live lanes and a prepared int32 bias.

The non-obvious step is fitting k0 and k1 into signed int4. An unsigned sign choice could produce +8, which does not fit. Try `(h,l)=(1,1)`, then `(1,-1)`, then `(-1,1)`. One always places both coefficients in `[-8,7]`. Each matrix column can forbid at most one orientation, so two columns cannot forbid all three choices. The other coefficients, `7h` and l, also fit int4.

The preparation distribution across all 81 possible A matrices is 64 normal orientations, 15 low-row flips and 2 high-row flips. The implementation then uses two dot instructions, one per output column, and one shift-or to join the two output bytes.

Radix 7 is deliberate. Radix 8 would give coefficients as large as ±9 and does not fit signed int4 for every A. We change the representation to fit the instruction, rather than insist on a power-of-two arithmetic interpretation.

## Proofs and checks

[Kelana/Toy2.lean](../../Kelana/Toy2.lean) contains kernel-checked proofs of:

- existence of a valid prepared sign orientation;
- equality of the fused dot expression and the specified matrix output encoding;
- equality with the elementwise baseline;
- exact output decoding and value bounds;
- the exact symbolic instruction-cost saving;
- eventual advantage after any finite preparation cost.

The mathematical proof models instruction arithmetic through the expressions above. The assembly and finite checks connect that model to concrete word layouts; this is not a formally verified assembler or GPU implementation.

[check.py](check.py) independently checks all **531,441** valid A/B/C combinations against ordinary matrix arithmetic. It also checks the common bit-expansion network on all **65,536** 16-bit inputs, including codes outside the ternary domain. [check-results.json](check-results.json) records the source hash and results.

[kernels.s](kernels.s) contains the two explicit gfx1151 arithmetic cores. [assemble.py](assemble.py) assembles and disassembles them, then checks the emitted opcode counts. [assembly-results.json](assembly-results.json) records the source hash and 13/9 counts. The common `s_endpgm` terminator is excluded from both counts.

[gpu_check.cpp](gpu_check.cpp) and [gpu-check.sh](gpu-check.sh) provide a native correctness check over all valid inputs. The first run compiled but GPU admission returned 75 because resident reservations left insufficient headroom. [gpu-status.json](gpu-status.json) records that result. No native GPU correctness result or timing measurement is claimed.

From the repository root:

```sh
lake build
lake env lean research/Audit.lean
python3 research/toy2/check.py --output research/toy2/check-results.json
python3 research/toy2/assemble.py --output research/toy2/assembly-results.json
bash research/toy2/gpu-check.sh
```

The last command uses the host's shared `gpu-run` admission mechanism. It does not evict resident workloads. Python, LLVM and the optional HIP toolchain are already host-owned; this experiment creates no service or model cache.

## Follow-up: the online cost under free packing

[optimality/NOTES.md](optimality/NOTES.md) continues this experiment with a free
wire-only input packing pass granted to both sides. The incumbent's online core
is then three instructions; one `V_DOT4_I32_IU8` with prescaled lanes followed
by one `V_DOT8_I32_IU4` through its accumulator does the same job in two, for
every A, and a single instruction suffices for some A once the wiring may depend
on A. [Kelana/Toy2Optimality.lean](../../Kelana/Toy2Optimality.lean) carries the
proofs, including a lower bound ruling out any single 4-bit-lane dot with shared
wiring.

## One-dot core with a different output label

[The radix-64 construction](radix64/README.md) packs both output columns into a
12-bit code and computes the complete map with one signed-byte/unsigned-byte
`V_DOT4_I32_IU8`. Its shared input wire places two trit codes into each byte;
Lean proves the exact endpoint and all 531,441 triples replay against ordinary
matrix arithmetic. This is an optimum for the declared free-wire arithmetic-core
model at the radix-64 observation. The byte-pair endpoint above needs conversion,
and neither input wiring nor a compatible downstream consumer has native timing.

## What remains

The result establishes a cheaper exact construction than four separately computed matrix entries under a common packed-output contract. It does not establish that nine instructions is minimal, that dot instructions are the best family, or that all input expansion is necessary. The next search can target the shared six-instruction expansion or replace the dot formulation entirely. Lower-bound arguments must not assume that shared intermediate merely because these two candidates use it.
