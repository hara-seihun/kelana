# A finite gate alphabet closes a nonlinear region

SiLU blocks the bilinear fold in [joint operators](../../quantization-discovery/representations/joint-operators/README.md). On an **already binary** six-coordinate input, changing the gate weights can make the *complete* SwiGLU region a cubic map exactly. The useful part is the condition for closure, not a Taylor approximation. This experiment also shows why forcing ordinary gates into that condition is usually the wrong conversion.

## Exact statement

Let `x_i ∈ {-1,+1}`. Each gate row has exactly two nonzero entries, `g_h = a_h(s_hi*x_i + s_hj*x_j)`, with `a_h > 0`, signs `s_hi,s_hj ∈ {-1,+1}`, and `i != j`. Up rows and all down rows are arbitrary real matrices. The reachable gate values are `{-2a_h,0,2a_h}`. On precisely these three values,

```
SiLU(g_h) = g_h/2 + tanh(a_h)*g_h²/(4*a_h)
          = a_h*(s_hi*x_i+s_hj*x_j)/2
            + a_h*tanh(a_h)*(1+s_hi*s_hj*x_i*x_j)/2.
```

After multiplying by an arbitrary linear up row and summing through any down matrix, every output is in the span of square-free monomials of degrees zero through three. The identities `x_i²=1` remove repeated indices. For six coordinates the shared feature list has `1+6+15+20=42` entries. Neither gate values nor hidden units need be materialized by a direct reader. The coefficients can be computed from the complete finite response by the Walsh transform, `c_S = 2^-6 Σ_x F(x) ∏_(i∈S)x_i`. All coefficients above degree three must vanish for this gate family. This is a real-number identity, checked to FP64 rounding error in the experiment, not a floating-point ISA proof. It does not hold on continuous inputs.

This gives a decision test even for gates outside the family: their high-degree Walsh energy on all 64 binary inputs is the **exact minimum squared error** among cubic binary maps, divided by the complete response norm for relative RMS. It is an orthogonal projection, with no training inputs or polynomial extrapolation. An arbitrary direct 64-entry lookup is the stronger exact finite-domain competitor at a larger image size.

## Small experiment

`experiment.py` fixes six inputs, 48 hidden channels and four outputs. Eight seeds per family draw independent Gaussian up and down weights. The gate families are equal-magnitude two-support rows, those rows plus independent Gaussian noise of standard deviation `.08`, and unrestricted Gaussian rows. The two-support magnitudes lie in `[.45,.9]`. The unrestricted rows have standard deviation `.7`. The complete 64-state binary domain is used in each projection. Separate 512-point Gaussian panels at standard deviations `.8` and `2.3` test the boundary assumption. Relative RMS divides the candidate's aggregate output error by the teacher's aggregate output norm. The table gives medians over eight seeds; individual results and seeds are in `results.json`.

| Gate teacher | Binary cubic FP64 | Binary direct cubic int8 | Binary scalar q4 | Binary full table int8 | Direct cubic int8 on real .8 | Scalar q4 on real .8 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Two-support | < 4e-16 | .00681 | .11334 | .00581 | .59086 | .11412 |
| Perturbed | .00188 | .00689 | .13499 | .00590 | .56727 | .13249 |
| Unrestricted Gaussian | .04493 | .04539 | .12644 | .00663 | .51667 | .13113 |

All three cubic readers get worse on the wider continuous panel: `.74436`, `.73133`, and `.77639`, respectively, against scalar q4 `.11253`, `.13057`, and `.12825`. The constrained-family exactness is a **binary producer-domain** theorem, not permission to substitute this reader downstream of arbitrary real activations.

The direct cubic image stores 168 signed int8 coefficients and four FP16 output scales, **176 bytes**. The exact-domain full-table control stores 256 signed int8 entries plus the same scales, **264 bytes**. The conventional scalar q4 control stores all 768 gate/up/down weights in 384 packed nibble bytes and one FP16 scale for each of 100 rows, **584 bytes**. Its scale is selected from 81 steps per row by weight squared error, rather than fixed nearest rounding; the int8 scales receive the same search and FP16 rounding. All readers emit the four real-valued outputs. Original parameter count is 768, so these images are 1.833, 2.750, and 6.083 effective bits per original parameter, respectively. Fixed program code and the fixed 42-term basis are not model-specific bytes. A real producer's sign/packing work must still be charged.

To test **deliberate gate snapping** rather than only direct response coding, the script also replaces each gate row by its closest equal-magnitude two-support row on the entire binary box. The optimal row selection keeps its two largest absolute entries and sets their shared magnitude to their average. It recomputes the closed cubic and stores the same 176-byte image. Binary median errors are `.00681` for the constructed teacher, `.17779` for the perturbed teacher, and `.52407` for the Gaussian teacher. Even a tiny perturbation is expensive when made to satisfy exact gate closure, while directly quantizing the *whole map's* cubic coefficients gets `.00689`. For unrestricted gates the structural high-degree fraction is only `.04493`, despite gate snapping losing `.52407`. Closure of the observed map is much less restrictive than closure of each source gate. This is the main conversion lesson here.

## Execution and limits

A cubic reader needs 42 signed-byte features, 168 coefficient reads and four scale operations. With features already arranged in byte groups, four-output evaluation needs at most 44 four-way integer dots with two zero-padded terms per output; the padding can be generated at runtime instead of stored. Making the features is *not free*: a direct multiplication circuit can form 15 pairs and 20 triples, or bit parity can form signs from the six input bits, followed by byte packing. The 264-byte full table instead needs a six-bit index and four indexed reads. Scalar q4 needs nibble decoding, two 48-row projections, 48 SiLU evaluations, hidden products and the four down rows. These are operation/traffic obligations, not a native latency ranking. The script evaluates NumPy FP64 responses and counts physical model bytes; it does not run packed readers or test register pressure and cache behavior.

The binary comparison used the entire domain for fitting and evaluation, so it is an exact finite-domain error calculation, **not** a held-language-quality claim. The independently drawn teacher seeds are controls against a planted-only conclusion. They do not establish prevalence in actual Qwen producer states. A useful next test is a frozen real FFN snippet with its actual quantized-producer output codes, followed by a fused native cubic reader versus the indexed full-table and calibrated scalar readers under the same input and output boundary. If the producer does not supply a small binary domain, this particular construction has no transfer claim.

Reproduce from the repository root in a few seconds:

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python3 research/isa-quantization/nonlinear-closure/experiment.py
```
