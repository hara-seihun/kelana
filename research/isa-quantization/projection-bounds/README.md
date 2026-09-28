# Rejecting instruction-image families before fitting their codes

The search object is a stored description and executable map, not a fixed scalar weight alphabet. A useful lower bound can give a candidate instruction structure *more* freedom than its actual packed image, then reject the entire family if that optimistic response is already too inaccurate.

In a complete nine-input toy, the combined semantic and coefficient-grid bound reduces exact packed assignments scored from **6,190,380 to 191,607**, a 32.3-fold reduction, while returning the identical optimum and deterministic tie winner for all twelve generic rational teachers. Collision-only bounds score 3,846,879 assignments; an unconstrained function-space projection scores 682,907. The whole experiment, including a separate exhaustive oracle, runs in about 0.78 seconds on this host. These counts do not claim a 32-fold wall-time or inference speedup.

[experiment.py](experiment.py) derives and replays rational certificates. [results.json](results.json) records every family floor and exact family optimum, each winning five-byte payload and its projection witness. There is no GPU use, model-quality result or claim that this toy format beats a conventional quantizer.

## 1. Relax complete behavior, not intermediate weights

Enumerate a declared finite input domain. Flatten every required output on that domain into a target vector f. Let W be a positive diagonal matrix of observation weights.

For a structural candidate g, suppose every feasible stored image produces a response in

```
{ A_g theta : theta in Theta_g }.
```

A_g may contain evaluated complete ISA functions or consumer observations. It need not contain individual source weights or original hidden units. Theta_g includes storage, representability and sharing restrictions. Enlarging Theta_g to all real vectors is a safe relaxation.

A certificate consists of a vector a and residual r satisfying

```
f = A a + r
A^T W r = 0.
```

Then for every theta,

```
||f - A theta||_W^2 = ||r||_W^2 + ||A(a-theta)||_W^2 >= ||r||_W^2.
```

The equality follows by expansion; the cross term vanishes by the displayed orthogonality. The remaining sum is nonnegative because W has positive weights. Checking the two certificate equations with rationals proves the numerical floor without trusting a floating solver's status. The current implementation constructs and checks these certificates in Python, not in the Lean kernel.

A source/consumer space intersection asks whether this floor is zero for some functions. This is the approximate extension: the floor orders or eliminates entire candidate program families before discrete constant fitting. It is not a new least-squares identity; the useful application is making the search space an instruction-induced function family.

## 2. Pay the packed coefficient grid without enumerating it

When A has independent columns, let G = A^T W A and let v solve Gv = e_j. Then v_j is positive. For displacement d = theta-a,

```
d^T G d >= d_j^2 / v_j.
```

A direct proof completes the square:

```
(d - d_j v/v_j)^T G (d - d_j v/v_j)
    = d^T G d - d_j^2/v_j >= 0.
```

If every feasible coefficient theta_j lies in a known set S_j, define delta_j as the distance from a_j to S_j. Every feasible packed image therefore obeys

```
loss >= ||r||_W^2 + max_j delta_j^2 / (G^-1)_{jj}.
```

Taking a maximum is important. Adding the coordinate penalties can charge the same response displacement repeatedly and is generally unsound. This bound retains correlations through G while using inexpensive coordinate descriptions of the packed code set. If the original coefficients are dependent, a coordinate restriction cannot simply be transferred to an arbitrary independent basis; the experiment uses only the projection floor for those families.

This also applies to a search branch: replace S_j by its remaining legal coefficient set. It gives a lower bound before selecting all fields. Joint code restrictions can tighten it further; the independent-coordinate relaxation never proves those restrictions absent.

## 3. Collision bounds are an earlier relaxation

If a carrier h merges inputs, any deterministic consumer must return one response per h label. The best unrestricted decoder under squared error returns each label's weighted target mean. The corresponding within-label variance is a lower bound.

The polynomial consumer below is a subset of those arbitrary decoders, so its projection floor is at least the collision floor. Its paid coefficient grid is a subset of the polynomial space, so the grid-aware floor is at least the projection floor. This gives three nested rejection tests with explicit containment, rather than assuming that equal fibers determine realization cost.

## 4. The finite executable family

Inputs x,y are in {-1,0,1}, supplied as the radix-3 word u=(x+1)+3(y+1). The whole input domain has nine points. A candidate computes

```
h = signed_bfe32(a*u+b, shift, 3)
q = (q2*h + q1)*h + q0
output = q/4.
```

The structural fields range over:

- a in {1,3,5,7,9,11,13};
- b in {-8,-4,0,4,8};
- shift in {1,2,3}.

This gives 105 structures, retained separately even where their observable maps coincide. Each q coefficient is an integer in [-8,8], giving 4,913 images per structure. The online arithmetic core is a MAD, signed bitfield extraction and two Horner MADs. Every intermediate fits the stated integer operand ranges. Negative bitfield inputs follow two's-complement signed extraction, not truncation toward zero.

The per-instance payload stores a, b and shift in three bytes, then the three offset five-bit q fields in two bytes. It is an actual five-byte export with an exact round trip. The fixed implementation is shared; input radix packing, static field preparation, register placement and a consumer demanding a floating result have not been lowered or timed. Four core operations are not a native latency or full-program cost result.

The response space for one fixed structure has columns 1,h,h^2. The coefficient grid in the evaluator's 1/16 target units is {-32,-28,...,32} per column. No learned per-image scalar multiplies this grid. These are operator constants in an instruction program, not independently quantized original weights.

Twelve seeded teachers use generic rational coefficients of eight linear, quadratic and gated input functions. They are not generated from the candidate instruction family. All nine inputs participate with fixed positive weights, so the optimum concerns this complete finite domain rather than an empirical calibration sample.

## 5. Search and independently checked optimum

For each teacher:

1. Construct the rational envelope certificates for all 105 structures.
2. Order structures by the selected lower bound.
3. Exactly fit a structure's 4,913 packed assignments only if its bound does not exceed the current incumbent.
4. Run a separate complete oracle after the searches and compare the winning score, structure and payload.
5. Check every bound against its family's exhaustive optimum.

Strict `bound > incumbent` pruning preserves tied optima and the declared deterministic winner. The oracle is not consulted during any pruned search.

| Search | Exact packed assignments scored across 12 teachers |
| --- | ---: |
| Complete enumeration | 6,190,380 |
| Carrier collision floor | 3,846,879 |
| Complete-response projection floor | 682,907 |
| Projection plus paid coefficient-grid floor | 191,607 |

There are still 1,260 small envelope solves. An expensive relaxation could consume more work than it saves; this experiment records enumeration reduction, not a general speed theorem. All numerical bounds and payload scoring use exact integer/rational arithmetic.

## 6. Where this helps the larger search

A programme template can expose a compact response envelope while leaving its precise code assignment undecided. The envelope can eliminate the template before searching constant precision, codebooks or placements. Conversely, a surviving low floor says only that the family is expressive enough; it does not produce a cheap realizable image.

For nonlinear parameter dependence, partition the structural cases or derive a valid larger response set. Do not linearize and call the resulting fit a lower bound unless containment has been proved. For native rounding, either include its semantics or enlarge the response envelope by a justified rounding set. An ideal-real lower bound is not automatically a lower bound for a different native map.

The bound is on the complete observation vector used here. It cannot be summed over arbitrary layers whose errors may cancel, and it says nothing about unseen activations or language loss. A cost-limited continuation envelope could supply a stronger lower bound for unfinished program prefixes, but deriving that envelope without exponential expansion is still research.

The next transfer is to use a worker's concrete ISA family as A, with its real prepared fields as Theta, and see whether this certificate eliminates families that collision information alone cannot distinguish. No full-model training is needed for that question.

## Reproduce

```
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 /path/to/workspace/data/fish-s2-pro/venv/bin/python research/isa-quantization/projection-bounds/experiment.py
```

Related owners: [exact joint function spaces](../../discovery/joint-observer/README.md), [paid dominance and quantization bounds](../../quantization-discovery/MATHEMATICS.md), and [semantic resource bounds](../../discovery/resource-bounds/README.md). These supply different constraints and should not be conflated with this approximation floor.
