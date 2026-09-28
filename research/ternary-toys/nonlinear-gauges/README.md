# Shared coordinates through a nonlinear residual block

A planted two-channel RMSNorm/SwiGLU example has an **exact ternary representation** in a shared residual coordinate system that is neither the original basis nor a Hadamard basis. The useful extra freedom is not another gate rotation: it is a hidden *up/down diagonal gain*, which cancels through the product without touching SiLU. A finite search recovers the residual angle of 29 degrees and hidden gain of 2.5 without fitting all weight entries. This is a construction, not evidence that a real transformer has such a basis.

Run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/ternary-toys/nonlinear-gauges/experiment.py` from this checkout. It writes [results.json](results.json). NumPy is the only dependency. The exhaustive family contains residual angles 0 through 89 degrees and first-channel up gains 0.5 through 4.0 in 0.1 increments. Each of the three 2x2 matrices gets one nonnegative least-squares scale and four ternary entries. The script searches all 80 nonzero ternary patterns per matrix, then chooses the shared coordinates by the sum of their squared weight errors. There are 3,240 coordinate candidates, not a weight-training run.

Let `N(x)=x/sqrt(mean(x²)+1e-6)` and `B(x)=x+D[SiLU(G N(x)) ⊙ (U N(x))]`. For an orthogonal residual change `z=Qx` and an invertible diagonal hidden gain `S`, the exact same block in `z` is

```
G' = G Qᵀ       U' = S U Qᵀ       D' = Q D S⁻¹.
```

Orthogonality makes `N(Qx)=Q N(x)` even with epsilon; linearity preserves residual addition. `S` multiplies only the up side, so it cancels with `S⁻¹` in down. Hidden permutations can act on both gate and up, with the inverse on down. A generic hidden rotation cannot pass through a coordinatewise product; scaling the *gate* is not a gauge because SiLU is not homogeneous. On this held panel, illegally doubling gate preactivations and halving the up product yields 0.1399 relative output RMSE. An arbitrary nonorthogonal residual transform changes RMSNorm's denominator unless the norm computes a transformed metric, a paid operation. A learned diagonal norm gain can be absorbed into the following linear producers, but it does not expand the cheap residual symmetry to arbitrary shears.

The teacher uses ternary matrices in a rotated, hidden-gain basis. Its original-coordinate matrices are `G=G*Q₀`, `U=diag(1/2.5,1)U*Q₀`, `D=Q₀ᵀD*diag(2.5,1)`, where `Q₀` is a 29-degree rotation and the three starred integer matrices appear in the source. The first training inputs have channel standard deviations 2.0 and 0.3. Held inputs reverse that anisotropy to 0.35 and 2.0 and shift the means. Relative RMSE uses the original-coordinate teacher block output, including its residual. Each line below reports the weight-error-selected coordinates, not a selection on held data.

| Coordinate family | Angle, up gain | Weight SSE | Train output RMSE | Held output RMSE | Held, three repeated blocks |
| --- | --- | ---: | ---: | ---: | ---: |
| Fixed coordinates | 0°, 1 | 2.926 | .545 | .337 | .695 |
| Hadamard rotation | 45°, 1 | 2.550 | .774 | .367 | .737 |
| Best rotation alone | 29°, 1 | 1.320 | .545 | .337 | .695 |
| Best up/down gain alone | 0°, 3 | 1.231 | .487 | .212 | .447 |
| Joint shared search | 29°, 2.5 | <1e-29 | <1e-12 | <1e-12 | <1e-12 |

Selecting the controls directly on train *block output* does not close the gap. Rotation-only reaches .361 train RMSE at 55 degrees but .416 held RMSE; gain-only reaches .471 train at gain 1.6 but .427 held. The local weight objective misses output effects, while the anisotropic training panel can prefer a worse held basis. Neither observation proves a general advantage for weight SSE.

For a transfer check, a *different* ternary SwiGLU block uses the same planted residual angle, different gate/up/down patterns, and hidden gain 1.8. Only its second gain is searched; the first block's angle is frozen. On held inputs, the two-block composition has relative RMSE below 1e-12 in the joint basis, versus .336 for rotation alone, .415 for gain alone and .472 for fixed coordinates. This transfers a coordinate system between two blocks **constructed to share it**. It does not test naturally learned weights.

## Where the bill arrives

The output is already in the new residual coordinates, so a stack of blocks can share `Q` across their residual additions and pay one entry conversion and one exit conversion rather than a conversion around every nonlinear block. A 2x2 entry or exit rotation uses four real multiplications and two additions per token. A non-orthogonal alternative needs the original RMS denominator or a dense quadratic metric at every norm. Hidden gains are absorbed offline into `U'` and `D'`, with no per-token multiply; the three matrix scales remain charged. For this tiny first block the codes are 12 trits, packed as three separate radix-243 bytes if each matrix is independently packed, plus six bytes for three FP16 scales. A general 2x2 rotation stores at least its sine and cosine, four more FP16 bytes, and requires entry/exit work. If storing a reproducible search recipe rather than the final codes, the hidden gain costs another FP16 word; it is not needed by the deployed ternary block. The numerical experiment uses float64 trigonometry and scales, so the sub-1e-12 claims do **not** include FP16 rounding, packed arithmetic, or runtime measurements. At two channels the coordinate metadata and boundary arithmetic swamp any plausible weight saving. Shared coordinates only make economic sense across enough real width/depth and compatible consumers.

Attention imposes more constraints. A common Q/K orthogonal transform preserves dot products only if it is applied on the correct side of RoPE; moving it across all relative RoPE rotations requires commutation with each rotation. Softmax itself cannot be conjugated by a general channel matrix, and V/O needs a separate paired transform. A shared residual `Q` must also be carried through embedding, every attention and FFN branch, norms, and the output head; independently selecting an attractive angle for each matrix silently buys conversions.

## Off-manifold stress test

Run `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python research/ternary-toys/nonlinear-gauges/stress.py` for the additional [stress-results.json](stress-results.json). It uses a separate RNG seed, 768 train inputs and 2,048 held inputs with the same anisotropy reversal. One teacher adds independent Gaussian noise with standard deviation 0.2 to each of the 12 original-coordinate planted weights, *before* the gauge search. The other draws all 12 weights independently from a standard normal. These are two fixed draws, not a sweep or a claim about typical teachers.

All arms use the same three four-trit matrices and three FP16 group scales. The joint arm has 3,240 candidate coordinate pairs; the one-dimensional controls get their own best candidates. Each family is selected both by matrix SSE and by its *complete block output RMSE on train*, without looking at held data. Every candidate rounds the three scales to FP16. Nonidentity residual rotations store sine/cosine as FP16, cast transformed inputs and recovered outputs to FP16 at the two paid boundaries, and use the stored `Qᵀ` as the approximate inverse. Float64 arithmetic within the block isolates boundary and scale rounding; this is **not** an FP16 or packed runtime simulation. Fixed/gain-only coordinates need no entry/exit rotations. The original exactly planted teacher, now with these rounded scales and boundaries, has .000358 held relative RMSE rather than the earlier float64 zero.

| Teacher | Train-selected fixed held RMSE | Hadamard | Rotation-only | Gain-only | Joint angle/gain, held RMSE |
| --- | ---: | ---: | ---: | ---: | --- |
| Noisy planted | .1918 | .1919 | .1916 | .1391 | 37°, 2.1: .1256 |
| Independent Gaussian | .2813 | .2482 | .3146 | .1229 | 86°, 0.5: .0759 |

For the noisy teacher, a *weight-SSE-selected* joint gauge chooses 81°/4.0 and gets .1563 held RMSE, worse than gain-only's .1362. The best output-selected joint gauge gains .0135 absolute RMSE on held over the matched output-selected gain-only control, even with its FP16 boundary. On the independent teacher the corresponding held gain is .0470, but a single tiny Gaussian draw is not evidence for generality. The rotation-only output-selected control even reverses from .1885 train RMSE to .3146 held, so local or anisotropic train metrics can select a bad basis. A joint transform spends four FP16 coordinate bytes plus two 2x2 boundary maps, each with four multiplications, two additions and two FP16 lane casts per token. A gain-only transform avoids that bill. At width two and one block, the modest noisy-teacher accuracy gain does not justify a speed or storage claim.

The next discriminating test is a CPU capture of several *consecutive real Qwen3-0.6B layers*: use their frozen residual inputs and original BF16 weights to search small block-diagonal orthogonal residual transforms plus offline up/down gains, hold complete blocks and text windows aside, and compare at identical packed byte count against both fixed-coordinate and signed-Hadamard ternary GPTQ. Charge transform descriptors, any untied boundary conversions, and composed held next-token loss. If only independent per-matrix gauges improve weight error while held composed loss degrades, this planted construction has no practical transfer.
