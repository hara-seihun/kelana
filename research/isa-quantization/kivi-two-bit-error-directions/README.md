# Original KIVI2 complete-output error directions: eight retained held states

The original full-16Q/8KV KIVI2 cache's error on the eight **previously retained** held t128/t256 states is predominantly a **value/interaction direction**, not beneficial K/V cancellation. In the original 1024-coordinate O space, normalized by the sum of original teacher-output squared norms, V-only effect energy is **0.001531692**, K-only **0.000662897**, and the exact K×V interaction **0.000306348**. The V–interaction twice-inner-product is **+0.000597439**; K–V is **−0.000033502**. Source rounding contributes energy **0.000000568**. The complete both-quantized error is **0.003068938**. These are frozen-map diagnostics, not independent additive loss estimates or a new paid cache candidate.

Let S be attention/O with the chronological **BF16 arrival** K and V, Q and O frozen; K is packed K plus arrival V; V is arrival K plus packed V; B is both packed fields. T is the *retained original teacher output*, whose K source was original FP32 post-RoPE, not this BF16 arrival. All four maps use the same CPU float32 batched dot, softmax, value contraction and original BF16 O decode as the documented conventional CPU map. Define `E_source=S−T`, `E_K=K−S`, `E_V=V−S`, `E_int=B−K−V+S`. Their vector sum is `B−T`, without claiming S=T. The complete-output effect Gram `G_ij=<E_i,E_j>/sum ||T||²` includes every crosshead and cross-effect term: each vector is formed **after** all 16 heads mix through the original O. `results.json` retains the raw and individually normalized 4×4 matrices for every state, plus their pooled matrix. Pooled entries below are in units of 10⁻⁶ of the common original teacher denominator:

| Effect | Source | K | V | Interaction |
|---|---:|---:|---:|---:|
| Source | 0.568 | −0.792 | −0.146 | −0.026 |
| K | −0.792 | 662.897 | −16.751 | 2.712 |
| V | −0.146 | −16.751 | 1531.692 | 298.720 |
| Interaction | −0.026 | 2.712 | 298.720 | 306.348 |

Off-diagonal cells count twice in the full squared error. Ignoring source rounding for interpretation, the K and V separate energies total 0.002194589; their cross term is slightly negative, while the V×interaction positive cross term is almost **18×** its magnitude. The complete quantization contribution `||E_K+E_V+E_int||²/||T||²` is **0.003070297**. The largest eigenvalue of the four-effect Gram is **0.001600900** (64% of its trace), along approximately `−0.974 V −0.225 interaction` in effect-coefficient coordinates; the next is **0.000662731**, almost purely K, and the third **0.000237307**, the opposing V/interaction direction. These coefficient-space eigenvectors describe observed effect alignments, not a freely implementable cache map. Value effects are not uniformly largest: held-1/t256 is K-dominated; other states vary. Four largest V-heavy states (held-1/t128, held-2/t256, held-3/t128,t256) drive much of this pooled direction. This supports exploring V *and its observer interaction* rather than assuming separate K/V energy addition; there is no large beneficial K–V cancellation in this original cache at these states.

| State | Source² | K² | V² | Interaction² | 2⟨V,int⟩ | Complete² |
|---|---:|---:|---:|---:|---:|---:|
| held-0/t128 | .000000903 | .000359794 | .000126238 | .000083676 | +.000043871 | .000606530 |
| held-0/t256 | .000000167 | .000251018 | .000350845 | .000091882 | +.000121218 | .000752131 |
| held-1/t128 | .000000504 | .001245965 | .003597463 | .000996542 | +.001575943 | .007212581 |
| held-1/t256 | .000001119 | .000819731 | .000075156 | .000039447 | +.000007111 | .000982377 |
| held-2/t128 | .000000267 | .000442354 | .000195208 | .000062147 | +.000067706 | .000733458 |
| held-2/t256 | .000000669 | .000405578 | .001961226 | .000308052 | +.001002393 | .003746868 |
| held-3/t128 | .000000305 | .001265569 | .002728199 | .000545644 | +.001593754 | .006167664 |
| held-3/t256 | .000000647 | .000872608 | .005180946 | .000646791 | +.001174206 | .007810800 |

## Provenance and reproducibility

`measure.py` SHA256 `9ec229e8df43e867c5436d314936bf603861a9510f37e5de10b5e62e85058fec`; `results.json` SHA256 `c32576b7affb96b753cc73c66bfa5ea369b71e86752c8779c55cbef676405525`. The results pin the frozen snapshot manifest, original fixture/O image, each Q, teacher, conventional and byte CPU output, eight per-head packed states, original head event streams and original manifests, the BF16 arrival streams and their manifests, and hashes of every computed counterfactual O. Snapshot sources are [`../kivi-two-bit-dot-native/`](../kivi-two-bit-dot-native/README.md); chronological arrivals are [`../kivi-value-intern/`](../kivi-value-intern/README.md); immutable KIVI2 paid events and state receipts are [`../kivi-two-bit-causal/`](../kivi-two-bit-causal/README.md). Quantized K/V are decoded directly from those eight original packed states; the original event bytes match their quantized records and the arrival bytes match their recent records. No `source.arrays`, model/source forward, GPU, quantizer re-fit, recapture or ladder was used.

With `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python measure.py` from this directory, CPU B agrees **bit-for-bit** with the original retained conventional packed CPU outputs (maximum coordinate difference 0); algebraic closure against B−T has maximum absolute float32 coordinate residual **1.49×10⁻⁸**. Matrix inner products and denominators are accumulated in float64 *after* the four float32 O maps. The earlier full-256-position held-panel error is a different population: these eight points do not repeat that analysis, estimate a whole-panel score, or price any alternative representation or serving performance. The distinct [KIVI4 single-pair study](../joint-cache-error/README.md) does not supply these full-layer KIVI2 measurements.
