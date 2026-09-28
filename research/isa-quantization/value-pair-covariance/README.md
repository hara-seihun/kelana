# Exact source-only value-pair covariance discriminator

The immutable original Qwen3-0.6B BF16 O tensors are [`../kivi-two-bit-dot-native/original-o.bf16`](../kivi-two-bit-dot-native/original-o.bf16) (layer 0, SHA256 `803995a9d5abb24c72d3ddabd50f4e656fc5eff26efaf3b626f175fc706ab499`) and [`../contextual-value-feedback/original-o.bf16`](../contextual-value-feedback/original-o.bf16) (layer 1, SHA256 `677e1de44f3a28a51b2e75e806a8ec68807ed96dfadc169729c1993181418f48`). Each is 4,194,304 little-endian BF16 bytes, row-major `[1024 output, 2048 input]`. Each of 8 KV heads supplies 128 value coordinates, partitioned into four original contiguous G32 groups, and is served by **two Q heads** in each O layer. No Q/K/V, teacher, events, empirical errors, fitted weights or stochastic law were read or used.

## Provenance of the index correction

The first source study mistakenly took *layer 0* column `h*128+d` and *layer 1* column `h*128+d` as its two Q-head columns. That mixed distinct layers and did not examine either layer's second Q head; its 6,721-edge graph, shared-layer map, and derived coverage were **not evidence for this target**. The corrected artifacts replace those results in place; ordinary Git history retains the provenance. For each layer `L` **separately**, KV head `h`, and within-head coordinate `d=g*32+local`, the two actual Q-head O columns are `O[L][:,(2*h)*128+d]` and `O[L][:,(2*h+1)*128+d]`. This uses all 2048 input columns of each original O tensor. No cross-layer mixing, common-sign assumption or shared-layer map is made.

For each unordered pair `i<j` of *within-KV-head* coordinates in one `(h,G32)` group, [`coefficients.tsv`](coefficients.tsv) supplies 15,872 rows **per layer** (31,744 total) with integers `A=⟨O[L]_{q0,i},O[L]_{q0,j}⟩`, `B=⟨O[L]_{q0,i},O[L]_{q1,j}⟩+⟨O[L]_{q1,i},O[L]_{q0,j}⟩`, and `D=⟨O[L]_{q1,i},O[L]_{q1,j}⟩`, all in the *common exact unit* `2^-70`. The two nonnegative live attention masses `p0,p1` give the pair coefficient `(A p0²+B p0 p1+D p1²)·2^-70`. No normalization of the masses is needed. The `i,j` keys name KV value coordinates (`h*128+d`), **not** raw O column indices; the `layer` key distinguishes the two independent graphs.

Source BF16 exponents lie in `[99,125]`; each nonzero BF16 datum is an integer times `2^-35`, with absolute scaled integer below `2^34`. Each 1024-term dot has absolute bound `<2^78`, and the two-dot B has bound `<2^79`; the C producer's signed `__int128` accumulations cannot overflow. The squared discrimination predicate is computed instead in unbounded Python integers, since its operands can exceed 128 bits.

[`certificates.tsv`](certificates.tsv) supplies exact `4AD-B²` and classification for **every** pair in each layer. `+` means `A,D≥0` and (`B≥0` or `B²≤4AD`); `-` means `A,D≤0` and (`B≤0` or `B²≤4AD`); `zero` means `A=B=D=0`; otherwise `indefinite`. These are exact nonnegative-orthant sign conditions, including boundary cases that tie at some masses, not strict benefit everywhere. The parent's [`ValuePairCoupling.lean`](../../../Kelana/ValuePairCoupling.lean) proves the rational iff, finite shared-head Gram extraction and Fréchet endpoint optimality; [coupling theory](../value-rounding-risk/COUPLING.md) connects that theorem to the source map.

| Layer | `+` | `-` | Zero | Indefinite | Signed graph edges | Chosen `+` / `-` | Matched pairs | Covered coordinates |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 2,790 | 2,918 | 0 | 10,164 | 5,708 / 15,872 | 250 / 262 | 512 | 1,024 / 1,024 |
| 1 | 2,337 | 2,347 | 0 | 11,188 | 4,684 / 15,872 | 255 / 257 | 512 | 1,024 / 1,024 |

The sole predeclared objective is maximum cardinality followed by the lexicographically smallest sorted edge list in ascending `(i,j)` order, **independently in each of 64 layer/head/group graphs**. [`certify.py`](certify.py) uses maximum-cardinality blossom matching with unique descending powers-of-two edge weights: an earlier edge outweighs every possible set of later edges. No outcomes or attentions choose ties. All 64 separate 32-vertex graphs have perfect matchings, independently witnessing global maximum cardinality. The 1,024 chosen edges are in [`matching.tsv`](matching.tsv).

[`pair-map.bin`](pair-map.bin) is the actual **layer-indexed static model-specific byte encoding**: the complete layer-0 map followed by the complete layer-1 map, each in ascending `(head,group)` order. Each group starts with one count byte (`16`) followed by 16 lexically sorted triples `(local_i: uint8, local_j: uint8, sign: uint8)` where local coordinates are `0…31`, and sign is `1` for `+`, `0` for `-`. The layer-0 map occupies offsets `[0,1568)` and the layer-1 map `[1568,3136)`: **1,568 B per O layer, 3,136 B total static model-specific cost**, 196 B per KV head **per layer**, shared across sequences **within** that layer, and 0 B additional map storage per sequence. It does not alter original two-bit G32 V record size or coordinate order. A prospective consumer would use the appropriate layer's sign opposite the coupling covariance endpoint. Source discovery performs 31,744 × 1,024 row iterations and 130,023,424 integer multiplications over the two static O tensors once per model/O revision; no online O dots are needed. This prices the map and discovery, not an unbuilt online sampler or a GPU latency result.

For unbiased two-code marginals, the two Fréchet covariance endpoints bracket zero; choosing the endpoint opposite a fixed-sign coefficient weakly lowers pairwise output variance relative to independent coupling for every `p0,p1≥0`. At zero coefficient or zero attention mass it may tie. Neither the sign certificate nor full coverage guarantees improvement relative to biased deterministic nearest rounding or measures actual model output.

Reproduction:

```sh
gcc -O3 -std=c11 -Wall -Wextra coefficients.c -o /tmp/value-pair-coefficients
/tmp/value-pair-coefficients ../kivi-two-bit-dot-native/original-o.bf16 ../contextual-value-feedback/original-o.bf16 > coefficients.tsv
python certify.py
python verify.py
```

[`verify.py`](verify.py) independently decodes all source BF16 words, checks every certificate integer discriminant and sign predicate, the layer-specific selected matchings and binary entries, and recomputes all **1,024 selected** `(A,B,D)` from arbitrary-precision Python-int O-row dots at the correctly indexed Q-head columns. It checks artifact hashes in [`summary.json`](summary.json). [`coefficients.c`](coefficients.c) is the complete exact source-to-coefficient producer; all 31,744 graph edges can be regenerated and checked against the supplied digests. Signed-zero BF16 is mathematical zero. Input file hashes and shape are asserted by `certify.py` and `verify.py`; the C producer checks dimensions and the exponent bound across all columns.
