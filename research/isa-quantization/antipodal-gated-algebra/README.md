# SiLU reflection contracts a complete MLP—but the odd map survives

**Comparable-size scope:** the reflection/odd-map identities and reflected-domain even-reader floor are mathematical findings. Their comparisons against a larger Q4 image do not exclude all lower-size even/odd programmes or establish matched-rate SOTA dominance. Preserve the [comparable-effective-size objective](../BRIEF.md#comparable-size-state-of-the-art-is-the-target) when reusing them.

The exact identity `SiLU(z)-SiLU(-z)=z` contracts **half of any bias-free SwiGLU MLP's complete output** to one quadratic tensor, without matching, storing or preserving its original hidden channels. This is a genuine whole-map algebra. Its other half is odd under input reflection and is substantial on the real Qwen3-0.6B layer-0 producer states. A purely quadratic/even reader therefore fails sharply against a paid all-three-matrix scalar Q4 control. Even the exact quadratic tensor is large, and a same-payload dense bilinear factorization retains a measurable coefficient-space floor **before** paying for the odd map. The result shows these reflection-only constructions cannot reach the stated Q4 response threshold; it does not reject their entire lower-size frontier or jointly redesigned even/odd programs that share cheaper intermediate structure.

## Exact identity and formal contract

For a gate row `g_j`, up row `u_j`, down column `D_:j` and zero-bias source projections, let

```
F(x) = Σ_j D_:j SiLU(g_j·x) (u_j·x),
Q(x) = ½ Σ_j D_:j (g_j·x)(u_j·x),
R(x) = ½ Σ_j D_:j (g_j·x)(u_j·x) tanh((g_j·x)/2).
```

Because `SiLU(z) = z/2 + (z/2)tanh(z/2)`, **`F=Q+R` exactly in ideal real arithmetic**, `Q(-x)=Q(x)`, `R(-x)=-R(x)` and

```
F(x)+F(-x)=Σ_j D_:j (g_j·x)(u_j·x)=2Q(x).
```

There is no antipodal *source channel* hypothesis. The quadratic coefficient matrix of output `o` is `A_o=¼Σ_j D_oj(g_j u_jᵀ+u_j g_jᵀ)`, so `Q_o(x)=xᵀA_o x`. A direct reader may discard every hidden-unit label after contracting this tensor. [`Kelana/AntipodalGatedAlgebra.lean`](../../../Kelana/AntipodalGatedAlgebra.lean) proves the arbitrary-channel reflected complete-output identity for any rational activation obeying `φ(z)-φ(-z)=z` and any gate/up forms reversing under `x↦-x`. It also proves the algebraic symmetric-pair squared-error identity. The specific transcendental SiLU law, FP32 evaluation and spectral lower bound are mathematical/numerical arguments outside that Lean module; it does not pretend to formalize `exp` or a GPU program.

On a panel containing **both** `x` and `-x`, an even reader `P(x)=P(-x)` satisfies

```
||F(x)-P(x)||² + ||F(-x)-P(-x)||²
 = 2||Q(x)-P(x)||² + 2||R(x)||².
```

Thus the exact `Q` is already the best *possible* even map on such a panel; the irreducible relative RMS is `||R||/sqrt(||Q||²+||R||²)`. This is not an assertion that reflected inputs occur in the actual Qwen producer. On a nonsymmetric observed set, an unrelated even map might fit its points better than `Q`; the reflected-pair lower bound must not be applied to the actual-only panel.

## Real complete-region screen and paid control

[`screen.py`](screen.py) reads the pinned BF16 Qwen3-0.6B **complete** layer-0 gate/up/down source matrices: 1,024 input, 3,072 hidden, all 1,024 output dimensions. The existing durable [`isa-response` captures](/path/to/workspace/data/kelana-subbit/vector-full/capture/isa-response/README.md) provide 1,024 actual selected-ternary-producer states in each of disjoint train and held panels, with original complete BF16 MLP outputs and physically exported group-128 scalar Q4 outputs. The Q4 baseline contains **all gate, up and down nibbles/scales/descriptors**, 4,866,096 model-specific bytes. The script independently decodes each stored Q4 image, recomputes its reflected output, and checks its positive-state replay against the saved control (relative difference below `1e-6`). Reflected states are an algebraic stress panel, not held text or a certified reachable producer set.

| Complete output, relative RMS | Train | Held |
| --- | ---: | ---: |
| Existing scalar Q4 on actual states, 4,866,096 B | .16516 | **.16253** |
| Exact contracted quadratic `Q` on actual states | 1.45835 | **1.46868** |
| **Optimal among all even maps** on paired `±` states | .58827 | **.58877** |
| Existing scalar Q4 on the same paired `±` states | .19662 | **.19236** |

The exact algebraic replay of the source outputs on captured inputs differs by about `1.0e-6` relative RMS in FP32 numerical arithmetic. On held actual inputs, `||Q||/||F||=2.01630`, `||R||/||F||=1.46868`, and their cosine is `−.88179`: the target arises from **strong cancellation** between individually larger components. Approximating each piece in isolation without scoring their sum is dangerous. No coefficient quantization, extra shape restriction or data fit caused the quadratic-only failure. The reflected Q4 result is calculated from the **same paid image**, not a fresh, free reader.

## Price of the contracted quadratic map

A symmetric 1,024×1,024 tensor needs 524,800 coefficients per output, or **1,074,790,400 bytes** for 1,024 FP16 output tensors; FP16 is an *optimistic approximate* storage format, not a claim of exact BF16-product contraction. This is 220.9× the complete scalar Q4 payload, before computing the still-missing odd map. A more executable family uses `r` shared bilinear atoms:

```
P_o(x)=Σ_(k=1)^r C_ok (a_k·x)(b_k·x).
```

Each FP16 atom costs **6,144 model bytes**: two 1,024-input vectors and a 1,024-output readout column. At the Q4 payload ceiling, `r≤792` (4,866,048 bytes, leaving **48 bytes** for all headers, code constants and the odd map). Each atom requires two input dots, one product and an output readout; input encoding and native layout still cost work. This atom class is allowed *arbitrary* learned factors, not snapped source gate/up/down channels. The span of its output coefficient tensors has rank at most `r` even if its factors are otherwise free.

There is a source-derived exact coefficient Gram without materializing any output tensor. With `K_jk=⟨sym(g_j u_jᵀ)/2,sym(g_k u_kᵀ)/2⟩`,

```
K_jk = ⅛[(g_j·g_k)(u_j·u_k)+(g_j·u_k)(u_j·g_k)],
Gram(Q tensors) = D K Dᵀ.
```

The sum of eigenvalues beyond index 792 divided by total trace is **.0636166**, an optimistic squared Frobenius coefficient-error floor for *every* 792-dimensional shared quadratic output-tensor space. It is not a lower bound on response error under the actual producer law: a coefficient perturbation can vanish on those input states, and a quadratic fit directly to nonsymmetric responses can mimic part of the odd target. Conversely, the `.58877` parity floor is a complete-response bound on the declared symmetric panel and does not require a coefficient budget. These are independent restrictions; we do not add or multiply them. FP32 source dot/Gram arithmetic and eigenvalues make the reported numeric floor a diagnostic, not a formally certified numerical inequality. A factorized quadratic reader near Q4's byte ceiling has essentially no paid space left for the large `R` correction.

As a separate source-channel snapping control, the minimum gate-row cosine with *any other* original gate has median `−.11797` and 1st percentile `−.37750`; **zero of 3,072 rows** has another gate below `−.9`. For the nearest-gate-antipodal choice, median absolute up-row and down-column cosines are `.02594` and `.02910`. Exact antipodal source pairing is absent. This says nothing about a better whole-map basis: it is precisely why the complete-output reflection identity is more general than a gate-pair search.

## Reproduction, decision and boundary

Run with the installed CPU NumPy/safetensors environment and one BLAS thread. It regenerates [`results.json`](results.json) in ~4 seconds; hashes identify the original BF16 checkpoint, scalar Q4 images and durable preactivation panels.

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  /path/to/workspace/data/fish-s2-pro/venv/bin/python \
  research/isa-quantization/antipodal-gated-algebra/screen.py
lean Kelana/AntipodalGatedAlgebra.lean
```

**Decision:** do not build a quadratic-only source-channel-free reader from this identity for the real layer-0 fixture, and do not spend a Q4-sized image on dense bilinear atoms before identifying a cheap *joint* odd continuation. One coherent next construction would need an executable representation of `R` **and** `Q` with shared data movement and code, evaluated on the complete output after cancellation; replacing `R` with an unpaid decoder or keeping the original full hidden bank would erase the byte claim. This screen does not establish a universal lower bound on all such coupled programs, other producer domains, nonlinear readouts or a native timing result. It extends the source-bank and Gaussian-law negatives by testing an exact whole-map algebra rather than another selection of source hidden features.
