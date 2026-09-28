# Fixed-width phrase codes do not buy a narrow-value reader on this image

The [append-only Huffman rows](../value-row-entropy/README.md) save cache bytes on the frozen Qwen3-0.6B rank-28 signed-nibble V image, but parsing one row follows 224 dependent symbols. I tested a fixed-width phrase code as an alternative: one codeword expands to several signed differences, and a byte- or word-indexed decoder can look up the phrase without following individual Huffman bits. A row is still appended once and addressed by its two-byte block-relative offset. This is a rate and dependency experiment, not a GPU timing claim.

Eight train windows supply a signed-difference histogram for each of eight GQA groups. A deterministic Tunstall expansion repeatedly splits the highest-probability leaf into all 31 possible next differences. Eight, 34 and 136 expansions give 249, 1,021 and 4,081 leaves, indexed with 8, 10 and 12 fixed bits. Each expansion takes two stored bytes: the prior internal-node index and the new symbol. Offline reconstruction of these histories produces the same dictionaries. Each independently decodable group produces exactly 28 differences per key row; a zero-difference suffix completes its last phrase, and the decoder discards symbols beyond 28. Consecutive group codewords are bit-packed together within each row stream. There are one, two, four or eight independent row streams, byte-aligned separately.

The bill includes the 128/544/2,176-byte dictionary histories for 8/10/12-bit codes, the 112-byte absolute nibble anchor and four-byte block address per restart, two-byte offsets for non-anchor rows, one-byte lengths for every stream except the last, and all phrase padding and byte alignment. The script packs and decodes each held stream, checks every difference against the frozen image, reconstructs each dictionary from its stored history, and retains payload hashes. Four previously inspected validation windows provide 1,024 cached keys per layer.

| Layer | Phrase bits | Restart | One row parser, B/token | Eight group parsers, B/token | Mean phrases/group/key | Static nibble, B/token | Huffman one/eight parser, B/token |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 8 | 32 | 130.317 | 137.099 | 16.081 | 112 | 104.940 / 114.672 |
| 0 | 10 | 32 | 126.754 | 136.298 | 12.417 | 112 | 104.940 / 114.672 |
| 0 | 12 | 32 | 124.850 | 132.998 | 10.058 | 112 | 104.940 / 114.672 |
| 14 | 8 | 32 | 128.613 | 135.395 | 15.861 | 112 | 102.092 / 111.817 |
| 14 | 10 | 32 | 124.683 | 133.616 | 12.204 | 112 | 102.092 / 111.817 |
| 14 | 12 | 32 | 123.154 | 131.631 | 9.911 | 112 | 102.092 / 111.817 |

At width 256, the best 12-bit one-parser rows cost 125.041/123.306 B/token on layers 0/14; eight parsers cost 133.415/132.027. The longer restart does not rescue phrase coding. Even *without* the 2,176-byte dictionary, the width-32 layer-14 one-parser image costs 121.029 B/token, 9.029 above static nibble. The group end padding is paid. The 12-bit group parser follows about ten phrase lookups rather than 28 individual Huffman transitions on average, but its 131.631 B/token at layer 14 exceeds static nibble by 17.5% and appendable Huffman groups by 17.7%. It cannot win cache traffic on this frozen image, before lookup, suffix scan and producer costs. Increasing phrase width without changing the labels must earn back both its growing table and this deficit; the 8/10/12-bit trend alone proves no bound on wider trees or contextual phrase models.

There is a useful addressing guarantee at the 32-key restart. Each phrase emits at least one difference, so a group uses at most 28 codewords. At 12 bits, a row uses at most `ceil(224*12/8) + 7 = 343` bytes including seven stream lengths, and the whole block at most `112 + 2*31 + 31*343 = 10,807` bytes. Two-byte row offsets suffice for *every* signed-nibble history in this grammar. Each stream other than the last has at most 112 symbols and thus at most 168 bytes, so its one-byte length is also valid. This bound covers append addressing, not rate: worst-case reserved slots would lose badly. The observed 256-key blocks also fit two-byte offsets, but the worst-case block can exceed 65,535 bytes and would need a guarded restart.

The integer suffix-mass value identity from the Huffman row study applies to the decoded differences, without reconstructing absolute values. The equality is in integer arithmetic, not FP32 reduction order. The paid V/O factor, weight BPW and model quality do not change. No native time, whole-model loss, GPU reservation, Bonsai binary or serving service changed. The useful next native question remains the one/two-parser Huffman row consumer against static nibble and E4M3, including append, count preparation, backward mass scan and output projection. A fixed-width dictionary on these frozen labels does not earn its cache traffic. A different producer may learn lower-entropy phrase transitions; that would be a new quality/rate fit, not a larger tree on this image.

Run from a Kelana checkout, one layer per command:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-phrase-stream/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-phrase-stream/measure.py --layer 14
```

The receipts in `/path/to/workspace/data/kelana-subbit/value-phrase-stream/layer{00,14}.json` retain the train histograms, expansion histories, all charged per-window bytes, mean phrase counts, maximum observed row/block sizes, hashes of the packed payload and table, and source/model-capture/factor/parent hashes. The source and receipts are the precise observation grammar for this measured negative.
