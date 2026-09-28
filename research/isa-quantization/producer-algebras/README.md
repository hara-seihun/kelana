# Producer-derived algebra on a nonbinary state

**Finding.** A 32-valued integer producer can carry a *small, approximately sufficient* quotient through a complete 48-channel SiLU/up/down region and a live product continuation, without closing or snapping any individual gate. A fixed two-instruction producer code, `c(q)=(q*q)>>7`, has eight nonuniform cells. On 8/12 independently generated, unplanted nonlinear regions its 32-byte two-branch FP16 table has less complete three-observation error than the **best** of 797 tested affine MAD/shift eight-cell producers at the same table budget. The exact obstruction to product reuse is within-cell branch covariance, and a rigorous derivative/within-cell-variance bound screens that obstruction directly from the producer and complete responses. The win does **not** extend to linear or unstructured controls; calibrated scalar Q4 is much more accurate at 164 bytes, and a direct 32-cell table is essentially exact at 128 bytes. This is an explicit distortion/bytes/work tradeoff, not a scalar-Q4 replacement or native-speed result.

## The bridge from producer program to approximate algebra

Let a producer supply an **already quantized** integer `q∈{0,…,31}`. This is nonbinary: all 32 states are present with equal weight, not a binary expansion extrapolated to real activations. For any deterministic executable code `c(q)` with `k` cells, the functions of `c` form a pointwise algebra: sums, products, SiLU of coded values, and subsequent branches remain in the same label space. The code's conditional expectation `P_c f(q)=E[f(q)|c(q)]` is the best real table for a branch in complete-domain mean square. No source weight or source gate must lie in that algebra. A uniform within-cell distribution gives, for two real branch responses,

```
Cov_C(f,g) = [1/(2|C|²)] Σ_(i,j∈C) (f_i-f_j)(g_i-g_j).
```

The 1/2 counts each unordered pair twice. [`Kelana/ProducerAlgebras.lean`](../../../Kelana/ProducerAlgebras.lean) proves the unnormalized identity for **arbitrary finite lists and integer-valued branches**:

```
|C| Σ_i f_i g_i - (Σ_i f_i)(Σ_i g_i)
  = Σ_(i<j) (f_i-f_j)(g_i-g_j).
```

It does not formalize floating SiLU, FP16 rounding or the derivative bound below. The identity is stronger than a two-point or planted algebra witness and pairs with the general abstract product-projection identity in [`Kelana/ClosureContinuation.lean`](../../../Kelana/ClosureContinuation.lean).

If a cell is a contiguous interval of integer states and successive differences of `f` and `g` have magnitude at most `L_f(C)` and `L_g(C)`, telescoping gives `|f_i-f_j|≤L_f(C)|i-j|` and similarly for `g`. The pairwise identity then proves

```
|Cov_C(f,g)| ≤ L_f(C)L_g(C) Var(q|C).
```

If both branches increase with discrete slopes bounded **below** by positive `m_f,m_g`, the reverse inequality `Cov_C(f,g)≥m_f m_g Var(q|C)` holds: correlated variation is an obstruction, not a free cancellation. The squared additional product error from reusing the two projected branch tables instead of fitting a third product table is exactly `Σ_C Pr(C) Cov_C(f,g)²` before table rounding. Thus `Σ_C Pr(C)[L_f(C)L_g(C)Var(q|C)]²` is a **producer-code-specific upper bound** on that additional error. Branch approximation itself is separately bounded by `Σ_C Pr(C)L_f(C)²Var(q|C)` (and analogously for `g`). These are domain- and distribution-specific calculations, not worst-case guarantees on unseen real states.

This separates two questions that gate-snapping conflates: whether a cheap producer code places enough cells where the *complete responses* change, and whether the live branches' unresolved variations covary. Squaring followed by shifting gives cells `0..11`, `12..15`, `16..19`, `20..22`, `23..25`, `26..27`, `28..29`, `30..31`: it allocates resolution toward large positive inputs where SiLU/up products often vary faster. An affine binning would be better for a truly linear teacher. Both are executable producer instructions rather than an arbitrary free partition; the square reader pays one integer multiply and one shift, plus an eight-entry table select per branch. The affine comparator pays MAD and shift; each affine program's constants must be stored if selected per model, while the fixed square code needs only its shift literal as common routine code. Code formation is *not* attributed to the consumer or treated as free. Producing the upstream `q` from real `x` would require separate quantization and domain acceptance; this experiment starts after that producer has supplied `q`.

## Complete region, strong controls and outcome

For each seed 0–11, 48 independently drawn hidden units have gate `g_h(q)=a_h q+b_h` with `a_h∈[.025,.21]`, `b_h∈[-3.8,.7]`, up `u_h(q)=c_h q+d_h` with `c_h∈[.012,.14]`, `d_h∈[-.7,1.2]`, and independently drawn Gaussian down weights to **two outputs**. Neither gate slopes nor output rows are snapped to the eight-cell quotient. Observe `f(q)`, `g(q)` and their live product `f(q)g(q)` on all 32 input states. The score is the sum of the **three centered, individually normalized squared errors**; it can exceed one. The branch tables contain each cell's best real conditional mean, independently rounded to FP16; their product is computed online, not fitted as a third table. The scalar Q4 control quantizes all 288 gate/up/down parameters into signed nibbles, selects six FP16 field scales by two response-aware coordinate sweeps over thirteen scale factors, and fits/rounds two output gains and two origins to FP16. It pays 144 nibble bytes + 12 scale bytes + 8 calibration bytes = **164 bytes**, and evaluates the complete same SiLU/up/down product region. This is a stronger local scalar control than nearest rounding, although not a globally optimal Q4 converter. The unconstrained direct table stores 32 states × two FP16 outputs = **128 bytes** and computes the product online. A third fitted FP16 product table on the square code costs another 16 bytes; comparing it isolates the price of continuation reuse. An exhaustive dynamic program supplies an even stronger **optimistic** eight-interval control: it chooses all seven cuts freely and fits three independent real output tables, including the product, at a 53-byte nominal image (48 FP16 table bytes and five packed cut bytes). In exact arithmetic this independent-output projection is a lower bound for any composed two-table reader with the same cuts; the script evaluates the dynamic program in FP64, so the printed digits are not a certified rational bound. Runtime cut search or comparisons are still required; it is not an executable two-table multiplication witness.

| Teacher family, 12 seeds | Fixed square, 32 B | Best affine, 35 B | Square with third table, 48 B | Optimistic best eight intervals, 53 B | Full direct, 128 B | Fitted scalar Q4, 164 B |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Independent nonlinear SiLU regions | **.04801** | .07080 | .04798 | .04302 | .00000027 | .000324 |
| Same region with constant gates (linear output) | .14038 | **.04606** | .14009 | .04604 | .00000090 | .000000007 |
| Unstructured independent Gaussian response cells | 2.51766 | **2.04354** | 2.35517 | 1.27167 | .00000017 | n/a |

Entries are medians, **not paired-median differences**; all per-seed results and affine constants are in [`results.json`](results.json). The best affine stores its two literals and shift in three bytes beyond the shared FP16 table. The fixed square beats the best of all 797 affine partitions for nonlinear seeds `1,3,4,6,7,9,10,11`, and loses to it on every linear/unstructured seed. On the nonlinear panel the median exact normalized covariance penalty is `.0000251`; the finite-difference/within-cell-variance bound has median `.0001082` and holds for every seed. On the linear panel the bound equals the exact penalty (up to floating rounding), while on unstructured responses it is loose and correctly offers no favorable screen. Source coefficients are drawn independently of either candidate code; the common scalar producer and positive-domain nonlinear shape, **not planted quotient weights**, explain the effect.

These sizes count only model-specific FP16 labels, nibble codes, scales and gains. They do not include alignment, program code, decoded buffers or a backend instruction schedule. The fixed square program needs a 5-bit state, a multiply/shift, two indexed FP16 loads, output stores and one product; direct full table needs the 5-bit address, two loads and the product. The scalar Q4 reader must unpack codes, form 96 affine activations across 48 hidden units, evaluate 48 SiLUs and products, reduce both down rows, apply four calibration constants and multiply the branch outputs. Those are abstract work obligations, **not** measured device cycles or a proved latency ranking. FP16 rounding is scored; source SiLU is ideal FP64 via NumPy, not a certified floating-ISA equivalence. At 128 bytes the direct table almost eliminates distortion, so any claim that the eight-cell map is strictly better independent of byte/work constraints would be false. On arbitrary real producer states its finite-domain equivalence does not hold.

Reproduce in roughly four seconds, CPU only:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/isa-quantization/producer-algebras/screen.py
lean Kelana/ProducerAlgebras.lean
```

The first command rewrites `results.json` and checks the covariance bound for every candidate square code. The Lean module establishes the finite pairwise identity independent of the experiment's width, domain size or input count. This is a nonbinary, unplanted nonlinear follow-up to [closure continuation](../closure-continuation/README.md) and [instruction cells](../instruction-cells/README.md). It supplies a precise producer test to run on captured real-model code domains; it does **not** imply Qwen's 1024-dimensional real producer is governed by one cheap scalar code. A real-model transfer must first identify an actual upstream scalar or low-dimensional integer state with a program-level reachability contract, then measure its response collision floor and continuation covariance alongside paid scalar/direct readers.
