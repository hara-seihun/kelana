# The query-side cost of a pre-RoPE rank-one key cache

A pre-rotation code escapes the fixed-decoder orbit bound: for keys `k_t = a_t b`, cache only `a_t` and let each query compute `a_t qᵀ R_t b`. This removes 127 of 128 logical key scalars per token. It does **not** give a one-scalar per-key score program. The score as a function of position has 128 independent oscillatory modes even for this rank-one producer. Here is an exact lower bound for the natural shared linear recurrence, together with its matching construction.

## Contract and result

Use real arithmetic, Qwen3-0.6B's 128-dimensional RoPE planes `(j,j+64)`, and integer positions. Set `ω_j = 1000000^(-j/64)`, `j=0,...,63`. For a fixed query `q` and nonzero basis `b`, let `s_t = qᵀ R_t b`, and suppose that `q` and `b` each have nonzero magnitude in every common RoPE plane. A stationary real linear recurrence prepares a state `v(q,b) ∈ R^d` once per query and then emits consecutive scores via `s_t = uᵀ A^t v`, with fixed `A,u` for this pair. If it emits positions `0,...,254` exactly, then **`d ≥ 128`**. A 128-state oscillator attains equality. The hypothesis holds for each of the 32 layer/group/head pairs formed from the first Q and K input columns at pinned layers 0 and 14. Thus the rank-one key basis already present in those weights cannot feed a smaller exact stationary score recurrence for these queries.

This is a state-dimension bound, not a minimum instruction count, a cache-capacity bound, or a statement about BF16 bitwise behavior. In particular, it permits nonstationary position tables, nonlinear trigonometric instructions, a score table tailored to a finite horizon, and approximate or frequency-sparse learned Q/K images. It differs from the [post-rotation fixed-decoder orbit bound](../rope-key-orbit/README.md): the cache *can* be one scalar here; it is the query-side position sequence that needs 128 recurrence coordinates.

Write the two real coefficient vectors

`A_j = q_j b_j + q_{j+64} b_{j+64}`, `B_j = q_{j+64} b_j - q_j b_{j+64}`.

Then `s_t = Σ_j (A_j cos(tω_j) + B_j sin(tω_j))`. The 128 complex nodes `exp(±iω_j)` are all distinct, since `0 < ω_j ≤ 1 < π`. Each conjugate coefficient is nonzero exactly when both `q` and `b` have a nonzero plane component, as `A_j²+B_j² = (q_j²+q_{j+64}²)(b_j²+b_{j+64}²)`. Form the 128-by-128 Hankel matrix `H_{ik}=s_{i+k}`, `0≤i,k<128`. Over the complex numbers it factors as a Vandermonde matrix, the nonzero diagonal of mode coefficients, and the transpose of that Vandermonde. Its determinant is nonzero. Any proposed `d`-state recurrence instead factors `H` into a 128-by-`d` observability matrix and a `d`-by-128 reachability matrix, so `rank(H)≤d`. A real 128-state realization keeps cosine/sine coordinates for each plane, updates each pair by the fixed two-dimensional rotation `R_{ω_j}`, and sums the 64 first coordinates. The bound and construction meet. If only `m` planes have overlapping support, the identical argument gives `2m` for a horizon of at least `4m-1` scores. Frequency support, not rank of the unrotated key producer, controls this grammar's state.

## Pinned witness and online price

[`recurrence.py`](recurrence.py) loads original BF16 Q/K weights into FP64 and checks all 16 query heads at layers 0 and 14, using the first input column of each group/head. Every pair has 128 nonzero modes. The minimum `hypot(A_j,B_j)` is `5.61233e-6` at layer 0 and `3.69222e-6` at layer 14. The constructed oscillator replays 256 scores against independent direct trigonometric evaluation with maximum FP64 absolute differences `2.802e-16` and `2.572e-16`. This numerical check illustrates the exact algebra; a floating Hankel SVD is neither used nor credible as a rank certificate for closely spaced frequencies. The [receipt](/path/to/workspace/data/kelana-subbit/rope-recurrence/receipt.json) records each head, model/config/source SHA256, domain and errors.

With contiguous keys, one score query can prepare 128 real coefficients and advance 64 oscillator pairs for **each** key position, then reduce 64 two-coordinate contributions and multiply by its key scalar. An elementary oscillator lowering uses four real multiplies and two adds per plane per position, plus 128 coefficient-coordinate products and their reduction per score. It holds 128 live real state elements per head, so two independently queried heads need 256. This is a candidate program and arithmetic count, not a GPU timing claim; instruction fusion, lane layout and scalar reuse could change the cost. Sparse plane selection, by contrast, keeps its selected key coordinates already rotated at write time and needs two products per retained plane for a score. The price of exact rank-one pre-RoPE storage is therefore shifted onto query-position work and live state rather than erased. Across 16 query heads, 128 FP32 state elements/head would be 8,192 bytes of live state per query/layer before register placement.

The useful next experiment is a *learned* pre-RoPE key basis and both observing query heads trained under quantized-producer causal loss, with a term for oscillator support or a cheaper position-aware realization. Compare it at a paid total Q/K image and KV rate against the [causal whole-plane masks](../rope-causal-mask/README.md), then measure native query preparation, key read, occupancy and attention loss. A generic dense rank-one basis is a bad exact recurrence candidate even though it is an excellent storage example. This result says nothing against approximate bases that deliberately concentrate energy in a small set of planes.

Reproduce the CPU witness without reserving the GPU:

```sh
OPENBLAS_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/quantization-discovery/subbit/rope-recurrence/recurrence.py \
  --output /path/to/workspace/data/kelana-subbit/rope-recurrence/receipt.json
```

No Bonsai executable, model image or resident service changed.
