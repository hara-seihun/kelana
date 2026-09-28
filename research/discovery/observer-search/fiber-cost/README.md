# Packed SiLU sign observer on a complete ternary cube

A packed three-trit input supports a complete gate, up, SiLU and ternary sign observation without recovering the trits. For all 676 pairs of nonzero ternary weight vectors `g,u` on three coordinates, let

```
q = (x+1) + 3(y+1) + 9(z+1),  x_i in {-1,0,1}
F(g,u,x) = sign(SiLU(g dot x) * (u dot x)).
```

Since the real sigmoid is strictly positive, `F = sign((g dot x)*(u dot x))`. Prepare two 27-bit constants. Bit `q` of `P` is one when `F=1`; bit `q` of `N` is one when `F=-1`. Then `BFE(P,q,1)-BFE(N,q,1)` is the whole observed region. It keeps `q` injective across all 27 states, unlike the eleven-state carrier rejected by the [trained-region study](../../joint-observer/TRAINED.md). The threshold at zero is part of this map, not a fit to a smooth proxy.

[The sign-orbit quotient](SIGN-ORBIT.md) preserves all 676 observers with exactly 14 input states and is minimal for the entire family. It packs each endpoint into one 28-bit signed-field literal and needs one signed extract when the shared input offset is ready. Starting from the original radix-3 code costs three shared instructions, so one isolated observer takes four instructions rather than the two-mask path's three; two or more observers amortize that boundary. Neither construction preserves SiLU amplitude.

The executable census covers all 18,252 combinations of input and weights. There are 432 three-valued and 244 two-valued maps, with 182 distinct endpoint tables. `test_bitplanes.py` checks each output against a separate real-SiLU calculation. The example with `g=(1,1,1), u=(1,-1,0)` uses constants `0x00905048` and `0x03010406`. [`example.s`](example.s) assembles for gfx1151 into two literal `v_bfe_u32` instructions of 12 bytes each and one four-byte `v_sub_nc_u32_e32`. Thus the data region is three instructions and 28 code bytes, conditional on `q` already being in a VGPR and the weight-specific masks being prepared.

Within the restricted straight-line grammar of one-bit `BFE(C,q,1)` and a final binary subtraction, the 432 three-valued maps need both lookups and the combining instruction. One lookup has only two values. Two lookups without a combine leave each destination Boolean. This is a three-instruction optimum **only in that grammar**; affine arithmetic on `q`, wider extraction, permutation, comparisons and other ISA instructions are not excluded. The two-value maps may need less. Literal encodings are an assembly fact, not a throughput measurement.

This does not replace the deployed FFN. It observes a ternary sign, whereas Bonsai's hidden quantizer uses dynamic scales and produces A4/A8 codes; its SiLU and FP32 rounding also have a distinct native contract. Packing the three inputs, forming masks for input-dependent gates, combining many hidden outputs, and carrying a code into the next consumer all cost work. A table prepared from a runtime activation would require evaluating its 27 entries online. The useful next native question is whether several fixed sign or cell predicates share an incoming packed `q` and the same weight-specific masks across enough rows to amortize those boundaries. For the actual hidden A4 observer, first include its dynamic scale and rounding in the finite region, then check if a small set of precomputable bitplanes survives. A single isolated three-instruction predicate is not a model speedup.

Run from this directory:

```
python3 -m unittest -q test_bitplanes
python3 bitplanes.py
llvm-mc -triple=amdgcn-amd-amdhsa -mcpu=gfx1151 --show-encoding example.s
```

[`results.json`](results.json) records the census and emitted witness. This construction extends the [instruction-first observer study](../README.md), and its cost is deliberately separate from the semantic equality.
