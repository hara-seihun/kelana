# The seven-symbol key-difference alphabet has no frozen-coordinate rate headroom

Could each of the 256 cached K coordinates choose its own seven direct three-bit difference symbols, keeping a five-bit escape for the other 22 values? This would retain the split row layout and its direct two-head score consumer. On the frozen paid Qwen3-0.6B signed-nibble cache, the answer is no. The uniform `-3..3` alphabet is already close to the *held-data oracle* in this fixed-symbol grammar. More static labels add a table lookup to every coordinate's decode and lose after their bytes are charged.

Eight 256-token training windows select the seven most frequent differences in each group or each coordinate. This selection is an exact minimum of total escapes in each partition: every direct label replaces one five-bit escape, with no symbol-specific variable cost. Four previously inspected validation windows supply 1,024 tokens per layer. We also select on those held windows as an oracle diagnostic, never as an inference policy. All arms use the same paid Q/K projection, selected RoPE planes, key norm affine, signed-nibble labels, 32-key restarts and integer score map.

| Frozen layer | Uniform `-3..3` | Train group alphabet | Train coordinate alphabet | Held-coordinate oracle with paid table | Oracle lower bound, table and escape alignment waived | Competing cache |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 126.570 | 126.604 | 127.638 | 127.248 | 126.042 | 112 static mixed |
| 14 | 106.737 | 106.771 | 107.840 | 107.797 | 106.593 | 96.837 packed-directory four-row Huffman |

All rates are bytes/token/layer. The train coordinate alphabet saves only 31 escapes on layer 0 and adds a 1,120-byte static table, or 1.094 bytes/token over these 1,024 tokens. It **adds** twelve escapes at layer 14. Even an oracle that sees the held keys saves only 685/59 escapes on layers 0/14. Waiving the entire table and pooling all escape bits across blocks gives the last column's lower bound. It still loses to the corresponding competing cache before any native parser, lookup, scan or append work. A group-specific alphabet changes no escapes at either layer, and its 35-byte table is pure overhead.

## Exact scope and map

For a 32-key block in each of eight groups, the image has a 16-byte absolute signed-nibble anchor, 31 fixed twelve-byte rows of three-bit difference labels, one group-block five-bit escape stream and a four-byte block offset. Later cache rows do not require another floating key vector. A coordinate alphabet stores seven signed differences at five bits each, 256 sets or 1,120 bytes per layer; one alphabet per group takes 35 bytes. Decode uses the table entry unless the label is seven, in which case it takes the five-bit signed difference. A five-stage row escape-count scan finds the side-stream offsets. An open block can append a fixed row and its escape bits in a group-local stream without moving completed blocks; updates to the two tails and offsets, variable scattered escape loads and the decode are still online costs.

The script encodes and decodes all 256 held group-blocks per layer, checks every absolute key label, and checks two independent integer query score scans for each block. For either real prepared query `u`, `u·c_t = u·c_0 + Σ_{r=1}^t u·d_r`; both heads can consume decoded differences and scan scalar scores without first materializing int4 keys. This identity is exact in real arithmetic; reassociated FP32 scores need not be bit-identical.

For the bound, let `E*` be the number of held differences outside the top seven values of each coordinate, across all windows. Every *fixed per-coordinate* seven-symbol alphabet has at least `E*` escapes. With 256 group-blocks, anchor/offset/fixed-symbol bytes are `256 × (16+4+31×12) = 100,352`. Even sharing one unaligned escape bitstream and granting the alphabet for free requires at least `100352 + ceil(5 E*/8)` bytes. Here `E*` is 45,943/14,078, giving 126.042/106.593 bytes/token on layers 0/14. The bound excludes block-varying alphabets, shorter fixed rows, learned labels, different escape grammar and a changed producer. It says nothing about whether Huffman decoding beats fixed rows on gfx1151.

This closes the frozen alphabet question, rather than sub-bit key coding. Native work should first price the existing packed-directory Huffman reader. A new fixed-row contender needs a paid producer trained to reduce escapes or a genuinely different symbol grammar. Replacing only the seven symbols per coordinate cannot overcome the byte gap, even if the reader lookup were free.

Run with the installed CPU environment:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-coordinate-alphabet/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/key-coordinate-alphabet/measure.py --layer 14
```

`/path/to/workspace/data/kelana-subbit/key-coordinate-alphabet/layer{00,14}.json` contain per-window charged bytes, escape counts, the complete train and oracle alphabets, payload SHA-256 hashes and source/model/capture/paid-image identities. This is CPU original-producer cache evidence. No GPU run, model NLL, Bonsai executable, service or serving default changed.
