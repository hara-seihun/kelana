# Mixed absolute and difference value rows buy too little on frozen labels

An absolute narrow-V row can be parsed when its integer attention mass is positive; temporal differences compress later Qwen3-0.6B labels better, but their direct consumer carries a suffix mass through zero-count gaps. I tested a rowwise mixture on the same paid rank-28 V/O image. The layer-14 mixture saves 1.052 bytes/token against the existing temporal-row image, but increases the number of parsed rows by 16.6% against pure absolute coding on the inspected attention workload. At layer 0 pure absolute coding wins on both bytes and work. A native mixed reader for these frozen labels is a poor next experiment. A jointly trained producer would need a much larger byte margin or long absolute runs selected for the actual mass distribution.

Eight training windows fit both existing canonical Huffman families: four entropy-ranked absolute-label tables per GQA group and the layer's two/four difference-label tables per group. At append, encode each 224-coordinate row under both tables and retain the shorter byte-aligned body; ties choose absolute, and the first row is absolute. The two families and their coordinate assignments are charged once across four previously inspected 256-token validation windows. A 32-bit relative row directory, 32-byte mode bitmap and four-byte block address are charged per window. The maximum code lengths are 11 and 16 bits, so even a block of 256 rows encoded at the larger 16-bit bound fits in `1024 + 32 + 256*448 = 115,744` bytes, within the 32-bit directory for every signed-nibble history. At two or four parsers, a nonfinal stream spans at most 112 symbols and its one-byte stream length fits even at 16 bits/symbol.

| Layer | Parsers/row | Mixed bytes/token | Absolute bytes/token | Difference bytes/token | Mixed absolute/difference rows |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 1 | 93.223 | **92.851** | 104.606 | 1,008 / 16 |
| 0 | 2 | 94.646 | **94.288** | 106.003 | 1,008 / 16 |
| 14 | 1 | **100.661** | 104.100 | 101.713 | 443 / 581 |
| 14 | 2 | **102.104** | 105.499 | 103.151 | 446 / 578 |

The 112-byte static nibble cache is larger than every one-parser arm here. The layer-14 byte improvement against temporal rows is only 1.03%, and the mixed image needs *two* code tables and a mode branch. Rowwise byte selection is the exact minimum of these two frozen row bodies with this fixed mode and directory grammar. It does not minimize decode time, model loss or bytes under a jointly trained code family. The four-parser mixed results and each window's charged bytes are in the receipts.

There is an exact direct integer consumer. Let `a_t` mark an absolute row, let `c_t` be its 224 signed-nibble labels, and let `n_t` be a conserved nonnegative 4,095-count attention mass. For a difference row store `d_t=c_t-c_(t-1)`. Partition the history into runs starting at absolute rows. Within a run beginning at `s` and ending just before the next absolute row at `e`, the response is

```
    sum_(t=s)^e n_t c_t
      = c_s sum_(t=s)^e n_t + sum_(j=s+1)^e d_j sum_(t=j)^e n_t.
```

Thus neither a floating value vector nor an absolute reconstruction is needed. The script checks packed row round trips and this integer response on every held row with a deterministic mass sequence. It also computes prefix-rounded 4,095-count masses from the actual original-producer Q/K captures. Across four windows per layer there are 2,105,344 causal query/head/key positions. At layer 14, 1,330,127 have nonzero mass. Pure absolute coding parses that many rows; mixed coding parses 708,330 absolute anchors and 842,166 differences, or 1,550,496 total. A nonzero count can activate earlier zero-count difference rows in its run, and an absolute anchor can be needed even when its own mass is zero. The longest observed distance between absolute rows is 18, but there is no universal constant-gap promise in this format. At layer 0, the mixture parses 1,012,700 rows against 1,009,996 for pure absolute.

The row directory and probability/count construction still inspect all causal positions. The mixed consumer additionally pays a backward suffix scan, two Huffman tables, a mode branch, gathers, and an append-time comparison of both encodings. The parser counts exclude these costs and do not prove native latency. Frozen labels and the integer response preserve the same *lossy cache map* as the parents, but changing floating accumulation order is not bit-identical FP32 execution. No GPU, full-model loss, executable or service changed.

A better next question is whether a producer trained for short absolute labels and sparse-mass response can preserve the layer-0 byte advantage on quantized-upstream text, or whether a native absolute-only reader at long occupied context beats nibble/E4M3 after append, mass formation, indexed parses and paid O. Layer 14's 1.052-byte mixed saving does not justify that more complicated native reader on its own.

From a Kelana checkout, each CPU command finishes in a bounded panel:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-absolute-work/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-absolute-work/measure.py --layer 14
```

Receipts under `/path/to/workspace/data/kelana-subbit/value-absolute-work/layer{00,14}.json` retain source, capture, factor, parent, payload hashes, both paid table byte counts, per-window bytes, row-mode counts and measured parser counts. This is CPU original-producer evidence on repeatedly inspected validation windows, not fresh model quality.
