# An exponent ladder as a quantization alphabet

A block can store three-bit codes for `{0, ±2^e, ±2^(e+1), ±2^(e+2)}`. The base exponent `e` is shared by the block. Unlike scaled ternary, the code chooses *which magnitude* to use, and its FP16 operand is assembled from its exponent and sign bits. No scale multiplication or per-block integer drain belongs to the FP16 dot. This is a proposed quantization family and an exact finite-domain comparison, not a measured kernel or a model replacement.

## Operand and payment

For `-14 <= e <= 13`, all three nonzero magnitudes are normal FP16 powers of two. Assign codes `0..7` to `0, +1, +2, +4, -1, -2, -4, 0`, multiplied by `2^e`. The eighth code is another zero, not a free extra magnitude. For positive rung `j`, its FP16 high byte is `((e+15+j)<<2)`; the negative rung sets bit 7. The low byte is always zero. Two prepared 32-bit registers hold the eight high bytes. A byte-permute with selectors `[0,c0,0,c1]` constructs two FP16 operands per output word, once the packed three-bit codes have been extracted. `exact.py` checks all 28 base exponents and all eight codes against actual FP16 bit decoding. The exponent is still model metadata. Calling this a scale-free format would be misleading: its five-bit base specifies the absolute magnitude, but it does not represent an independently fitted real multiplier.

With ordinary byte-aligned storage a group of 128 weights uses 48 code bytes and one exponent byte, or 49 bytes, 3.0625 effective bits per weight. A symmetric seven-level scalar grid uses the same 48 code bytes plus one FP16 scale, or 50 bytes. Compact scaled ternary uses 26 trit bytes plus two scale bytes per 128 weights in its original layout; its two-bit-kernel layout instead uses 32 plus two. The ladder pays materially more than ternary. The full-model table must also account for padding, row layout, prepared tables if stored rather than regenerated, and every group's exponent.

The operand route can reuse an FP16 dot with one FP32 accumulator across K, as [compact scaled FP16](../../ffn/batched/compact-scaled/README.md) already does. That work folds ternary scales into selected FP16 operands; merely moving a scale into a table is *not* the new result here. The different seven-value alphabet is. The high-byte selection may save one permute per two operands against a generic scaled seven-level grid whose low bytes vary. But some scalar scales, including the fitted control below, also give all-zero low bytes. Packed three-bit extraction crosses byte boundaries, exponent-table preparation costs work, and FP16 WMMA has unchanged issue demand. Neither instruction nor time superiority follows. An affine grid may also prepare its eight FP16 operands and avoid an online offset correction. This experiment does not price a native kernel.

## Exact consumer comparison

Use the full real input box `x_i in [-1,1]` and target row `w`. For a candidate row `v`, the maximum linear-response error is exactly `sum_i |w_i-v_i|`: choose every `x_i` as the sign of its coefficient error. This is a robust, whole-row response objective, not a per-weight squared error or a sample fit. It is also the box identity already proved in [MATHEMATICS.md](../../quantization-discovery/MATHEMATICS.md); the novelty is the executable exponent alphabet, not the norm identity.

For `w=(-4,-2,-1,1,2,4)`:

| family | exact best box error | fitted values | payload for six weights |
| --- | ---: | --- | ---: |
| exponent ladder, `e=0` | 0 | `(-4,-2,-1,1,2,4)` | 3 code bytes + 1 exponent byte |
| fitted symmetric ternary, real scale | 6 | `(-2,-2,0,0,2,2)` | 2 code bytes + 2 FP16 scale bytes |
| fitted symmetric seven-level scalar, arbitrary rational scale | 2 | `(-3,-2,-1,1,2,3)` | 3 code bytes + 2 FP16 scale bytes |
| fitted eight-level affine grid, arbitrary rational offset and step | 1 | `(-4,-2,-1,1,2,3)` | 3 code bytes + 4 FP16 metadata bytes |

The rational-parameter controls are *stronger* than FP16-constrained fitting. The affine control's optimum happens to use FP16-representable offset `-4` and step `1`. These are exact global minima within the named families, not nearest rounding at a guessed scale. In particular a seven-level symmetric grid cannot contain all six signed powers, and an eight-level affine grid cannot contain them all: its range of 8 forces a step of at least `8/7` across seven intervals, but representing both `-2` and `-1` forces an integer multiple of that step to equal 1. The search gives the sharper positive errors in the table.

`exact.py` finds the symmetric optimum by checking zero and every `|w_i|/k`, `k=1..3`. For fixed codes, the absolute-error sum in the scale is piecewise affine and has a minimum at one of those breakpoints. It finds the affine optimum by checking the `step=0` boundary and pairwise intersections of `offset+step*q=w_i` for integer `q=0..7`, retaining `step>=0`. For fixed codes this is a two-variable piecewise-affine objective; a minimum has a representative on that finite set. At each candidate, it independently assigns the nearest permitted code. The ladder checks every legal normal FP16 base exponent and optimizes each code independently. All scoring and search use exact rational arithmetic.

A uniform-friendly counterexample matters: for `(-3,-2,-1,1,2,3)`, the ladder's best error is 2 while both fitted three-bit grids score zero. On 48 seeded, unstructured six-weight rational rows, the ladder wins 10, ties 5 and loses 33 against the symmetric grid. Against the freely fitted affine grid it wins 0, ties 3 and loses 45. The ladder beats fitted ternary on 40, ties 4 and loses 4. These are counts for this generator, not estimates for trained weights. The six-rung witness shows a structural option; the unstructured control emphatically does not justify replacing a scalar three-bit image wholesale.

## Next decision

Measure whether actual 128-weight groups have enough signed dyadic spread to beat a fitted scalar three-bit grid on held producer responses, and whether a three-bit reader plus table preparation pays off at an actual consumer tile. Keep both comparisons at the same byte accounting and activation producer. If it cannot beat the scalar control on relevant groups, preserve this exact construction as a specialized codebook option rather than growing the search.

Replay from the Kelana root with `OPENBLAS_NUM_THREADS=1 python3 research/isa-quantization/magnitude-placement/exact.py > research/isa-quantization/magnitude-placement/results.json`. The checked-in JSON contains every weight row, chosen parameters, exact fitted responses and the aggregate counts. This work makes no claim about native FP32 summation order, throughput or full-model loss.
