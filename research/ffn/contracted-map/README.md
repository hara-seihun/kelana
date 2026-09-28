# Compile the observed function, not the hidden layer

Two exact constructions remove an entire hidden layer on a two-trit input domain. The second
also removes every recognizable arithmetic operation from its online evaluation.

This is a new two-input toy, not the earlier 2×2 matrix problem. No whole-Bonsai speedup is
claimed here.

## Two instructions for the complete observed function

Let `f : {-1,0,1}² -> byte`, with `f(0,0)=0`. It may be a quantized FFN output, a composed
program, or an arbitrary function. Prepare its eight other output bytes once.

Represent each input trit with its signed two-bit code, `-1 -> 3, 0 -> 0, +1 -> 1`, and put
`raw = code(x) | (code(y) << 2)` in a register. On gfx1151:

```text
selector = V_BFE_U32(0x722c, raw, 4)
result   = V_PERM_B32(table_hi, table_lo, selector)
```

The low result byte is `f(x,y)`. No gate/up projections, hidden products, activation or
intermediate channel decoding remain. This is a register-resident lookup compiled from the
whole function, not a faster implementation of its original operations.

The trick is that the nine valid raw input words map to eight byte selectors plus PERM's
built-in zero selector:

| x | y | raw | selector |
|---:|---:|---:|---:|
| -1 | -1 | 15 | 0 |
| +1 | +1 | 5 | 1 |
| 0 | +1 | 4 | 2 |
| +1 | -1 | 13 | 3 |
| -1 | +1 | 7 | 4 |
| -1 | 0 | 3 | 5 |
| +1 | 0 | 1 | 6 |
| 0 | -1 | 12 | 7 |
| 0 | 0 | 0 | 12, emits zero |

[`TritObserver.lean`](../../../Kelana/TritObserver.lean), `observer_compilation`, proves this
for **every** such byte-valued function using the project's actual BFE and PERM meanings.
The proof is kernel-checked bit extensionality, with no native-decide axiom or proof hole.
[`selector.py`](selector.py) searches all 65536 source words under this selector template and
finds two solutions, recorded in [`selector.json`](selector.json). This search does not prove
an instruction-count optimum.

[`observer.hip`](observer.hip) executes the two instructions on gfx1151. It checks 257 complete
functions, including the 64-unit network below, on all nine states: **2313 cases, zero mismatches**.
[`observer-result.json`](observer-result.json) records the run. The compiled map contains one
BFE, one PERM and a byte store; the kernel uses five VGPRs. Loads, addressing and kernel control
are additional instructions. No throughput measurement was made.

The contract matters:

- Input trits already occupy the specified four bits. Producing that layout from other inputs
  costs work.
- Only the low output byte is observed. A signed int32 consumer needs sign extension; upper
  PERM bytes are not meaningful output.
- Tables contain eight bytes per scalar output. Preparing a table costs nothing asymptotically
  only when the function's parameters remain fixed across calls.
- A universal table for this class needs 64 bits of function-specific information, because
  there are `256^8` possible functions. This elementary counting argument bounds information,
  not instructions, and does not apply to a restricted function family.
- Multiple outputs can share the selector, then use one PERM and eight table bytes per output.

## The algebraic collapse that led here

For a bias-free gated network

```text
F(x,y) = sum_i c_i s(a_i*x + b_i*y) * (u_i*x + v_i*y)
```

assume `s(t)-s(-t)=t`. Ideal real SiLU and ReLU satisfy this reflection identity. Then

```text
F(x,y) + F(-x,-y) = sum_i c_i (a_i*x+b_i*y)(u_i*x+v_i*y).
```

The antipodal sum is quadratic. On ternary inputs, `x³=x` and `y³=y`; the whole network
therefore reduces to seven monomials:

```text
x, y, x², y², xy, x²y, xy².
```

[`ContractedFFN.lean`](../../../Kelana/ContractedFFN.lean) proves `contracted_network` over a
commutative ring, with the reflection identity as a hypothesis. It constructs seven
coefficients representing `4F`, avoiding division by two in rings where that is unavailable.
The theorem does not formalize real exponential arithmetic or FP32 SiLU. Over integers,
`coefficients_unique` proves uniqueness in this seven-feature family. That is not a hardware
lower bound.

[`check.py`](check.py) evaluates networks of hidden widths 1, 8, 64 and 256 with four outputs
on all nine inputs using exact integers. All 144 output cases agree. Exact rational rank
calculations show the seven-feature space and the family of 81 ternary ReLU units both have
rank seven. [`result.json`](result.json) retains all parameters and coefficients.

The generated [`ContractedToy.lean`](../../../Kelana/ContractedToy.lean) gives a concrete
64-unit ternary ReLU network whose `2F` is one signed nibble dot against
`[0,-5,0,1,1,1,-2,0]`, after feature encoding. Its nine values are
`[8,0,-2,6,0,-4,2,0,-4]` in lexicographic input order.

That dot was not the final answer. [`probe.hip`](probe.hip) confirmed it on the GPU, but
forming its monomials and packed nibbles generated about 25 VALU operations, including two
quarter-rate multiplies. The two-instruction observer bypasses those features entirely and
returns the same `2F` as a signed byte. `two_instructions_replace_network` proves that
composition against the explicit 64-unit network. This is why the final consumer's output contract must
participate in map selection.

## Why this does not yet replace Bonsai's FFN

The small changing input domain makes the table affordable. A lookup over `d` independent
trits grows as `3^d`. Bonsai's activation codes are not trits; A4 has fifteen values, and its
per-token scales also change. Precomputing weights does not precompute activation-dependent
scales or a function of thousands of changing inputs.

Nor can we evaluate the two-input toy independently on input chunks and add the answers.
The nonlinearity couples their sums. `outside_domain_counterexample` in the Lean file also
shows that extending the contracted polynomial beyond ternary inputs changes the function.

We tested a separate continuous-domain contraction on real layer-0 weights:
[`contracted-quadratic/FINDINGS.md`](../contracted-quadratic/FINDINGS.md). Contracting the even
part into output quadratic forms and then applying spectral truncation needs ranks around
1600–2000 for 10% error on captured inputs. Independent output forms break even near rank 10.
The tested shared basis also loses. Both quantisers are excluded from that experiment, so it
is not an impossibility result for the deployed map.

The useful search question is now precise: can a substantial FFN region factor through a
small, cheap-to-compute state that its final consumer can observe directly? The two-trit map
answers yes exactly. The dense quadratic representation answers no for the measured low-rank
schemes. Neither result requires preserving the original intermediate operations.

## Reproduce

From the repository root:

```sh
python3 research/ffn/contracted-map/check.py
python3 research/ffn/contracted-map/selector.py
lake build Kelana.ContractedFFN Kelana.ContractedToy Kelana.TritObserver
```

For native correctness and assembly, from this directory:

```sh
mkdir -p build
hipcc --offload-arch=gfx1151 -O3 observer.hip -o build/observer
../batched/hardware-run ./build/observer > observer-result.json
hipcc --offload-arch=gfx1151 -O3 --cuda-device-only -S observer.hip -o build/observer.s
hipcc --offload-arch=gfx1151 -O3 probe.hip -o build/probe
../batched/hardware-run ./build/probe > native-result.json
```

GPU work uses the existing research lock. These commands do not benchmark throughput or
change services and clocks. `build/` is disposable; source, proofs and recorded results are
owned by Kelana.
