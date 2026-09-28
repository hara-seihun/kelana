# Centered four-sign A7 tables do not earn a byte-only reader

The paid Qwen3-0.6B binary `mlp_up` factors have an exact two-stage A7 consumer. Its four-sign half-orbit table usually fits signed byte for one activation, but few table positions remain byte-safe over many inputs. This study asks whether shifting each four-code input by one integer center can make those tables byte-sized without changing the integer output. It gives the optimal admission test for this centered grammar, then charges the missing correction.

For a quartet of signed integer codes `q=(q0,q1,q2,q3)` and packed weight signs `s`, choose integer `c`, set `r_i=q_i-c`, and use the half-orbit table `T_c(a)=r0+sum_{i=1}^3 a_i r_i` for `a_i∈{-1,1}`. The exact response is

```
s0*T_c(s0*s1,s0*s2,s0*s3) + c*(s0+s1+s2+s3).
```

The second term cannot be silently discarded or treated as one correction per activation: it depends on the paid output signs. Its sign sum can be derived from four packed bits, or stored for each output/quartet. The latter uses one byte per sign sum, 98,304 first-stage and 294,912 second-stage bytes for this `mlp_up`, in addition to the existing factor image. Computing it online instead pays extraction/popcount plus the dynamic center product and sum. Either route needs a complete native comparison; byte admission alone is not a speed result.

Let `L(c)=sum_i |q_i-c|`. Any integer center between the two middle order statistics minimizes `L`; denote the minimum `L*` and the upper median `u`. The table fits `[-128,127]` iff `q0-c-S>=-128` and `q0-c+S<=127`, where `S=sum_{i=1}^3 |q_i-c|`. Thus **some integer center admits the byte table exactly iff `L*<=127`, or `L*=128` and `u>q0`**. For the edge case choose a minimizing `c>q0`, placing `-128` rather than `+128` at the extreme. If `L*>128`, no center can help. This is a complete integer-code-domain statement in the grammar of one common center per quartet followed by one half-orbit byte lookup and an exact correction. It does not bound general byte programs or changed quantizer codes. In particular `(-64,-64,63,63)` has minimum radius 254, so a universally byte-sized four-sign A7 table is impossible even after centering.

The script opens the frozen paid `.55` factor images and original-producer validation fixture rows 960–1023 on four layers. It uses the parent's safe `.75` A7 ladder at both stages, not a changed lossy model. Every observed half-orbit label is checked against the correction identity, the first quartet is replayed across every paid output sign row, and complete factor outputs are hashed. Results are table instances over 64 inputs; static positions mean safe on *all* 64. Each layer has 16,384 first-stage and 6,144 second-stage table instances, with 256 and 96 distinct positions respectively.

| layer | input raw→centered byte tables | input all-64 safe positions | rank raw→centered byte tables | rank all-64 safe positions | extra nonzero corrections, input/rank |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 15,806→16,136 | 51→115 | 5,816→6,005 | 5→34 | 2,267,587 / 6,972,172 |
| 7 | 15,718→16,107 | 36→116 | 5,850→6,027 | 12→30 | 2,352,566 / 6,984,697 |
| 14 | 15,768→16,114 | 48→111 | 5,873→6,037 | 16→44 | 2,332,320 / 7,172,085 |
| 27 | 15,826→16,126 | 73→130 | 5,717→5,987 | 17→47 | 2,305,104 / 7,314,487 |

Centering admits 300–389 more first-stage and 164–270 more rank-stage tables per layer, yet still leaves 107–157 int16 rank tables and 248–277 int16 input tables across the sampled input panel. Only 30–47 of 96 rank positions survive as static byte after centering. Even restricting the extra correction to nonzero centers *and* output quartets with nonzero sign sum leaves roughly nine million extra per-output corrections per layer over 64 inputs; ordinary centered table lookups number 25.17 million across the two stages. A branch to skip corrections itself has a cost. The result rejects centered byte tables as a free fix to the static-width problem on these frozen codes. It does not reject training new signs or grouping the A7 quantizer's coordinates into quartets whose median radii are uniformly small.

Next compare a full native **uniform int16 four-sign** versus **uniform byte two-sign** reader, with both quantizers, table construction and rank traffic charged. If that shows a large byte advantage, train quartet-aware A7 codes on quantized-producer composed MLP or gold loss and revisit the centered width together with its correction bill. Do not add a dynamic centered-width fallback for these frozen images on the strength of admission frequency alone. There is no GPU, whole-model loss, native timing or engine change here.

`measure.py` writes the source, parent reader, image, fixture, code, table, center, sign and integer-output hashes to [`data/kelana-subbit/binary-a7-centered-byte/receipt.json`](/path/to/workspace/data/kelana-subbit/binary-a7-centered-byte/receipt.json). Reproduce from any Kelana checkout:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/binary-a7-centered-byte/measure.py
```
