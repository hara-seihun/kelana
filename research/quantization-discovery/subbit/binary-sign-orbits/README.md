# Selective response-table preparation on paid binary factors

The frozen Qwen3-0.6B binary-factor signs nearly exhaust their eight-sign response-table addresses. Skipping unused half-orbit entries cannot materially reduce the preparation of the complete two-factor consumer. For `mlp_up`, the first stage uses 62,285 of 65,536 entries across four paid images; the output stage uses **all 24,576**. This settles a specific alternative to splitting tables into four-sign parts: do not build a sparse preparation schedule for these unchanged signs. A useful sparse table must change the factor signs themselves, and therefore needs a quality fit.

## Domain and bound

Each consecutive eight-sign chunk of a factor row indexes one of 128 relative-sign classes after quotienting by a global sign. For algebraically independent real input coordinates, distinct classes give different response linear forms up to sign. If a chunk uses `m` classes over its rows, a direct one-read-plus-sign table needs at least `m` entries for that chunk. The quotient index is `(packed_byte >> 1) XOR (packed_byte & 1 ? 0 : 127)` with bit 0 indicating a positive sign.

The regular [half-orbit table](../binary-half-table/README.md) uses 128 entries and 127 Gray updates after its seed. In a *scalar, one-response-created-per-update grammar* that generously grants the first generic response for free, preparing `m` distinct needed responses takes at least `m-1` updates. Thus even an ideal selective schedule can save **at most `128-m`** of those 127 Gray updates per chunk. The usual base and doubling setup, extraction and address routing are outside this optimistic saving. In particular, an unchanged direct-index table still reserves 128 addresses; compacting it requires an index map or a different label layout. This is neither an ISA-independent bound nor a native latency bound. A vector instruction may generate several responses at once.

If a new factor image is restricted to at most `c` orbit classes per fixed chunk, retain the `c` most frequent old classes. Every old occurrence in a discarded class must change at least one sign to enter the new alphabet. The sum of discarded frequencies is therefore an exact lower bound on changed eight-sign block occurrences for that cap, under this fixed chunk layout. It is attainable as an occurrence count if arbitrary reassignment is permitted, but says nothing about the response or model loss after changing signs, or the number of bit flips beyond one per changed occurrence. A simultaneous permutation of rank coordinates changes the chunk grammar and is not covered.

## Frozen-image measurement

`measure.py` reads the packed U and V planes of sixteen paid `.55` Qwen images, projections down/up/O/Q at layers 0, 7, 14 and 27. The first stage is V; the output stage is U. The table aggregates four layers per projection. A 96-class cap is the first target shown: it allows at most 95 one-entry updates per chunk, against 127 for the full Gray generator, only if the new signs can be fitted without offsetting work.

| Projection | Stage | Used / 128-entry capacity | Full chunks | Maximum saved Gray updates | Minimum changed block occurrences for 96 classes |
| --- | --- | ---: | ---: | ---: | ---: |
| down | first | 186,639 / 196,608 | 3 / 1,536 | 9,969 / 195,072 | 49,228 / 589,824 = 8.35% |
| down | output | 24,572 / 24,576 | 188 / 192 | 4 / 24,384 | 28,619 / 196,608 = 14.56% |
| up | first | 62,285 / 65,536 | 0 / 512 | 3,251 / 65,024 | 16,553 / 196,608 = 8.42% |
| up | output | 24,576 / 24,576 | 192 / 192 | **0 / 24,384** | 109,367 / 589,824 = 18.54% |
| O | first | 122,110 / 131,072 | 0 / 1,024 | 8,962 / 130,048 | 25,823 / 360,448 = 7.16% |
| O | output | 22,521 / 22,528 | 169 / 176 | 7 / 22,352 | 26,275 / 180,224 = 14.58% |
| Q | first | 61,197 / 65,536 | 0 / 512 | 4,339 / 65,024 | 13,174 / 180,224 = 7.31% |
| Q | output | 22,528 / 22,528 | 176 / 176 | **0 / 22,352** | 60,097 / 360,448 = 16.67% |

The complete up map can save at most 3,251 of its 89,408 Gray updates, or 3.64%, even if a sparse schedule incurs no address or scheduling overhead. Its output stage cannot skip a single entry. This is an optimistic arithmetic count, not a prediction for gfx1151. It also explains why another hand-tuned selective generator for these signs is a worse next experiment than a learned sign alphabet. The 96-class up-output target forces at least 109,367 of 589,824 sign chunks to move before any quality improvement is considered. Fitting both factors under this alphabet, then timing the whole two-stage program against the regular half table and partitioned tables, is the next useful question.

The source, all image hashes, per-chunk occupancy histograms, code-index hashes, and exact top-frequency reassignment bounds at 64/96/112 classes are in `/path/to/workspace/data/kelana-subbit/binary-sign-orbits/receipt.json`. Reproduce from the Kelana root with `OPENBLAS_NUM_THREADS=1 python3 research/quantization-discovery/subbit/binary-sign-orbits/measure.py`; it reads paid signs but no GPU or model activations. No stored weight rate, model quality, native code, engine executable or service changed.
