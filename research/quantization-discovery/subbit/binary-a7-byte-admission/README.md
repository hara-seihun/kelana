# Why four-sign A7 byte tables need a dynamic fallback

The paid two-factor binary `mlp_up` reader already has an exact four-sign response table. At A7 its full-code-domain range needs int16, while the A6 version fits signed byte. This panel asks whether the *actual* A7 activations leave enough byte-safe tables to make a mixed-width reader worth building. Most individual tables fit, but almost none can be assigned a static byte width across even 64 new inputs. A uniform byte-only A7 reader instead splits each eight-sign block into four two-sign tables and doubles the gathers versus `(4,4)`.

## Exact admission and cost

For four signed A7 codes `q0,q1,q2,q3`, a half-orbit table stores eight values `q0 ± q1 ± q2 ± q3`. Let `S=|q1|+|q2|+|q3|`. Its exact integer extrema are `q0-S` and `q0+S`. The table fits signed byte if and only if `q0-S >= -128` and `q0+S <= 127`. This is a constant-time per-input test that avoids enumerating the entries, not an assumption based on an average code magnitude. The packed first sign selects the response sign *after* widening the byte to int32; negating byte `-128` in byte arithmetic would be wrong.

No fixed four-sign table can use signed bytes on the whole A7 code domain: `(-64,-64,-64,-64)` has entry `-256`. A two-sign table has the tight full-domain range `[-128,127]` and fits byte. Under the existing one-gather-plus-sign per disjoint subblock grammar, four two-sign byte tables per eight-sign block are necessary if every subtable must be byte for every A7 code vector. This does not bound arbitrary ISA programs, packed residuals, or changing the activation codes.

For a paid `K=1024`, rank-384, `N=3072` up projection, both factors together use 176 original eight-code tables and 196,608 response uses per input. A `(4,4)` mixed-width reader still makes 393,216 gathers and row additions, compared with 786,432 for uniform byte `(2,2,2,2)`, or 196,608 for int16 eight-sign half tables. A byte four-sign subtable takes eight bytes and an int16 fallback sixteen. The code must also pay two A7 quantizers, ladder multipliers, intermediate traffic, signed-index extraction, the width test and fallback control. These operation counts do not predict native time.

## Paid-image panel

`OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/binary-a7-byte-admission/measure.py` reads frozen `.55` one-bit U/V images and 64 fresh Qwen3-0.6B validation inputs, rows 960:1024, at layers 0/7/14/27. Both factor stages use the existing safe two-choice A7 C8 ladder. The script computes complete integer rank and output responses, enumerates all eight table entries to check the extremum theorem, and checks admitted int8 storage and post-widening negation against the int32 table. Every image, fixture, first/final integer output, ladder weights, code array and table has a SHA-256 identity in the [CPU receipt](/path/to/workspace/data/kelana-subbit/binary-a7-byte-admission/receipt.json).

| Layer | Input byte-safe four-tables | Rank byte-safe four-tables | Input static-safe across all 64, of 256 | Rank static-safe across all 64, of 96 |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 15,806/16,384 | 5,816/6,144 | 51 | 5 |
| 7 | 15,718/16,384 | 5,850/6,144 | 36 | 12 |
| 14 | 15,768/16,384 | 5,873/6,144 | 48 | 16 |
| 27 | 15,826/16,384 | 5,717/6,144 | 73 | 17 |

Per-input byte admission is 93.1–96.6%, but a byte/int16 schedule frozen even by a held-data oracle would use byte for only 14–29% of first-stage positions and 5–18% of second-stage positions over all 64 inputs. Two 32-row halves admit more positions, but an unseen code vector can still overflow them. Dynamic mixed width keeps the 3.4–7.0% fallback rate by choosing per input, at the cost of width tests and nonuniform tables across rows. Total table data for one input ranges from 2,816 bytes if all four-sign subtables fit byte to 5,632 bytes if none do; the measured per-input average is 2,927–2,939 bytes across layers. Uniform two-sign byte subtables use 1,408 bytes but double `(4,4)` response reads and row additions. All of these tables are prepared from activations at runtime, not stored weight bytes.

The paid factorization offers a free rank-coordinate gauge inside each second-stage 32-coordinate ladder group. Reorder V's rank rows and the corresponding U columns together. The group range and ladder step are unchanged, and integer sums are exact, so the complete two-stage output is identical. We tried a train-only stable sort by each rank's mean absolute second-stage A7 code on 64 separate train rows 896:960. It clusters large codes instead of scattering them. This does not buy byte admission on fresh inputs:

| Layer | Identity held admitted of 6,144 | Sorted held admitted | Train-fitted static byte positions, identity / sorted of 96 | Held byte overflows at those train-selected positions, identity / sorted |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 5,816 | 5,810 | 8 / 12 | 11 / 27 |
| 7 | 5,850 | 5,827 | 11 / 22 | 31 / 52 |
| 14 | 5,873 | 5,772 | 10 / 23 | 31 / 28 |
| 27 | 5,717 | 5,510 | 23 / 32 | 44 / 27 |

The sorted gauge's integer output SHA-256 agrees with the original at each layer. Static byte positions selected on train overflow even under the unchanged original rank order. The sort increases the *number* of train-safe positions by concentrating failures, but it decreases held individual-byte eligibility on all four layers. A no-fallback reader would need a proof over its reachable quantizer codes, not a train-only mask.

This is a bounded CPU negative for treating observed A7 byte eligibility as a static cheap four-sign table map, including one exact rank-repacking gauge. The A7 response, binary weight rate and conditional quantization error are unchanged; no GPU, model NLL, engine binary or service changed. The next native experiment should compare uniform int16 `(4,4)` with uniform byte `(2,2,2,2)` at both factor stages, including quantizers and rank traffic. Only add the mixed-width fallback if narrower tables pay for more reads and the native branch bill is below the saved table/lookup cost. Learning activation codes with a hard four-sign byte constraint is a different, lossy co-design question that could avoid fallback but needs composed quality evidence.
