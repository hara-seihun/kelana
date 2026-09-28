# Oblivious random sketches of the consumer

Can a weight-only Rademacher or Gaussian projection of the down matrix guide low-bit hidden
codes better than the top-singular sketch in [`../sketch.py`](../sketch.py), without computing
`W v` during selection?

**Not usefully.** At every rank tested the oblivious sketch is a worse guide than the singular
subspace of the same rank under the greedy update this study and `../sketch.py` both use. A
search that selects and accepts on one fixed oblivious sketch drives that sketch's surrogate
error down by 20× while the true down-projection error rises by 8–15%. Adding an independent
validation sketch removes the loss and leaves one small real gain: ternary codes at layer 0
improve from 29.19% to 28.64% (rademacher, rank 128, one step, 0.25 dense projections of
sketch multiplies), reproducing across ranks and step counts but confined to that layer and
that level count. The singular sketch reaches 28.06% in the same cell at 0.60 and 27.95% at
1.10. The measured reason for the gap is that all available gain lives in the off-diagonal of
`WᵀW`, and the oblivious estimate of that off-diagonal is dominated by its own variance at
these ranks.

This is a statement about the tested update — greedy top-k flips with backtracking acceptance —
not about every possible use of an oblivious sketch. A different update rule, a different prior
over code changes, or a sketch used to screen rather than to score remain open.

Inputs, target and error metric are the ones in [`../README.md`](../README.md): eight native
rows from layers 0 and 10 under `/path/to/workspace/data/kelana-ffn/ptq1_0/layerNN/r8`, the real
ternary down matrix with its per-row per-128 scales, relative RMS in the down projection only.
`D = 5120`, `FF = 17408`.

## What a sketch has to get right

Flipping code `j` of a token by `δ ∈ {+1,-1}` changes the squared consumer error by exactly

```
2 δ s_j (W e)·W_j + s_j² ‖W_j‖²        where e = q∘s - v
```

In the second term `‖W_j‖²` is prepared offline; `s_j²` is a per-token per-128 block scale and
is online, 136 scalars per token here. Split the first term:
`(W e)·W_j = ‖W_j‖² e_j + offdiag_j`.
For nearest-rounded codes `|e_j| ≤ s_j/2`, so the diagonal part alone can never predict a gain —
it is exactly the statement that nearest rounding is locally optimal per coordinate. Every gain
a search can find is in `offdiag_j`. That is the only quantity a sketch has to estimate, and
`gain_probe.py` measures how well each one does.

An oblivious `L = S W / √r` gives `LᵀL` with the right expectation everywhere; the singular
basis is exact on a small subspace and blind elsewhere. Unbiasedness turns out to be worthless
here and the blindness is cheap.

### layer00 gradient probe, 7-level codes, exact diagonal correction

The norm estimate ratio is `‖L‖_F² / ‖W‖_F²`, the sketch's estimate of the total weight energy
relative to the true value. It is a property of the estimator, not information the sketch
retains: the oblivious values exceed 1 because the estimate is noisy around an unbiased mean.

| sketch | rank | norm estimate ratio | off-diagonal cosine | top-1 gain capture | top-8 gain capture | top-8 coupled ΔE |
|---|---:|---:|---:|---:|---:|---:|
| singular | 32 | 0.043 | +0.801 | +0.456 | +0.497 | -0.01413 |
| singular | 128 | 0.087 | +0.821 | +0.565 | +0.607 | -0.01996 |
| singular | 256 | 0.141 | +0.842 | +0.552 | +0.706 | -0.02460 |
| gaussian | 32 | 1.003 | +0.228 | -0.070 | -0.249 | +0.01490 |
| gaussian | 128 | 1.005 | +0.390 | +0.276 | -0.015 | +0.00557 |
| gaussian | 256 | 1.003 | +0.430 | +0.424 | +0.228 | -0.00551 |
| rademacher | 32 | 1.001 | +0.096 | -0.229 | -0.538 | +0.02805 |
| rademacher | 128 | 1.000 | +0.279 | -0.209 | -0.039 | +0.00477 |
| rademacher | 256 | 1.000 | +0.328 | +0.387 | +0.169 | -0.00341 |
| hybrid-gaussian | 256 | 0.995 | +0.284 | +0.055 | +0.039 | +0.00139 |
| oracle, full W | 5120 | 1.000 | +1.000 | +1.000 | +1.000 | -0.03972 |

Gain capture is the true gain of the moves that estimator picks, divided by the true gain of the
best moves, so a negative number means the estimator's own top picks damage the projection.
Coupled ΔE applies all eight picks per token and measures the real energy change. Layer 10 is the
same shape with weaker singular structure: cosine 0.268 / 0.450 / 0.539 for singular at rank
32/128/256 against 0.082 / 0.174 / 0.246 for gaussian.

Three things fall out of that table.

**Unbiased is not useful.** The oblivious sketches estimate the total weight energy correctly
and still point the wrong way. The singular sketch accounts for 4–14% of it and points nearly
right. Selection needs low variance on one direction, not an unbiased estimate of the whole
Gram.

**Extrapolated rank, heuristic.** Assume the direction accuracy of an oblivious sketch follows
`cos² = 1/(1 + c/r)`, the form a fixed signal against variance decaying as `1/r` would give,
and fit `c` from the single measured rank-256 point. The rank that would match the rank-128
singular sketch is then ≈2325 (gaussian) or ≈4399 (rademacher) at layer 0, and ≈1014 / ≈1069 at
layer 10, out of `D = 5120`. This is an extrapolation from one point under an assumed law, not
a measurement: the three measured ranks per family already deviate from that law (gaussian
layer 0 gives 0.228 / 0.390 / 0.430 at rank 32 / 128 / 256 where the fit through rank 256
predicts 0.166 / 0.319 / 0.430), and the deviation is in the pessimistic direction at low rank. The honest reading is an
order of magnitude, several hundred to a few thousand rows, where a single sketch product
costs 20–86% of the dense down projection it is supposed to accelerate.

**The exact diagonal correction only helps the biased sketch.** Keeping it lifts the singular
rank-32 top-1 capture from +0.177 to +0.456. For the oblivious sketches it changes nothing
(+0.276 both ways at gaussian rank 128), because their error is variance, not the missing
diagonal mass the correction supplies. The `hybrid-gaussian` rows test the obvious repair —
randomized-SVD top rows plus oblivious rows projected off that subspace — and it is worse than
either parent: the oblivious estimate of the remainder injects more noise than the remainder
carries signal, so dropping the complement beats estimating it. Note that this is not an exact
complementary decomposition. The top block is the same randomized subspace `../sketch.py` uses,
accurate but not exact, so the "complement" is only approximately orthogonal to what the top
block already captures. A construction with an exact split, or one that shrinks the oblivious
block toward zero instead of using it raw, is untested.

## End to end search

`sketch_search.py` runs the same greedy update as `../sketch.py` under four protocols that
separate optimizer overfitting from real improvement:

- `fixed` — select and accept on one prepared sketch, what `../sketch.py` does
- `holdout` — select on sketch A, accept on an independent sketch B, both charged online
- `refresh` — a prepared pool, a different member each iteration
- `refresh-holdout` — pool member `i` selects, member `i+1` accepts

The full projection is computed only to score a finished candidate and to record the trace. It
never gates a proposal or an acceptance.

With a fixed sketch, at rank 256 and 4 steps:

| layer | sketch | levels | surrogate error | true error |
|---|---|---:|---|---|
| layer00 | gaussian | 15 | 0.1325 → 0.02251 | 3.9529% → 4.5567% |
| layer00 | rademacher | 15 | 0.1282 → 0.02548 | 3.9529% → 4.4992% |
| layer00 | singular | 15 | 0.1307 → 0.124 | 3.9529% → 3.8580% |
| layer10 | gaussian | 7 | 18.08 → 0.8757 | 22.1728% → 23.6793% |
| layer10 | rademacher | 7 | 17.54 → 0.8495 | 22.1728% → 23.5829% |
| layer10 | singular | 7 | 17.63 → 15.77 | 22.1728% → 21.0306% |

A 20× surrogate improvement that moves the real error the wrong way is the entire hazard of this
class of method stated in one line. The search has ~17k code coordinates per token to move and
the sketch constrains 256 directions.

This is the adaptive-input setting of [Hardt and Woodruff, *How Robust are Linear Sketches to
Adaptive Inputs?*](https://arxiv.org/abs/1211.1056): a linear sketch carries no generic
Johnson–Lindenstrauss guarantee once its own output chooses the next query, and this search
queries the sketch tens of thousands of times with inputs derived from the sketch. That result
says the guarantee is absent, not that this particular finite candidate family must fail. The
`holdout` and `refresh` protocols are what decides it, and they decide it against the fixed
sketch: a fresh draw for acceptance removes the collapse, so those surrogate numbers were the
optimizer defeating its own observer rather than a representation win.

### Is the collapse an artifact of an indefinite surrogate?

The exact correction `d = diag(WᵀW) - diag(LᵀL)` goes negative wherever the oblivious sketch
overestimates a column norm, which it does for 49.4% of the 17408 coordinates at layer 10 rank
256. There are more negative coordinates than the rank of `L`. Some nonzero vector
supported on those coordinates therefore lies in `ker L`, where the corrected quadratic
form is strictly negative. Its trace is positive because the corrected diagonal equals
`diag(WᵀW)`, so it also has a positive direction. Thus it is indefinite, and a surrogate
decrease could in principle be the search running down an unbounded direction rather than
exploiting sketch blindness. `results/diagonal-control-layer10.json` separates the two, gaussian
rank 256, 4 steps, 15-level codes:

| protocol | diagonal | negative entries | surrogate | true |
|---|---|---:|---|---|
| fixed | exact | 49.4% | 3.304 → 0.1439 | 9.4325% → 10.1729% |
| fixed | clamped | 0% | 3.42 → 0.3071 | 9.4325% → 10.0784% |
| fixed | none | 0% | 3.306 → 0.1684 | 9.4325% → 10.0732% |
| holdout | exact | 49.4% | 3.304 → 2.332 | 9.4325% → 9.4876% |
| holdout | clamped | 0% | 3.42 → 2.477 | 9.4325% → 9.5027% |
| holdout | none | 0% | 3.306 → 2.463 | 9.4325% → 9.4890% |

`clamped` and `none` are both positive semidefinite by construction, so their surrogate is a
squared seminorm. The collapse survives both — 11× with clamping, 20× with no correction at all —
and the true error still rises to almost exactly the same place. Indefiniteness changes the
magnitude of the surrogate drop but is not what produces it. What remains is the ordinary
risk that the search can change components the sketch does not constrain. For `none`,
`ker L` has dimension at least `FF - r` and contributes zero surrogate energy. The
experiment does not show that individual updates lie wholly in that kernel.

### Held-out results

Under held-out acceptance the oblivious sketches improve the true error in exactly ten cells of
the grid, and every one of them is ternary codes at layer 0:

| sketch | rank | protocol | steps | true | cost |
|---|---:|---|---:|---|---:|
| rademacher | 128 | holdout | 1 | 29.1887% → 28.6382% | 0.25 |
| rademacher | 128 | holdout | 4 | 29.1887% → 28.7083% | 1.00 |
| rademacher | 256 | holdout | 1 | 29.1887% → 28.9140% | 0.50 |
| rademacher | 256 | refresh-holdout | 4 | 29.1887% → 28.9023% | 1.80 |
| gaussian | 256 | holdout | 4 | 29.1887% → 28.9739% | 2.00 |
| gaussian | 256 | holdout | 1 | 29.1887% → 29.0662% | 0.50 |

(The remaining four are `refresh-holdout` duplicates of the one-step rows.) This is a small
real gain, not noise dressed up: it holds across two sketch families, three ranks and both step
counts, and acceptance came from a sketch the selection never touched. It is also the only
place it happens. Layer 0 ternary is the cell with the most headroom in the whole study, 29.19%
starting error, and the singular sketch takes the same cell to 28.06% for 0.60 and 27.95% for
1.10. Nothing improves at layer 10 anywhere in the grid, and nothing improves at 7 or 15 levels.

Best cell per family over the whole grid — 3 kinds × 3 ranks × 4 protocols × 3 level counts × 2
step counts per layer, plus the 16-step runs for the singular family — minimised on the true
score, which is adaptive reuse of the score and therefore optimistic:

| layer | levels | best gaussian | best rademacher | best singular |
|---|---:|---|---|---|
| layer00 | 3 | 29.1887% → 28.9739% (cost 2.00) | → 28.6382% (0.25) | → 27.0079% (7.05) |
| layer00 | 7 | → 9.2629% (2.00) | → 9.2740% (0.25) | → 8.7394% (7.20) |
| layer00 | 15 | → 3.9755% (0.50) | → 3.9613% (0.45) | → 3.7506% (7.50) |
| layer10 | 3 | 63.5854% → 63.6866% (0.40) | → 63.6676% (0.35) | → 56.8147% (2.40) |
| layer10 | 7 | → 22.2533% (0.30) | → 22.2114% (0.50) | → 19.1747% (2.40) |
| layer10 | 15 | → 9.4633% (0.50) | → 9.4479% (0.50) | → 8.1437% (2.40) |

Cost is sketch multiplies only — gradient, every proposed update, every validation — as a
fraction of one dense down projection per token. Sorting, scalar work, launches and traffic are
excluded and are not free. Four of the six best oblivious cells are worse than nearest rounding
even after that selection.

## The side result that is real

The singular sketch improves monotonically with rank, and rank is what buys the improvement,
not the protocol. Layer 10, 4 steps:

| configuration | 7-level | 15-level | online cost |
|---|---:|---:|---:|
| nearest rounding | 22.1728% | 9.4325% | 0 |
| rank 128 fixed (published) | 21.5451% | 9.1702% | 0.33 |
| rank 256 refresh, pool 4 | 20.5689% | 8.8046% | 0.60 |
| rank 512 fixed | 20.2241% | 8.6662% | 1.20 |
| rank 1024 fixed | 19.3192% | 8.2222% | 2.40 |
| rank 1024 refresh, pool 2 | 19.1747% | 8.1437% | 2.40 |
| oracle, 128 iterations of full `W` | 7.08% | 3.03% | ≫ 1 per iteration |

Refreshing the basis between iterations helps consistently but slightly, and at equal online
cost a single larger basis beats a refreshed pool of smaller ones (rank 1024 fixed at 2.40
beats rank 256 refresh × 16 steps, 8.2222% against 8.4446%). Refresh is worth its keep only as
insurance against surrogate overfitting, which is exactly what it was added to test. Prepared
storage is `r × 17408 × 4 B` per basis: 71 MB at rank 1024, 143 MB for a pool of eight rank-256
bases.

None of this changes the conclusion of the parent study. Reaching a third of the oracle's gain
costs more arithmetic than the projection being protected, and across the ranks measured here
(32 to 1024, the last being 20% of `D`) the error is still falling with rank rather than
settling, so the remaining gap is priced in more rank, not in a cheaper trick.

## Honest limits

- Eight tokens per layer, two layers. Relative RMS of the down projection, not model quality.
- Everything is scoped to one update rule: greedy top-k flips ranked by predicted gain, with
  halving backtracking on a coupled acceptance test. Conclusions about the sketches are
  conclusions about that search using them.
- The grid minimum rows are selected on the true score. Per-configuration rows are not, and the
  singular ordering (rank helps, oblivious loses except at layer 0 ternary) holds in every
  cell, not in a selected one.
- The extrapolated ranks are a one-point fit under an assumed law, labelled as such above.
- The `holdout` protocol is a genuine independent draw for the oblivious families. For the
  singular family the seeds produce nearly the same subspace, so a singular holdout is not an
  independent validation and is not claimed as one; the singular numbers are reported against
  the true projection instead.
- Cost is a MAC ratio, not a timing. No GPU work was done and none is justified by these
  numbers.

## Reproduce

The repaired search records were generated at commit `4efa955`; their source hashes
refer to that version. The later integration changes only the source comment about
positive semidefiniteness, not the measured computation. The explanation above supplies
the negative-subspace argument and distinguishes a squared seminorm from a seminorm.

From the repository root, with the installed Python/NumPy. Bases are cached under
`random-sketch/build/` and rejected if the weight image changes.

```sh
cd research/ffn/consumer-quotient/random-sketch
OPENBLAS_NUM_THREADS=32 python3 gain_probe.py --layer layer00 --levels 1 3 7 \
  --ranks 32 128 256 --kinds singular gaussian rademacher hybrid-gaussian \
  --json results/probe-layer00.json
OPENBLAS_NUM_THREADS=32 python3 sketch_search.py --layer layer00 --levels 1 3 7 \
  --ranks 32 128 256 --kinds gaussian --steps 1 4 --json results/search-layer00-gaussian.json
OPENBLAS_NUM_THREADS=32 python3 sketch_search.py --layer layer10 --levels 1 3 7 \
  --ranks 256 --kinds gaussian --protocols fixed holdout --diag exact clamped none \
  --steps 4 --json results/diagonal-control-layer10.json
python3 summarize.py
```

Each layer of the probe takes about 20 s and each search file about 8 s on the local GPU host CPU.
`common.py` holds the loaders and the four basis constructions; no activation data enters any
basis. Results and source belong to Kelana.
