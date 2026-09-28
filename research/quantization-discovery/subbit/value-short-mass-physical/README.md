# Short probability mass barely skips physical value rows

The frozen rank-28 signed-nibble V/O image has a useful direct two-digit consumer: a train-selected subset of heads uses conserved mass 255 instead of 4,095. At layer 0 this halves modeled packed-dot slots at less than 1e-4 held relative squared output error against the all-4,095 map. But a shared one-parser Huffman value row is still requested if *any* of sixteen heads has a positive count. On four previously inspected 256-token Qwen3-0.6B validation windows, the selected mass policy saves just **0.44%** of cold 64-byte lines at layer 0 and **0.32%** at layer 14. Lower arithmetic does not imply lower physical cache traffic in this layout.

The [255-mass parent](../value-nibble-255/README.md) selected 15/16 short heads at layer 0 and 4/16 at layer 14 on eight train windows, at a 1e-4 train relative squared error budget. Its held errors are .00008794/.00006063. We retain those masks, its 4,095 and 255 prefix-rounded counts and the [absolute Huffman parent](../value-active-entropy/README.md)'s paid cache codes, one-bank/four-table canonical lengths, row order and four-byte directory. No new cache or fitted table is chosen on validation. The zero-count exposure alone changes.

| Layer | Mass policy | Physical rows visited / 131,584 | One-parser decoded prefix B/query | One-parser cold 64B B/query | Eight-parser cold 64B B/query |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | all 4,095 | 131,577 | 10,293 | 11,958 | 13,247 |
| 0 | selected 255 | 130,585 | 8,922 | 11,905 | 13,186 |
| 0 | all 255 | 124,323 | 8,592 | 11,542 | 12,749 |
| 14 | all 4,095 | 130,450 | 11,486 | 13,243 | 14,502 |
| 14 | selected 255 | 130,088 | 11,023 | 13,201 | 14,444 |
| 14 | all 255 | 104,504 | 7,362 | 10,944 | 11,774 |

The 4,095 controls reproduce the earlier independent row, prefix and line receipts exactly. The one-parser charged rate is fixed at 92.851/104.100 bytes per key, against 112 for static nibble; eight parsers charge 102.879/114.167. A shared parser processes every requested row through all eight groups. Eight group-local parsers skip more *logical prefix bytes*, but their headers, directory and separate 64-byte starts still increase cold lines over the shared parser in every arm. At layer 0 the selected policy reduces decoded prefix bytes 13.3%, yet reduces cold lines only 0.44%. The all-255 layer-14 arm saves 17.4% of modeled lines, but the parent measures .005709 held relative squared output error against all-4,095 there, compared with .000061 for the selected arm. It cannot be counted at the selected arm's quality.

The comparison counts unique 64-byte lines within each query, including row directory entries, length headers and the parsed prefix through the last active group. It assumes cold lines between queries; cache reuse may change the actual traffic. Prefix-rounded counts conserve mass separately per head. The exact integer value response consumes those counts and the frozen labels directly without expanding a cache into int4, but the two masses are different approximate attention maps. None of these byte figures includes softmax, count construction, key-index compaction, table parsing instructions, paid V/O work or model-quality propagation. They are CPU physical-read models, not native latency. This result does not rule out a cache layout whose rows are independently addressed per group, a jointly learned support policy, or long-context compaction where a 255-count head has at most 255 nonzero keys.

The next short-context cache question is *not* whether a small mass automatically makes a shared parser sparse. Either price the complete fused one-parser reader at occupied context against nibble and E4M3, or jointly fit a value basis, mass policy and group-local cache placement on quantized-upstream text. A cheap probability mass that remains dense after the group union is an arithmetic choice, not a memory choice.

`measure.py` replays both frozen probability maps and reuses the parent rate and line accounting. It writes source-, model-, capture-, factor- and parent-input-hashed receipts at `/path/to/workspace/data/kelana-subbit/value-short-mass-physical/layer{00,14}.json`. Each layer runs as a bounded CPU job from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-short-mass-physical/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-short-mass-physical/measure.py --layer 14
```

No GPU, Bonsai executable, service or serving default changed.
