# Correct A7 byte-table carries in a sparse second pass

The exact masked-byte four-sign reader tests an exception bit at **every** selected lookup even though only 0.6–0.9% of the paid Qwen sign selections actually need a carry. There is a different schedule for the same integer map: read only wrapped signed bytes on the main pass, and revisit output signs only for four-sign tables whose eight prepared entries contain a carry. On four paid `mlp_up` factor images, the second pass inspects 4.25–6.06% as many sign quartets as the main pass makes byte lookups. This is a counted candidate for a native reader, not a latency claim. It avoids a per-lookup mask test without pretending that sparse output scatters are free.

## Exact construction

For each activation quartet `q ∈ [-64,63]^4`, prepare the eight relative-sign responses `T_j`, wrapped signed bytes `b_j`, and carries `e_j ∈ {-1,0,1}`:

```
T_j = q0 + s1(j)q1 + s2(j)q2 + s3(j)q3
b_j = ((T_j + 128) mod 256) - 128
e_j = 0                       if -128 <= T_j <= 127
    = -1                      if T_j < -128
    = +1                      if T_j > 127
T_j = b_j + 256 e_j
```

The direction also follows from the wrapped byte's sign and the one-bit exception mask, as in the [parent masked-byte proof](../binary-a7-exception-table/README.md). Let a static output row's four factor signs be `u`, with relative-sign table index `j(u)`. Its quartet contribution is `u0 b_{j(u)} + 256 u0 e_{j(u)}`. The main pass accumulates only the first term. While preparing a table, put its quartet position on a short active list iff some `e_j` is nonzero. A second pass visits the packed factor signs of every output row only for those positions and adds `256 u0 e_{j(u)}` into the **same group accumulator** before applying that group's A7 integer ladder weight. The first factor's completed integer response feeds the ordinary second quantizer; repeat the construction for the second factor. No weight, int4 intermediate, or floating result is reconstructed to decide a carry.

This is exact for the selected two-stage integer A7 map, with group weights and factor outputs in the same integer arithmetic as the existing reader. It does not claim FP32 bit equality after replacing a real-valued model projection. The proof is distributivity of the displayed identity within each 32-coordinate group. The measured `int32` program checks every paid output on all 64 inputs per layer, including both group-weighted factor stages. A native implementation must preserve accumulator range and the original group-weight multiplication order.

The active list needs at most 352 quartet IDs for one `K=1024, R=384, N=3072` up projection, namely 256 first-stage and 96 rank-stage tables. An uncompressed two-byte-ID list needs at most 704 temporary bytes/input; the measured lists contain 13.86–15.39 IDs/input. Eight byte entries and a one-byte exception mask per table remain the prepared table representation. Two carry-direction masks are optional; reading the wrapped byte on an active selection recovers the direction. No model-specific metadata or changed weight bits are required.

## Paid sign panel

Pinned Qwen3-0.6B `.55` binary factor images at layers 0/7/14/27, original-producer validation rows 960:1024, and the parent's safe `.75` two-boundary A7 ladder. The counts cover *both* factors. A scan is one output row inspecting its static sign quartet for one active table; it is not a GPU instruction or cache-line count. Every arm performs 25,165,824 main-pass byte selections over these 64 rows. The parent's in-line masked arm tests that many exception bits. The sparse arm instead prepares active table IDs and performs the counted sign inspections, followed by the same number of nonzero carry updates the parent reports.

| Layer | Active tables / 22,528 | Second-pass sign inspections | Inspections / byte selections | Nonzero carry updates |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 906 | 1,229,568 | 4.886% | 175,402 |
| 7 | 960 | 1,158,912 | 4.605% | 165,311 |
| 14 | 887 | 1,069,056 | 4.248% | 157,547 |
| 27 | 985 | 1,526,016 | 6.064% | 222,882 |

Layer 0's first factor accounts for 221,952 inspections and 32,768 updates; the rank factor accounts for 1,007,616 and 142,634. The latter matters far more because its active quartet must be checked against 3,072 rather than 384 output rows. The per-stage counts and complete weighted-response hashes live in `/path/to/workspace/data/kelana-subbit/binary-a7-carry-fold/layer{00,07,14,27}.json`, alongside source, paid-image and activation-fixture hashes.

A good native comparison must include the extra traversal of packed U/V signs, active-list preparation, irregular output updates or a reduction buffer, both A7 quantizers, the rank intermediate and output scales. The second pass saves roughly 94–96% of per-lookup carry *tests*, not 94–96% of inference work. There is also a meaningful unfavorable limit: if every quartet table is active, this schedule scans every output sign quartet in addition to making every byte lookup, so the in-line masked reader wins on this axis. The active-table list provides a cheap per-input selector between the two schedules, but the dispatch and occupancy bill must be measured before such a switch ships. Compare this complete reader against the parent's uniform int16-four and byte-two readers on gfx1151. If a sparse pass loses to sign re-reads and scatters, keeping the uniform masked lookup is the correct choice; training signs for lower active-table *incidence* then matters more than lowering exceptional use frequency alone.

Reproduce one layer from a Kelana checkout:

```sh
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=2 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/subbit/binary-a7-carry-fold/measure.py --layer 0
```

This is CPU integer-map and counted-work evidence. No GPU, whole-model NLL, native executable, serving default or service changed.
