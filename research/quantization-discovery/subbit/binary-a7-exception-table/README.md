# One exception bit rescues the A7 byte-table response

The paid Qwen3-0.6B binary `mlp_up` factor reader cannot use an ordinary signed-byte four-sign table over the whole A7 code domain. Splitting into two-sign subtables makes byte storage unconditional but doubles its two-stage lookup count again. There is a third exact coordinate: store every four-sign response modulo 256 in a signed byte, plus one bit at each table entry whose true integer response is out of byte range. The byte itself tells us which direction to correct. This keeps two four-sign lookups per eight signs without an int16 table or int4 weight expansion.

## Construction and domain

For codes `q_i ∈ [-64,63]`, let `T_j=q0+Σ(i=1..3) σ_i(j)q_i`, with `σ_i∈{-1,+1}`. The complete A7 domain gives `-256≤T_j≤255`. Set `b_j=((T_j+128) mod 256)-128` and `m_j=[T_j∉[-128,127]]`. Then

```
T_j = b_j + m_j * (b_j >= 0 ? -256 : +256).
response(s) = s0 * T_index(s0*s1,s0*s2,s0*s3).
```

The three relative signs choose the index; the first sign is applied *after* widening and correcting. If `T_j<-128`, its wrapped byte lies in `[0,127]`; if `T_j>127`, its wrapped byte lies in `[-128,-1]`. Thus one bit plus the byte determines the integer result throughout the full domain, including `T=-256` and `T=255`. Eight byte entries and an eight-bit mask suffice for every four-sign table. There is no conditional int16 fallback and no stored per-exception payload. Byte tables may omit the mask only if their construction proves all eight entries safe. The construction preserves the selected two-stage integer A7 map, not its FP64 source-weight response or its FP32 rounding order.

For the two paid factors of one `K=1024, R=384, N=3072` up projection, each input row prepares 352 four-sign tables and selects 393,216 responses across both factors. A fixed-stride layout takes nine bytes/table or 3,168 temporary bytes/input, against 5,632 for int16 four-sign and 1,408 for byte two-sign tables. A tightly packed variable-stride layout can omit safe-table masks, but must also pay offsets or branches. All routes still pay both A7 quantizers, intermediate rank writes, integer-ladder reductions and output scales. In the masked route, each selected response additionally tests a bit and potentially adds `±256`; even when the correction rarely fires, the bit test and control are not free.

## Paid-image frequency, not a speed claim

The CPU panel reuses the pinned `.55` one-bit U/V images, rows 960:1024 of the Qwen3-0.6B original-producer validation captures, and the safe `.75` two-boundary A7 ladder at layers 0/7/14/27. It computes both paid factor responses. Packed U/V signs are counted by actual relative-sign index, not by assuming table entries are selected uniformly. The first full input per stage also checks every selected wrapped response against the direct unpacked integer factor dot. The script checks every table entry's wrapped-byte reconstruction over all 64 rows. [The receipt](/path/to/workspace/data/kelana-subbit/binary-a7-exception-table/receipt.json) binds source, parent source, image, fixture, A7 codes, paid signs, selection histogram, tables, ladder weights and both complete factor outputs.

| Layer | Bad four-sign tables / 22,528 | Exceptional entries / 180,224 | Selected corrections / 25,165,824 | Corrections as uses | Prepared bytes, packed masks / int16 four-sign / byte two-sign |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 906 | 1,048 | 175,402 | 0.697% | 181,130 / 360,448 / 90,112 |
| 7 | 960 | 1,096 | 165,311 | 0.657% | 181,184 / 360,448 / 90,112 |
| 14 | 887 | 1,016 | 157,547 | 0.626% | 181,111 / 360,448 / 90,112 |
| 27 | 985 | 1,130 | 222,882 | 0.886% | 181,209 / 360,448 / 90,112 |

Every bad table in this panel has one or two exceptional entries, but the one-mask theorem needs no such restriction. A fallback chosen per *table*, rather than per selected entry, would send 1,069,056–1,526,016 response uses to an int16 route across these layers. The exceptional-entry route corrects only 157,547–222,882 of them. This is a more informative scheduling target than the preceding table-admission rates: paid sign patterns decide how often the exceptional entries are read.

Do not infer speed from the 0.6–0.9% correction rate. A native byte-only four-sign reader must expose its byte and mask with tolerable register use and address preparation, and a divergent branch on each selected entry could cost more than a uniform int16 read. Compare complete two-factor native `int16 (4,4)`, `byte (2,2,2,2)` and masked-byte `(4,4)` readers at identical A7 codes and occupied batch widths. Charge both quantizers, table creation, rank materialization and scales. If masked selection loses, change the factor signs or quantizer grouping so the exceptional bits admit a regular, shared schedule rather than reducing the frozen admission rate again. This is a CPU exact-integer construction and a paid-sign work count; no GPU, whole-model loss, engine binary or service changed.

Reproduce from a Kelana checkout:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/binary-a7-exception-table/measure.py
```
