# What the tiny experiments change

This round asks whether better conversion algorithms can replace more training.
The results below concern finite toy maps. They identify mechanisms and cheap
transfer tests; they do not change the current Qwen quality or native speed.
The [round index](README.md) links the source and measurements.

## First transfer result

The proposed [paired code/scale repair](../ternary/paired-repair/README.md) has
now run on the complete 0.6B image. It failed held acceptance: test NLL
4.646432 became 4.646920, and validation worsened too. Scale-only repair beat
the selected pair on the separate train check. The toy mechanisms below remain
valid; this first nomination and transfer did not produce a better model.
[The central catalogue](../catalogue/README.md) owns current classifications.

## The first practical lead was coupled discrete repair

[Discrete geometry](discrete-geometry/README.md) gives the strongest current
multi-problem evidence. Across 40 independently sampled gated teachers, exact
single-coordinate descent reaches the train optimum in 6 cases. Searching
one- and two-coordinate changes reaches it in 16. Held NLL improves from
.553739 to .551065. At 14 single-coordinate minima, a beneficial pair crosses
a strictly positive single-coordinate barrier. This is a failure of the
neighborhood, not merely an inaccurate STE gradient.

The search costs about 330 candidate scores versus 40 for singles and 6,561
for the full oracle. The useful next question is how to select interacting
pairs cheaply, not whether to enumerate pairs across hundreds of millions of
weights. Candidate response vectors or downstream directional derivatives
can nominate collisions; exact paired loss must decide them.

[Composed error](composed-error/README.md) supplies a reason to couple codes
with scales too. Its locally chosen down vectors conserve a coordinate sum
that the teacher changes. This proves a floor for every scale-only refit.
A downstream trit change frees the missing direction. A simultaneous upstream
scale change, harmful on its own, cuts held composed MSE from .46674 to .09171.
The teacher was selected by a train-only search for this witness. The invariant
proof is useful; the improvement is not an average over generic networks.

[Rate allocation](rate-allocation/README.md) extends this to a complete paid
catalogue. In its linear two-block residual map, joint selection gets .035156
composed error at seven bytes versus .941406 for downstream-weighted
independent selection. Even the linearized combined error of the winning pair
is 19.3984: the omitted cross-error product supplies the cancellation. At nine
bytes a conventional four-bit pair does better, .019531. The mechanism is
joint factorization, not a universal ternary advantage. Nonlinear gates and
norms may rule out the large hidden-state deviations used by this witness.

Together these suggest a bounded Qwen experiment before another broad STE run:
look for suppressed residual directions in two adjacent quantized blocks, then
compare a small set of coupled code/scale changes against equally budgeted
single changes and scale-only recovery. Use separate proposal and check train
panels. Preserve the existing held split for the final selected image.

## Fit the consumer that will actually run

[Routed sums](routed-sums/README.md) keeps soft top-two routing, nonlinear
experts and a quantized producer that changes routes. Joint fitting with the
original routes gets .15439 held MSE. The same exhaustive code family fitted
with the actual quantized routes gets .09284, versus .16861 for independent
expert fitting. It wins across all 12 input-sampling seeds for this fixed
teacher. Individual expert errors increase while their cross terms and route
errors cancel in the final sum.

This gives a concrete MoE transfer experiment. Capture actual quantized inputs,
route IDs and scores, then retain joint expert response terms in a small code
search. Compare to the identical search with original routes and independent
expert objectives. The toy quantizes only part of each expert and has three
experts, so it does not price a complete Qwen converter.

[Observed logits](observed-logits/README.md) makes the continuation issue exact.
A common logit offset is invisible to the current softmax but visible after a
particular next-state map. A one-trit code selected on both observations halves
weighted excess NLL relative to the pointwise code, from .150685 to .075342.
An equally priced raw-logit-MSE code gets .114735. The optimal partition also
has a cheap affine-threshold encoder, so it is not just an arbitrary lookup
relabeling. This is a state-coding result, not a ternary weight-format result.

## Coordinate freedom can matter more than local weight accuracy

[Tied consumers](tied-consumers/README.md) constructs a six-token tied
embedding/head model where two anchor logit columns recover an exact ternary
coordinate system. Its complete probability map has zero KL at 18 payload
bytes. Independent row fitting leaves .080733 KL even when the body gets an
unrestricted real-valued refit. A column-space obstruction proves the gap
cannot be trained away inside that fixed embedding representation.

This is an existence witness with known anchors and a deliberately constructed
teacher. It suggests fitting the tied encoder and observer as one map. It does
not establish that arbitrary transformer coordinate changes commute with
normalization, attention or gates.

[Nonlinear gauges](nonlinear-gauges/README.md) addresses some of those
constraints directly. Orthogonal residual rotations commute with scalar
RMSNorm, while reciprocal up/down gains cancel through the gated product
without scaling the nonlinear gate. A constructed two-block example becomes
exactly ternary under one shared residual angle and separate hidden gains.
Gate scaling and general hidden rotations do not have the same freedom.
Entry/exit transforms, finite precision and shared consumers remain part of
the representation cost. A follow-up adds weight perturbations and a separate
Gaussian teacher. Train-output-selected joint gauges beat gain-only in both
fixed draws, .1256 versus .1391 and .0759 versus .1229 held relative RMSE,
with rounded scales and paid FP16 boundaries. Weight-SSE selection loses to
gain-only on the perturbed teacher. This moves the result beyond exact
recovery of a planted basis, but not to a population or real-model result.

## Cheaper calibration needs the right weights, not only diverse examples

[Calibration sufficiency](calibration-sufficiency/README.md) gives a three-state
example with known support probabilities. Three weighted teacher queries
identify the optimal gate code. Random calibration with 10,000 draws still
chooses the wrong code 22% of the time. The rare state is almost always present;
its estimated mass is the problem. The construction has a strongly amplified
rare state and supplies the true masses. Discovering the states and estimating
those masses is not free.

The transferable question is whether a small weighted cover preserves the loss
differences between competing edits. Generic activation clustering alone does
not answer it. Compare representatives against the same teacher-query budget,
and include the cost of discovering and weighting the cover.

## A different codebook only wins when its structure is present

[Coupled codebooks](coupled-codebooks/README.md) compares exact scalar ternary
search with paired templates at the same four-byte budget for eight weights.
Paired templates win all eight noisy-motif cases, with summed held MSE .1280
versus 4.8526. They lose all eight unstructured cases, 6.5182 versus 2.3132.
They also use more nonzero terms and need decoding. This is a conditional
quality/rate result at four physical bits per weight, not a native speedup or
a replacement for the current 1.727-bit image.

Before fitting such a dictionary to Qwen, measure whether the paired motifs
exist often enough to amortize its metadata and execution. The negative
control is as useful as the motif win.

## Preserve distinctions and dynamics before minimizing coefficient error

[Reachable quotients](reachable-quotients/README.md) enumerates a two-step
attention map on 27 inputs. The coefficient-optimal ternary producer merges
states whose attention answers differ. No decoder can repair that collision.
A worse coefficient fit preserves all required outputs exactly. The strongest
control is especially useful: ordinary rounding also becomes exact by halving
both query temperatures. A joint scale choice can be sufficient; a new code
format is not always needed. A branch that reads the common logit sum breaks
the quotient, so every live consumer matters.

[Recurrent stability](recurrent-stability/README.md) shows how a small discarded
coefficient can be a stabilizing feedback link. A 3.064% matrix error changes
the gated transition radius from .966655 to 1.021973. The tanh version stays
bounded but develops a false persistent state after a pulse. Scale recovery
restores stability but not the missing response. A charged FP16 link restores
much more of it. The exception image costs 57 bits versus 39 for ternary and
64 for dense FP16 in this two-state example. This is a sensitive-mode witness,
not a favorable compression ratio or evidence that Qwen has this instability.
A GDN transfer test should inspect multi-step state response and Jacobians,
then compare corrections at matched bytes.

## Packed continuation works, but full fusion is a stronger control

[Packed realization](packed-realization/README.md) is the native experiment.
It carries an exact three-trit residual state through eight byte-permute maps
without internal decoding. For shared conditional routes, staged AVX-512
lookup takes 3.796 ns per 64 streams versus 14.326 for compiled ternary SIMD.
Composing every route in advance takes 1.711 ns, but requires 16 KiB of tables
and 27,648 preparation evaluations rather than 512 bytes and 216 evaluations.

The state has only 27 values, and all 64 lanes share the route. This is the
regime where full fusion fits cache and wins. The useful scaling question is
where real reachable-state and route diversity make fusion too expensive,
while staged encoded continuation still beats arithmetic. The input is
already a byte label; a real producer's encoding cost must be included.
Fixed-route staged and fused timings tie at the measurement floor and do not
establish equal instruction cost.

## What to try next

The first follow-up should combine the discrete-pair and suppressed-direction
findings on a small real Qwen region. It has a direct failure criterion, retains
the current packed format, and tests why the earlier broad STE and isolated
trit proposals failed. Proposal search should operate on cached responses;
only a small shortlist should pay complete-model evaluation.

The next independent direction is shared residual coordinates plus offline
up/down gains. Its stress tests make it worth a real-weight test, but every
residual branch and tied consumer must accept the same basis. Gain-only is an
important cheaper control, not an optional ablation.

For MoE, actual quantized-producer routed sums are the useful observation.
The existing failed common-basis and independent gain experiments do not test
this objective. Start with a small co-routed expert subset and cached real
inputs, rather than retraining the whole expert bank.

Calibration covers can make these searches cheaper if their masses and loss
differences survive on separate text. Recurrence preservation targets GDN,
not the nonrecurrent Qwen3-0.6B pilot. Packed continuation belongs after finding
a small real reachable map with an affordable producer encoding.

No result in this round changes the selected complete-model NLL of 4.64643 or
establishes Bonsai-like retention. The round supplies runnable alternatives
and discriminating tests instead of another undirected training sweep.
