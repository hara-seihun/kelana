# Coordinate-conditioned narrow-value entropy and the append bill

The [one-table-per-group Huffman value cache](../value-entropy-ceiling/README.md) compresses frozen signed-nibble temporal differences, but a long coordinate stream cannot be appended in place without either slack or relocation. This study asks whether specializing the prefix tree to the coordinate buys enough bits to fund that access. It does not change the paid rank-28 V/O image, its signed-nibble labels, weight BPW or post-O quality.

Eight Qwen3-0.6B train windows fit code lengths. Within each GQA group, coordinates are ranked by their train difference entropy and divided evenly into one, two, four or 28 buckets. Each bucket pools its coordinates' train histogram, adds one pseudocount to each of the 31 possible differences, and builds a canonical Huffman tree. Four previously inspected 256-token validation windows determine payloads. Bucket IDs cost 28/56 bytes per layer for two/four buckets; tree lengths cost 310/620 bytes, against 155 bytes for the parent. The four-bucket decoder changes its tree at each known coordinate position in a group stream; independently parsed coordinate streams use one tree throughout each stream. Actual four-bucket streams are packed and round-tripped, including that changing-tree group decoder.

| Layer | Restart | Layout | Parent one table, B/token | Best conditioned, B/token | Tables/group | Static nibble, B/token |
| ---: | ---: | --- | ---: | ---: | ---: | ---: |
| 0 | 32 | serial group | 103.364 | 102.682 | 2 | 112 |
| 14 | 32 | serial group | 101.415 | 99.845 | 4 | 112 |
| 0 | 256 | independent coordinate | 104.128 | 103.422 | 2 | 112 |
| 14 | 256 | independent coordinate | 102.146 | 100.540 | 4 | 112 |
| 14 | 32 | independent coordinate | 111.397 | 109.799 | 4 | 112 |

Each listed rate includes a 112-byte absolute anchor and four-byte offset per block, stream byte alignment, 224 one-byte coordinate lengths per independently parsed block, and the once-per-layer tables and assignments divided across the 1,024 held tokens. The layer-14 four-bucket coordinate width-256 payloads are 25,281, 25,596, 25,909 and 25,491 bytes per held window, before the 676 metadata bytes once. One table per coordinate loses after its 4,340 metadata bytes: layer-14 width-256 coordinate streams cost 103.316 B/token. These savings are a better *compressed payload*, not a cheaper consumer. A width-256 coordinate parser still follows 255 variable-length transitions before reaching the latest difference, and the consumer still needs the backward suffix-mass scan. A group parser switches trees per coordinate and carries a serial chain across all 28 coordinates.

## An exact fixed-slot access bound

A simple appendable layout gives each coordinate its own fixed-size slot inside each restart block. A new difference can extend its stream in place; blocks have fixed addresses, with no relocation or secondary overflow. How large must those slots be if *every* signed-nibble history is valid? For a fixed Huffman tree with lengths `L[d]`, form the 16-state edge matrix `A[a,b]=L[b-a]`, for `a,b` in `{-8,...,7}`. Start all 16 anchor states at zero and take `B-1` max-plus steps. The largest terminal value `M_B` is exactly the longest valid difference-code stream in a B-key block. The induction includes the key-label range and temporal reachability, unlike multiplying the longest codeword by B. Therefore `ceil(M_B/8)` bytes per coordinate is the *minimum* fixed independent slot in this grammar. Summing those slots, anchors, four-byte offsets and static tables gives:

| Layer | Restart | Table choice | Observed coordinate stream, B/token | Exact fixed-slot minimum, B/token |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 32 | 2/group | 112.600 | 393.330 |
| 14 | 32 | 4/group | 109.799 | 356.254 |
| 0 | 256 | 2/group | 103.422 | 398.744 |
| 14 | 256 | 4/group | 100.540 | 361.504 |

The huge difference comes from rare but valid transitions, not an extrapolation from held text. Even a separate tree for every coordinate gives fixed-slot minima of 305.051/301.738 B/token at width 32 on layers 0/14. This is a bound on *independently addressed, fixed-capacity, no-overflow slots with these code lengths*. It is not a bound on a paged allocator, split common/exception streams, a learned low-difference producer, or all possible lossless codes. The rate-optimal packed layout is not append-ready; the immediately appendable fixed-slot layout loses to static nibble by more than 2.6x. Repeating an offline Huffman-rate sweep without charging append will not decide a native reader. The next construction should fit the V producer and output decoder with a streamable code, or use an overflow/page scheme and measure its pointers, allocations, write amplification, suffix scan and fused native dot against static nibble and E4M3.

The semantic observation is unchanged. For one coordinate and block anchor `a=c_0`, `d_j=c_j-c_{j-1}`, and integer masses `m_t`, the response is `a sum_t m_t + sum_{j>0} d_j sum_{t>=j} m_t`. Canonical decoding recovers every signed difference before that exact integer suffix consumer. This identity does not assert bit-identical FP32 accumulation or a quality win over E4M3. No GPU, native latency, whole-model loss, Bonsai executable or service state changed.

`measure.py --layer 0` and `--layer 14` each run on CPU within the session command limit. `/path/to/workspace/data/kelana-subbit/value-coordinate-entropy/layer{00,14}.json` retains train bucket assignments and code lengths, every held per-window payload, encoded stream SHA-256, source/capture/factor/parent hashes, and the exact max-plus slot lengths. Run from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-coordinate-entropy/measure.py --layer 0
OPENBLAS_NUM_THREADS=2 OMP_NUM_THREADS=8 "$P" research/quantization-discovery/subbit/value-coordinate-entropy/measure.py --layer 14
```
