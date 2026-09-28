# Shared template plus signed residuals

An additive integer program can beat a scalar scale/code on the right geometry, but the first real Qwen block here does not have that geometry. The result is a useful rejection of a common shortcut: sharing a dot across nearby rows is only valuable when their weight vectors actually share a large component.

## The executable map

Take 128 rows by 128 columns of Qwen3-0.6B layer-0 `q_proj`, originally BF16. For every consecutive group of eight rows, store one signed-int8 template `b[k]`, eight signed-int4 residuals `r[row,k]`, and one FP16 scale `s`. Given a signed-int8 query `x`, compute one shared template dot `t = sum_k b[k] x[k]`, eight residual dots `u[row] = sum_k r[row,k] x[k]`, then `y[row] = float(t + u[row]) * s`. The integer sum is exact; multiplying by `s` remains necessary at this FP output boundary. Across groups with different `s`, an integer-only continuation needs a separately specified common-scale reduction. None is credited here. This is a shared-template additive code, not a new invention of binary expansion.

The template and residual codes are selected offline by scanning FP16 scales. For each scale and coordinate, the encoder checks eleven nearby int8 template choices and picks each row's nearest clipped int4 residual. A candidate minimizes weight squared error. The controls scan 128 FP16 scales per row and choose nearest signed four-, five-, or six-bit scalar codes. In particular, the five-bit control has *independent per-row scales*, not a crippled common scale. This search is finite and deterministic but is not a certificate of optimal quantization over continuous scales or other program families. Both programs reproduce their intended packed codes exactly on decoding.

| 128 x 128 image | Packed weight bytes | FP16 scale bytes | Total bytes | Bits/weight | Online row work |
| --- | ---: | ---: | ---: | ---: | --- |
| scalar4 | 8,192 | 256 | 8,448 | 4.125 | one packed four-bit dot and one scale multiply |
| scalar5 | 10,240 | 256 | 10,496 | 5.125 | one packed five-bit dot and one scale multiply |
| scalar6 | 12,288 | 256 | 12,544 | 6.125 | one packed six-bit dot and one scale multiply |
| int8 template + int4 residual | 2,048 + 8,192 | 32 | 10,272 | 5.015625 | per eight rows one shared byte dot, eight nibble dots, eight integer adds, eight scale multiplies |

The packed images have no padding at these dimensions. The shapes and code conventions are part of the shared format, not model-dependent tables. Row addressing is fixed-width: the candidate reads a contiguous 128-byte group template and 64 bytes of residual nibbles per row; scalar5 reads 80 bytes per row. The additive reader does more integer products, but its shared template dot is amortized over eight rows. Conversion searches and packing happen offline. A consumer which requires floating output pays the final scale in both arms. There are no learned indices, exceptions, transforms or uncharged model-dependent dictionaries.

For any query with `|x[k]| <= 127`, each scalar sum fits signed int32 by `127*128*2^(bits-1)`. The additive sum fits by `127*128*(128+8) = 2,211,840`, even when the template and residual signs align. The measured maxima are recorded separately in `results.json`. No wraparound or saturating arithmetic enters the comparison.

## Observation

The error reference is the original BF16 weight block, converted exactly to FP64 and multiplied by 256 independent uniform signed-int8 queries. The box column is the **exact** worst absolute error per row on the complete `[-127,127]^128` integer box, maximized over these rows: `127*max_row sum_k |W[row,k]-W_hat[row,k]|`. Relative response RMS divides by the original responses' RMS across all queries and rows. Neither is whole-model quality.

| Fixture and format | Weight relative RMS | Probe response relative RMS | Largest row box error |
| --- | ---: | ---: | ---: |
| real Qwen, scalar4 | .114285 | .116002 | 154.5313 |
| real Qwen, scalar5 | .058514 | .059448 | 86.4191 |
| real Qwen, scalar6 | .028817 | .029248 | 46.2355 |
| real Qwen, template + residual | .112068 | .113475 | 79.9622 |
| planted paired rows, scalar4 | .100741 | .099176 | 32.9598 |
| planted paired rows, scalar5 | .050152 | .049586 | 16.9143 |
| planted paired rows, scalar6 | .024580 | .024203 | 8.1429 |
| planted paired rows, template + residual | .006096 | .006091 | 2.0528 |

The planted fixture repeats a Gaussian 128-coordinate template across eight rows and adds independent Gaussian perturbations with standard deviation .0008 to a template with standard deviation .020. It is a witness of the program's intended advantage, not a model measurement. On the real contiguous Qwen rows, group means account for only 13.1% of weight squared energy. The additive code is slightly smaller than scalar5 but almost doubles its sampled response RMS. Its smaller *maximum single-row* box error is a different, worst-row objective, and should not conceal that loss.

## Native CPU cost and limits

`native.cpp` consumes the actual packed scalar5 and additive images, with the same first 64 query vectors. It extracts packed fields inside the timed loops, shares the template dot over eight rows, checks the integer-dot output checksum against the Python map, and applies the FP16 values after exact promotion to float. GCC 15.3 `-O3`, Ryzen AI MAX+ 395, one thread, cache-resident images, eight rotated rounds of 32 repetitions by 64 queries per arm:

| Fixture | scalar5 µs/query | additive µs/query |
| --- | ---: | ---: |
| real | 14.565 | 13.595 |
| planted | 14.673 | 14.594 |

The additive reader is slightly faster than this simple scalar5 unpacker while paying an extra template dot; timings vary across runs and the planted difference is tiny. That is a property of these C++ loops, not a GPU or whole-projection speed claim. Five-bit extraction crosses byte boundaries. An optimized SIMD five-bit reader, two-bit native ternary engine, and packed-float consumer have different instruction costs. Input preparation, host/device transfer, cache misses at model scale, surrounding projections and any next consumer are absent. The approximation is severe on actual Qwen rows, so even a modest CPU loop-time advantage does not make this a useful model representation.

Run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/quantization-discovery/representations/additive-programs/measure.py` from the repository root. It compiles the native reader to a temporary directory and writes `results.json`, including full model/source hashes, fixture seeds, error metrics, integer bounds, and native checksums. The full-model file is read only. The minimal transfer test is to learn groups from a train-only correlation map on one real projection, then check packed bytes, held contextual outputs and the next layer's response at the same boundary. Contiguous-row sharing alone has failed this block.

Earlier [shifted integer scales](../../subbit/binary-shifted-scales/README.md) already remove intermediate floating reductions in a paid binary-factor map; [bitplane dots](../../subbit/binary-bitplane-dot/README.md) and [affine rank centers](../../subbit/binary-affine-rank/README.md) price different additive/offset arithmetic. [Compact scaled FP16](../../../ffn/batched/compact-scaled/README.md) already eliminates a scale epilogue by selecting native FP16 operands for ternary weights. This experiment asks the separate question whether shared *weight-row geometry* buys an additive template program at a five-bit physical budget. It does on the planted pair and fails on the inspected Qwen rows.
