# Sparse temporal value rows do not buy a frozen-cache consumer

The paid rank-28 Qwen3-0.6B V/O cache changes in most coordinates on every token. A sparse temporal code would let a value response skip zero differences, but this frozen image does not have enough zeros. Four inspected 256-token validation windows at layers 0 and 14 have nonzero fractions .828 and .814 between adjacent signed-nibble rows. The decisive result is a byte floor: even if the positions of every nonzero difference were free, storing each signed difference in five bits, plus the append-only block anchors and row directory, takes **117.827/115.926 bytes per token** at 32-key restarts. Static signed-nibble values take 112. Position encoding, parsing and online response work only widen the gap.

This closes fixed-five-bit sparse differences on the existing labels, not temporal value coding generally. The train-fitted appendable Huffman row stream already costs 104.940/102.092 bytes per token at width 32 and 104.606/101.713 at width 256 on these layers. It gives the more useful native question: whether one or two variable-length row parsers plus suffix mass and the paid O response outrun static nibble and E4M3. Making sparse differences worthwhile instead requires changing the paid V producer and its signed labels to increase exact repeats while fitting the composed post-O response, not adding another zero-run format to these frozen codes.

## Declared map and bound

Each GQA group stores 28 signed-nibble coordinates `c_t`. A block starts with the same 112-byte packed eight-group anchor as the appendable Huffman comparison, a four-byte global block address, and two bytes per later row for its relative offset. Rows append into a block arena without moving old rows. For an integer attention mass `m_t`, the direct response is

```text
sum_t m_t c_t = c_0 sum_t m_t + sum_{j>0} (c_j-c_{j-1}) sum_{t>=j} m_t.
```

Substitution and interchange of the two finite sums prove the identity over every signed-nibble history and integer mass row. A 224-coordinate held example also checks the entire response exactly. Both observing heads use the same stored differences with their own suffix masses. The result does not claim bit-identical FP32 reduction order. The right V factor, nibble steps, output factor and all model quality are unchanged.

Let `N` be the observed number of nonzero coordinate differences over the four held windows. At restart width `W`, four windows use `4(256/W)(112+4)` anchor/address bytes and `2*4(256-256/W)` directory bytes. A fixed signed-five-bit nonzero payload costs at least `ceil(5N/8)` more bytes even with a free position oracle, no stream boundaries, no table and no parser. At width 32, layer 0 has `N=183,933` and needs 117.827 B/token; layer 14 has `N=180,819` and needs 115.926. Beating the 112-byte static cache requires at most 174,387 nonzeros over the same four windows. At width 256 the observed `N=189,141/185,974` yields 117.889/115.955 B/token, versus a threshold of 179,494. These are exact lower bounds for *fixed-five-bit nonzero values with the stated independently appendable block boundary*. Entropy coding nonzero magnitudes is outside that grammar and is precisely why the existing Huffman rows can win.

## Charged alternatives on the frozen labels

Eight train windows fit one 60-symbol canonical Huffman table per group for a zero-run/value format. Four previously inspected validation windows supply the image rates below. Every row payload round-trips; the block pays the same anchor, address and two-byte row directory as above. Each of eight independently addressed group streams is byte-aligned, with seven one-byte lengths per row. The run format charges 300 table bytes/layer, one five-bit length for each possible run or nonzero difference. The table maximum depth fits five bits on these train windows.

| Layer | Width | 28-bit group masks + 5-bit values | 5-bit count/index/value | Huffman zero-run/value | Prior appendable Huffman rows | Static nibble |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 32 | 155.440 | 245.537 | 161.164 | 104.940 | 112 |
| 0 | 256 | 156.565 | 249.217 | 162.445 | 104.606 | 112 |
| 14 | 32 | 153.401 | 241.788 | 159.502 | 102.092 | 112 |
| 14 | 256 | 154.486 | 245.397 | 160.741 | 101.713 | 112 |

Bytes/token include table costs amortized over the 1,024 held tokens. Indexed rows have up to 28 entries/group; 28 fits their five-bit count. A run reader handles about `2N + 8` dependent symbols per key row across eight groups, versus 224 difference symbols for the previous Huffman reader. Its logical difference products can skip 17.2%/18.6% of coordinate work on layers 0/14, but the extra parsing, directory and bytes make a native reader pointless for these labels. Maximum observed block sizes and stream lengths appear in the receipts; the 16-bit relative directory is not a full-domain capacity guarantee at width 256. No GPU, native timing, model loss or Bonsai executable changed.

`measure.py --layer 0` and `--layer 14` regenerate the CPU results in under a minute per layer. `/path/to/workspace/data/kelana-subbit/value-zero-run/layer{00,14}.json` retains per-window bytes, lower bounds, nonzero counts, maxima, encoded payload hashes, train/source/capture/factor/parent identities and the exact integer response hash. Use the installed ROCm PyTorch environment with CPU threads bounded:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-zero-run/measure.py --layer 14
```
