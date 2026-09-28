# Exact cell search for a RoPE phase gauge

The [commuting-coordinate construction](../rope-commutant/README.md) leaves a phase per selected Q/K plane to fit. A uniform angle grid misses changes in the stored nibble labels and has no finite optimality claim. For a fixed key step and real, unrounded queries, the two-head, softmax-centered squared-score objective has a finite exact global infimum. Enumerate key-code transitions, then solve one quartic per constant-code interval. This is an offline conditional optimizer for a useful causal-score surrogate, not a solution for the full model loss.

## Domain and construction

One real plane has cached keys `k_j=(x_j,y_j)` and any finite set of observing query rows `q_h`. Both GQA heads use the same code. At phase `p`, rotate keys and queries by `U(p)` and store `c_j(p)=clip(floor(U(p) k_j / s + 1/2), -7, 7)` for a fixed positive step `s`. The approximate score is `s (U(p) q_h) dot c_j(p)`. The real teacher score is `q_h dot k_j`. Center scores over each query's causal key prefix before measuring the sum of squared error, since a common key-score offset is invisible to softmax. Positive fixed per-query weights also work. Keys in distinct prefixes can be represented as distinct observations with one shared appended-key code; the finite formula is unchanged.

For `p` inside an interval without a label transition, every code `c_j` is fixed. Its score has the form `a_hj cos(p) + b_hj sin(p)`, with `a_hj=s(q_x c_x+q_y c_y)` and `b_hj=s(q_x c_y-q_y c_x)`. Center `a`, `b` and teacher scores within each causal row. The complete two-head squared error on this interval is

```
F(p) = A cos²(p) + B sin²(p) + 2 C cos(p)sin(p)
       - 2 D cos(p) - 2 E sin(p) + G.
```

The six coefficients are sums of products of the centered arrays. The stationary equation is `(B-A) sin(2p) + 2C cos(2p) + 2D sin(p) - 2E cos(p)=0`. Under `z=tan(p/2)`, its finite roots are those of

```
(2C+2E) z⁴ + (4D-4(B-A)) z³ - 12C z²
+ (4D+4(B-A)) z + (2C-2E) = 0.
```

Evaluate its real roots inside the interval and both one-sided endpoint limits. Include `p=pi` for the half-angle pole if searching the full circle. Each key-coordinate code changes only when its rotated value crosses one of the fourteen half-integer thresholds `s(m+1/2)` for `m=-7..6`. Each threshold meets a sinusoid at most twice per revolution. There are at most `56N` transition angles for `N` distinct keys, hence at most `56N+1` cells before deduplication. With symmetric `-7..7` clipping, a 90-degree rotation simply permutes and changes signs of the two codes and rotated query coordinates, so the objective has period `pi/2`. Search `[0,pi/2]` only. This symmetry does **not** apply unchanged to a codebook using `-8` without `+8`.

This proves the global **infimum** in exact real arithmetic for the stated fixed-step score surrogate: on each open cell, a smooth function reaches its infimum at a stationary point or one of its endpoint limits, and the enumeration includes all of them. A one-sided endpoint value need not be attained under the specified tie-breaking rule. Choose an interior phase arbitrarily close to it, or compare actual endpoint codes separately. The script computes floating polynomial roots; it demonstrates the construction numerically rather than certifying those roots in exact arithmetic.

## Checked finite example and cost

`python3 research/quantization-discovery/subbit/phase-cell-fit/fit.py` generates twelve fixed-seed two-dimensional keys and two correlated query heads. Its [receipt](receipt.json) includes the keys, queries, source hash, cell and grid controls. At step `.75`, zero phase has centered squared-score error `1.7998493509`. The 23-cell search finds infimum `1.4625734295` at the one-sided boundary `p=.2317405926`, a reduction of 18.74%. Moving `1e-8` radians into the chosen cell realizes `1.4625734500`; a 100,000-point grid gives `1.4626035537`. The quarter-turn interval has 22 crossings, against a loose 672-crossing full-circle bound. These are synthetic scores, not Qwen NLL or attention KL. The script checks its analytical value against the actual code/score calculation near the selected boundary and against the grid.

For a frozen plane and `N` observed appended keys, constructing the angle list costs at most `56N` candidates and a sort. The direct executable rebuilds and scores all two-head keys in each cell, `O(N²)` in the worst case; an incremental coefficient update can reduce this after ordering the transitions. The quartic has at most four real stationary candidates per cell. This is **offline fitting work**. At inference the retained cost is the prior phase gauge's two FP16 numbers per plane, phase/position composition, key label generation and the existing three- or four-dot query consumer. A rounded nibble query adds its own transition cells and its dynamic-scale rule is not included in this theorem. The native query prep and append composition remain unpaid.

The next experiment should freeze the selected Q/K masks and paid binary producer, fit each plane's phase on quantized-upstream train captures using this exact centered-score objective, then compare finite causal KL and post-O error on fresh held text against zero phase at identical step and rate. If a score fit loses causal quality, optimize that finite objective inside the same label cells instead of increasing the phase grid. Test the rounded-query and native append boundary before choosing an engine map. No GPU, executable, service or serving default changed here.
