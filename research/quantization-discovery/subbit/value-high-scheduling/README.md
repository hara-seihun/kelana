# Four-lane high corrections for the direct value consumer

The [radix-128 integer value map](../value-mass-radix/README.md) has at most 31 high keys per probability row. Giving every row a 32-lane wave nearly erases that arithmetic saving. A fixed layout with eight independent four-lane subgroups per wave instead assigns one row/head to each subgroup. Each lane owns seven of the paid narrow value's 28 coordinates and can form its share of the signed-byte dot from its subgroup's compact high-key list. Subgroups keep separate accumulators; only their four lanes reduce together. The count scan and dense low digit still have to happen. This layout changes no count, value code or output map.

The simple wave-slot model prices divergence rather than pretending eight independent rows run for free. For a subgroup of `L` lanes with `m` candidate keys, it needs `ceil(m/L)` key passes. One wave issues `32 * max_j ceil(m_j/L)` lane slots for its `32/L` adjacent heads at the same query position. It can leave lanes idle. The same formula charges 16, eight and four lanes per head. It counts one coordinate assignment per lane per key, not GPU cycles. The fixed eight-subgroup assignment needs no cross-head atomics or runtime row sorting. At four lanes each lane has seven value coordinates, which fits one signed-byte dot8 operand with a padding coordinate; all 28 coordinates are paid. Addressing the compacted keys, subgroup reductions, probability/count preparation, cache traffic, occupancy and the narrow O projection are not in this count.

`measure.py` replays the existing original-producer Q/K captures and exact prefix-rounded 4,095-count map. It prices both post-scan lists and the conservative `4095*p>=126` pre-scan superset. Four held validation windows per layer have 16,384 query/head rows and 2,105,344 causal key/head pairs. Eight train windows are recorded in the receipts too.

| Held layer | List | Actual candidate keys | Four-lane issued slots | Eight-lane issued slots | 16-lane issued slots | One 32-lane row slots |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 0 | post-scan exact | 75,633 | 176,736 | 186,816 | 262,240 | 524,032 |
| 0 | pre-scan guarded | 76,476 | 178,336 | 188,800 | 262,240 | 524,064 |
| 14 | post-scan exact | 68,350 | 153,760 | 160,416 | 262,144 | 524,288 |
| 14 | pre-scan guarded | 68,907 | 154,944 | 161,920 | 262,144 | 524,288 |

The four-lane arrangement reduces issued high-dot slots by 66.3%/70.7% against one row per wave at layers 0/14. The guarded candidate list costs another 1,600/1,184 slots. Relative to the compulsory dense low dot, four-lane high work is 8.39%/7.30% of its 2,105,344 key/head pairs, versus 24.9% in the one-row-per-wave arm. Even this schedule issues 2.34/2.25 slots per actual high key because independent adjacent heads diverge; it is not an ideal packed list. This is an actionable logical construction, not evidence of a native time reduction. A four-lane subgroup may give back its slot saving in reduction, ballots, scattered nibble loads or registers.

The model/fixture/source-hashed train and held receipts are `/path/to/workspace/data/kelana-subbit/value-high-scheduling/layer{00,14}.json`. Neither the GPU nor Bonsai's runtime was changed. The next native experiment should time four-lane subgroups against a 32-lane row and eight-lane subgroups with the full count scan, guarded pre-scan or post-scan compaction, low/high dots, cache gathers and O reduction at occupied contexts. Separately, the frozen signed-nibble value cache still loses to E4M3 on held post-O error; fit its V/O codes on quantized-producer complete-model behavior before selecting it as an inference path.

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-high-scheduling/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-high-scheduling/measure.py --layer 14
```
