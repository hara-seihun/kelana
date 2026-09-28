# Repairing the eleven-state carrier without unpacking its source

The joint observer's `h = floor(27q/64)-5` collapses the 27 packed three-trit inputs into eleven labels. [The trained-region experiment](TRAINED.md) showed that this loses required output distinctions on every tested region, even with an arbitrary decoder. There is an exact, cheap way to keep the observer's useful label while preserving those distinctions: carry `s = q & 3` beside `h`. The map `q -> (h,s)` is injective on `q=0..26`. This is a representation of the complete three-input state, not a claim that the trained FFN now has a cheap consumer.

## Exact information cost

The fibers of `h`, in ascending order, are:

```
h=-5: 0,1,2       -4: 3,4       -3: 5,6,7
h=-2: 8,9        -1: 10,11      0: 12,13,14
h= 1: 15,16       2: 17,18      3: 19,20,21
h= 4: 22,23       5: 24,25,26
```

Some fibers have three elements. Any exact continuation distinguishing all 27 states needs at least three side labels conditional on `h`, whatever functions it uses. Two fixed-width side bits are necessary. They suffice because each fiber is a run of two or three consecutive integers, whose low two bits are distinct. The pair has 27 reachable states, not 44; `h` and `s` are correlated. One fixed-width bit is impossible even with an arbitrary side producer and a free decoder. This bound assumes that `(h,s)` is all the dynamic input information crossing the boundary; an uncharged copy of `q` changes the contract.

For the more specific grammar of one AND against an immediate mask on five-bit `q`, exhaustive enumeration of masks 0..31 finds exactly eight valid masks: `3,7,11,15,19,23,27,31`. Each includes both low bits. An arbitrary three-valued side label could also suffice, but no one-instruction realization of such a label is asserted. `sideband.py` constructs and checks the inverse table for all 27 states and emits a collision for rejected masks. `test_sideband.py` checks the lower-bound witness, inverse and entire mask grammar.

## Native boundary price

[`sideband.s`](sideband.s) assembles for gfx1151 with two data instructions for `h` and one `v_and_b32` for the side. It keeps packed `q` in `v0`, places `h` in `v1` and `s` in `v2`; [`sideband-encoding.txt`](sideband-encoding.txt) records the assembled instructions. If a live `q` register can cross the boundary, retaining it is strictly less work than materializing `s`, and the side should not be computed. If `q` must die while the eleven-state observer's downstream consumer uses `h`, the extra AND plus one live register is an achievable sideband producer. Register lifetime, lane layout and the decoder of `(h,s)` into any trained-region result remain unpriced. Do not equate two bits of side information with a two-bit memory saving: the original `q` already fits in five bits, while two separately materialized register values can cost more.

This result repairs the *semantic* collision that ruled out the eleven-state carrier on the finite trained regions. It does not repair its execution cost or establish FP32 identity: the trained-region tables use CPU float64 and fixed A8 scale cells, and no native FFN continuation consumes `(h,s)` today. A worthwhile next experiment would keep `h` for the six known joint-observer functions and use `s` only when a quantizer-cell-aware trained consumer needs to distinguish two members of the same fiber. Build that consumer before a GPU run; compare its complete producer, side lifetime and output map against carrying `q` directly.

Reproduce from this directory:

```sh
python3 -m unittest -q test_sideband.py
python3 sideband.py
llvm-mc -triple=amdgcn-amd-amdhsa -mcpu=gfx1151 --show-encoding sideband.s
```
