# Decompositions that earn their costs

The question is broader than removing a scale field. It is which object to
encode, how its consumers execute, and where magnitude and precision should
live. The [existing-work map](MAP.md) and new experiments give examples where
these choices change both rate and recurring work.

## The scalar decomposition is not a universal optimum

[Joint operators](joint-operators/README.md) gives a nonplanted existence
result. A three-input, 32-hidden, four-output bilinear gate folds into 24
quadratic coefficients for arbitrary weights. Across eight Gaussian teachers,
a direct int8 operator uses 32 physical bytes and gets .0037 median held
relative RMS, versus .1929 for 166 bytes of independently quantized q4
matrices. No hidden projections need to be reconstructed.

The same shortcut fails on SiLU. Quadratic and cubic approximations lose to
scalar q4, and higher Taylor degree fails badly on wider inputs. The gain
comes from a low-dimensional closed operator family, not from a universally
better weight alphabet. Existing whole-map and real-weight quadratic results
remain the relevant transfer controls. Python feature-generation timing does
not establish a fast packed reader.

Even within a scalar code family, the decomposition can contain redundant
parts. In [response dictionaries](response-dictionaries/README.md), combining
the source row scale and a fitted sign gain into one stored FP16 scale saves
10,240 bytes with essentially unchanged held response RMS, .528731. That is
valid because this consumer does not separately observe the source scale.
It would be invalid to erase a value another live consumer still needs.

## Joint vector codes change the rate/distortion frontier

[Vector geometry](vector-geometry/README.md) encodes a real Qwen gate/up weight
pair with one byte selecting a polar direction and radius, plus one shared
FP16 gain for the image. On 8,192 held weight pairs under an isotropic linear
consumer, its per-pair error is 4.237e-5 versus 6.953e-5 for the stronger
one-byte scalar-code/scale-index control with a trained 32-byte scale table.
It also beats a three-byte-per-pair quaternary code with an individually
optimized FP16 scale, 5.808e-5. A separate scale for every pair is not an
optimal allocation of those bytes in this family.

The result reverses under a sum-dominant consumer. The trained scalar control
gets 2.098e-6 versus polar's 2.329e-6; even the fixed scalar scale grid beats
polar at exactly matched model bytes. The polar reader needs a 1,024-byte
prepared table against a 32-byte scale table. This is a real-weight
rate/distortion result under declared linear observations, not a native win.

A follow-up tests a real SiLU subnetwork: four gate/up channels, 128 input
coordinates and 32 original down outputs, without an uncompressed gate/up
background. Two exact local index sweeps use 64 train positions; 128 separate
validation positions score the nonlinear output. With quantized-producer
inputs, polar gets .23275 held relative RMS versus .31775 for the best of
three scalar controls. Original-producer inputs give .23814 versus .29369.
All arms use 512 index bytes. Polar and fixed scalar add two model bytes;
learned scalar tables add 32. The unchanged down slice costs 256 bytes. The
polar runtime table still costs 1,024 bytes. This is the round's strongest
positive transfer, but it is a partial nonlinear map, not a full-channel
MLP, language-loss result or native speed measurement.

## Full-channel transfer narrows the vector result

The [full-layer study](vector-full/README.md) now covers all gate/up channels,
the actual selected ternary producer and the same ternary down at layers 0,
14 and 27. A learned mixed 3/4-bit pair image fits almost exactly the selected
ternary MLP's bytes, but loses held response in all three layers. The local
positive needs eight bits per pair, four per weight, and about 1.79 MB more
per MLP. Independent group-128 scalar4 is competitive at a nearby rate.

Frozen layer-0/14 substitutions add 3.58 MB to the whole source. Polar reduces
test NLL from 4.646432 to 4.635783, but worsens validation from 4.733112 to
4.743336. Learned pairs behave similarly. Ordinary grouped scalar4 beats both
joint candidates on both splits for another 194,596 bytes. No replacement
passes validation; the selected ternary image stays unchanged.

The [native reader](vector-native/README.md) evaluates full gate/up plus SiLU
without an expanded matrix. Learned, polar and fitted scalar codes each take
about 30 microseconds for one input. They beat the simple 42.5-microsecond
expanded-FP16 wave-row control, but do not show an advantage over one another
or a full-model serving baseline. Stronger scalar controls and complete
consumers removed most of the apparent advantage of the tiny slice.

## Response-aware search repairs part of the low-rate gap

The [response-aware follow-up](vector-response/README.md) changes packed
indices while leaving codebooks and payload bytes fixed. A row's hidden
change has a rank-one down-output effect, so exact nonlinear candidate scores
need only cached projections and the current output residual. Two CPU sweeps
change 6,105 three-bit pair indices at layer 0 without a dense training run.

The actual exported image improves held full-MLP response RMS from .69242 to
.61463. Its complete-model test NLL improves from 4.792683 to 4.702836, and
validation improves from 4.889163 to 4.808191. The selected ternary model is
still better at 4.646432 test NLL. A response-fitted sixteen-scale scalar
control also improves both held splits. The eight-bit pair fails: its
train-check gain becomes worse held response and worse whole-model loss.

Thus the whole-consumer objective helps one low-rate family without proving
joint codes superior or making local response a safe model-selection proxy.
All complete-model arms were frozen before gold-loss scoring, and none is
adopted.

## A promising decomposition needs actual structure

[Additive programs](additive-programs/README.md) stores one int8 template per
eight rows plus int4 residuals. It uses 10,272 bytes for a 128-by-128 image,
slightly below a strong independently scaled five-bit control's 10,496.
On planted correlated rows it gets .00609 query RMS versus .04959. On actual
Qwen q_proj rows it loses .11348 versus .05945. Shared row energy is absent
where this format needs it. The exact int32 bound and native packed loops are
useful, but a modest unpack-loop timing advantage cannot pay for that quality
loss. Learned grouping remains a different hypothesis from contiguous rows.

[Response dictionaries](response-dictionaries/README.md) tests the same issue
for learned eight-trit shapes on a real Bonsai block. Top-sixteen exact motifs
cover 1.423% of rows, essentially the independent-trit control's 1.417%.
Learned K16 and K64 dictionaries cost 55,296 and 88,064 bytes, but lose .754
and .611 held response RMS. The folded scalar-sign control is better at
.529 and 92,160 bytes. These are rate/error points, not an equal-rate theorem.
A free or uncharged dictionary would conceal the actual tradeoff.

## Fewer stored bytes can mean more work

[Entropy and execution](entropy-execution/README.md) preserves every code and
FP16 scale in a real 5,120-by-128 Bonsai block. Paged scale deltas reduce the
complete image from 143,360 to 139,948 bytes. Native CPU dot readers become
about two nanoseconds slower per row under sequential, random and sparse
access. Scale-conditioned trit coding also fails its held statistical test.

The layout wins on capacity, not the tested hot execution path. A cold
compressed representation expanded into a hot fixed-width representation is
a possible lifecycle, but its expansion and reuse threshold must be paid.
Sparse access can touch more metadata than it saves. Entropy is not physical
traffic, and physical bytes alone are not latency.

## Joint operands must preserve sharing

[Joint operands](joint-operands/README.md) moves channel magnitude between an
actual routed expert's input and gate/up weights with a static power-of-two
diagonal. At the same Q4 matrix payload, the train-selected coordinate reduces
held perturbation relative to the captured full routed-sum norm from .04643
to .03201. It pays a 4,096-byte diagonal and input preparation. The original
GGUF weights with a Q8 input are much better, .00215.

The first diagonal is expert-specific. It shares one input code between gate
and up, but would destroy the existing sharing across eight selected experts.
That distinction is part of the result, not an implementation detail to defer.
A follow-up uses one diagonal and one input code across the 16 experts most
frequent in train routes. Held complete-sum perturbation falls from .06008
to .04266 against matched Q4/Q4, so the coordinate benefit survives this
sharing. Unchanged GGUF/Q8 still wins decisively at .00281. All 16 weight banks
and the single diagonal are charged; other experts keep their captured native
outputs. A 256-expert replacement and whole-model quality are still open.

## A stronger scalar baseline changes the comparison

The [four-bit diagnosis](../q4-diagnostic/README.md) now separates format and
conversion quality. The previous symmetric rounding control loses mostly in
the body, not the tied embedding/head. Affine group grids plus full-covariance
sequential GPTQ reduce complete Qwen3-0.6B test NLL from 4.451341 to 3.795795,
against BF16 3.639218. Validation improves too. The new image costs 4.251313
BPW versus the earlier 4.12635, and a same-format, exact-shared-head rounding
control scores 3.980601. Both grid fitting and calibrated compensation matter.

New decomposition comparisons should include this calibrated scalar baseline.
The earlier local controls remain valid measurements of their stated images;
they do not establish superiority over well-calibrated four-bit conversion.
No ternary replacement or native runtime is adopted by that result.

## What this changes about the search

Search over complete image/program pairs, retaining nondominated quality,
bytes, runtime state, latency and conversion effort. Four observations should
shape the next proposals:

- Test an encoded operator before insisting on the source's scalar weights.
  Also test the actual nonlinear boundary that can prevent contraction.
- Measure reuse and geometric structure on real weights or actual producer
  states before building an expensive dictionary or shared-factor engine.
- Include the strongest simple control. Fold redundant scales, fit scalar
  steps fairly, and preserve sharing that the existing implementation already
  exploits.
- Distinguish compression for capacity from a directly executable format.
  They can be different representations at different points in the lifecycle.

## Real paired repair did not transfer its proposal gain

The [paired-repair experiment](../../ternary/paired-repair/README.md) uses actual
quantized-producer inputs at Qwen3-0.6B layer 12's down projection. Cached
responses screen 139,300 adjacent-trit/FP16-scale combinations; complete gold
loss scores six nominees as paired, code-only and scale-only changes.
Separate train rows select finalists before held evaluation.

One proposal really crosses a barrier: both individual edits worsen proposal
loss, while their pair improves it, with mixed NLL difference -.003003.
That pair loses on the separate check panel. The check-selected pair has no
favorable interaction there and loses to its scale-only control.

The actual packed pair changes one trit and one scale at unchanged bytes.
Validation NLL worsens 4.733112 to 4.733498; test worsens 4.646432 to 4.646920.
The source image remains selected. This is a negative for six nominees in one
layer/group neighborhood. It does not reject coupled edits elsewhere, but it
does reject adopting this local-response-nominated repair.

The full-layer vector follow-up substitutes actual packed images into a
complete model for evaluation, but adopts none. Repair inside the existing
format and replacement of that format answer different questions; neither
should be used to claim the other's result.
