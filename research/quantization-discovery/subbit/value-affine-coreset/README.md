# A fixed sparse value cache cannot inherit the 29-key theorem

The [minimum-variance carrier](../value-min-variance-carrier/README.md) already proved that each *individual* rank-28 attention moment has a nonnegative representative on at most 29 cached keys. That representative depends on the query. Here the question is different: can one select a small set of cached keys once per sequence, before queries arrive, and later change only its nonnegative masses? On two frozen Qwen3-0.6B value-cache windows, **every distinct code vector is an extreme point**. An exact fixed-support positive reader for *all* probability rows must retain every distinct vector. At layer 14 this means all 256 keys in every GQA group. The dynamic sparse witness and the query-independent cache are different programs.

## Exact finite-domain bound

Let `c_1,...,c_N` be one group's signed-nibble rank-28 code vectors. A fixed subset `S` is enough to reproduce `sum p_i c_i` with query-dependent nonnegative coefficients summing to one for *every* probability vector `p` on the `N` keys if and only if `conv(c_i : i in S) = conv(c_i : i in 1..N)`. In particular, it must retain at least one key for each distinct vertex of the full convex hull. Necessity follows by setting `p` to the unit mass on an omitted vertex. Sufficiency follows because each point of the full hull has a convex representation on its vertices. Even if attention softmax is required to have strictly positive masses, it can approach each unit mass as a limit of unconstrained logits; a fixed closed convex hull that reproduces every such row must still include each vertex. Actual Qwen queries do not range over arbitrary logits, so this theorem is **not** a lower bound for a learned restricted query domain.

For each distinct code vector the script finds a 28-integer normal `u` such that `u·c_i > u·c_j` for every other distinct vector `j`. Its receipt contains all normals and their minimum strictly positive *integer* separation margins; verifying those dot inequalities with integer arithmetic certifies every vertex, independently of the LP solver's floating feasibility tolerance. The value steps are positive and invertible coordinatewise, so they preserve vertices. Each paid output-head decoder has full rank on these narrow coordinates if one wants to transfer this code-moment bound to that head's real output; the claim here only needs the narrow code moment. Negative mixture coefficients or reconstructing codes from a fixed affine basis change the grammar and evade the bound, but can amplify error and require different online arithmetic.

## Pinned-cache counts

The script uses the first previously inspected 256-token validation window, original-producer hidden states and the frozen paid rank-28 V/O image. It quantizes each appended value with its train-fitted group coordinate steps. Identical codes from repeated tokens are counted once. Every unique code passes the exact integer separation check.

| Layer | Distinct code vectors per group | Necessary fixed keys over eight groups | Duplicate row copies per group | Query-specific sparse moment uses on 64 head queries |
| --- | ---: | ---: | ---: | ---: |
| 0 | 147 / 256 | 1,176 / 2,048 | 109 | 1,190 versus 3,725 positive-mass rows |
| 14 | 256 / 256 | 2,048 / 2,048 | 0 | 1,819 versus 5,711 positive-mass rows |

The last column is a separate dynamic LP replay at positions 63, 127, 191 and 255 for sixteen heads. It targets the pre-existing 4,095-unit integer-mass code moment with arbitrary *real* nonnegative coefficients. Every LP uses at most 29 keys; maximum absolute numerical moment residual is `2.73e-12` / `6.18e-14`. Layer-0 duplicate values explain its smaller fixed set; grouping repeated code rows still needs a key-dependent aggregation of probability masses, and at layer 14 there is no duplicate to exploit. Static index metadata, physical 64-byte lines and cache writes are not priced here. A static 29-key subset cannot be exact on the declared full simplex despite each query having a separate 29-key representative.

The dynamic LP reads every positive-mass value code to construct its constraints. Its 64 small CPU solves take 84.5/91.8 ms on layers 0/14, about 21–23 ms for one sixteen-head query/layer before data movement. Those times are not a GPU performance bound. They show why the existence of a short final dot does not remove the value reads that discovered its support. The next useful construction must exploit *restricted actual query distributions*, learn a key-side selector that predicts useful value representatives without fetching all value rows, or change the V codebook so many keys share convex generators. Test its selected support, complete post-O loss, all cache fetches and selector work on quantized producers. Repeating the 29-key LP with a faster final dot alone cannot save cache traffic.

`fixed_support.py` stores each group's integer separating normals and source, capture, factor and cache-fit hashes under `/path/to/workspace/data/kelana-subbit/value-affine-coreset/fixed-layer{00,14}.json`. `measure.py` stores query-specific support, residual, rank and solver times in `layer{00,14}.json` beside them. Reproduce from a Kelana checkout:

```sh
P=/path/to/workspace/data/fish-s2-pro/venv/bin/python
for layer in 0 14; do
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-affine-coreset/fixed_support.py --layer "$layer"
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=4 "$P" research/quantization-discovery/subbit/value-affine-coreset/measure.py --layer "$layer"
done
```

This is a finite-cache full-simplex semantic bound and a CPU cost warning. No GPU, native latency, complete-model loss, Bonsai executable, serving state or default changed.
