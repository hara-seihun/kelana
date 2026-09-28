# Exact algebra for ternary maps, layer boundaries discarded

A small discovery tool. It turns any finite map on `{-1,0,1}^n` into one canonical
object, so two programs built from different layer stacks can be compared as functions.
No proof and no hardware claim lives here. [`ContractedFFN.lean`](../../../Kelana/ContractedFFN.lean),
[`ContractedToy.lean`](../../../Kelana/ContractedToy.lean) and
[`TritObserver.lean`](../../../Kelana/TritObserver.lean) own the proofs;
[`research/ffn/contracted-map`](../../ffn/contracted-map/README.md) owns the two-input
contraction and its GPU runs. This directory adds the executable algebra for arbitrary `n`
and reuses their vocabulary rather than reimplementing their results.

## The ring

Functions `T^n -> Q`, with `T = {-1,0,1}`, are exactly the elements of

```
Q[x_1..x_n] / (x_1^3 - x_1, ..., x_n^3 - x_n).
```

Every variable carries exponent 0, 1 or 2, and `3^n` monomials form a basis. This is
ordinary interpolation on a finite grid, written as a quotient ring: evaluation at the
`3^n` grid points is a ring isomorphism onto `Q^(3^n)`, the tensor power of one-variable
Lagrange interpolation at `-1, 0, 1`. The canonical form is the function. Anything that
computes the same values has the same normal form, whatever its layers were.

`x^3 = x` is why exponents stay below 3, so multiplication never grows the basis and the
representation stays sparse for maps that touch few variables.

## What the tool does

[`ternary_algebra.py`](ternary_algebra.py), stdlib only, `Fraction` coefficients:

- `Poly` with exact `+`, `-`, `*`, `power`, equality and `canonical_key` for hashing.
- `interpolate(f, variables)` recovers the canonical map from a rational truth table,
  one axis at a time. `from_values` takes a table you already have.
- `compose(mapping)` is composition of finite maps. `substitute_representative(mapping)`
  is algebraic rewriting of this representative and claims nothing about composition.
- `is_trit_valued()` decides whether a map lands back in `T` by testing `p^3 = p` in the
  ring, without enumerating the domain.
- `difference_witness(p, q)` returns an input state where two maps differ. It descends one
  variable at a time, three restrictions per variable, so it never enumerates `3^n` points.
  The cost is not linear in the support alone. Each restriction walks the term list, so it
  scales with support size times monomial count, and with the width of the rationals it
  computes on.
- `support_size`, `interaction_degree`, `total_degree`, `monomial_count`, plus
  `reachable_states` and `states_equal` over the whole domain.
- `points()` refuses tables above `3^11` states, and the table path of `interpolate`
  enforces the same limit. Interpolation is exponential in `n`, and that limit is the
  honest working range.

Three contracts keep the canonical form honest. The constructor normalizes any monomial you
hand it, merging repeated variables and reducing exponents into `{1,2}`, and rejects
negative or non-integer exponents rather than storing a second spelling of one basis
element. `Poly.terms` is a read-only view, so a stored hash cannot drift. Every replacement
passed to `compose` is coerced to a `Poly` before the closure test, so a bare `compose({'x': 2})`
is refused like any other map that leaves `T`. Table APIs reject repeated variable names.

[`demo.py`](demo.py) runs the examples and writes [`results.json`](results.json).
[`test_ternary_algebra.py`](test_ternary_algebra.py) has 18 checks and takes about
0.3 seconds. The demo takes about 3.

```sh
cd research/discovery/ternary-algebra
python3 test_ternary_algebra.py
python3 demo.py
```

## Substitution is the sharp edge

A normal form describes a map only on ternary arguments, so substituting into it is not
generally composition. Main's example: `y^3 - y` is the zero map on trits, so its normal
form is `0`. Substituting `y = x + 1` into that zero gives zero everywhere, while the
original expression at `x = 1` gives `2^3 - 2 = 6`.

`compose` therefore checks cubic closure of every substituted coordinate map and refuses
otherwise, pointing at interpolation instead. The demo records the refusal message. This
is the one place where a discovery tool can silently produce a wrong map, so it fails loudly.

A quantizer makes the check pass. In the demo's gate/up/quantizer/quadratic/down stack the
hidden coordinates are trits, `compose` collapses the stack into one map in `x`, and
end-to-end interpolation returns the same canonical form.

## What the examples show

The 2x2 MAC from [`research/toy2`](../../toy2/README.md), `D = AB + C` on twelve trits.
One output column packed as a radix-7 byte, `(d00+3) + 7*(d10+3)`, has 7 monomials over
its 8 input variables and interaction degree 2. Building it through `D` and interpolating
it straight from the elementwise implementation's truth table give the same element, so
the elementwise boundary is not part of the function. Sign metadata from the packed
construction is not modelled here.

Gated networks `sum_i c_i * relu(g_i.x) * (u_i.x)` on three inputs, widths 1 to 256.
The contracted map holds 10 to 18 monomials at every width. Hidden width disappears;
the hidden state does not, and the report counts both. Distinct hidden states run 5, 15,
27, 27, 27 against 5 to 19 distinct outputs, which is the observer quotient in numbers.

Observer equivalence. Sampling 400 random networks on two inputs finds pairs whose hidden
activations differ at a specific input, including pairs of different hidden width, while
their contracted maps are equal as canonical forms and agree on all 9 reachable states.
On three inputs the same sampling found no nonzero collision in 400 networks, and I report
that negative result rather than tuning the search until one appeared.

## Capacity of the reflection family

For `f(x) = sum_i c_i s(g_i.x)(u_i.x)` with `s(t) - s(-t) = t` and `f(0) = 0`, the antipodal
sum `f(x) + f(-x)` is a homogeneous quadratic. In the canonical basis that kills every even
coefficient of total degree above 2, and says nothing about odd coefficients, bounding the
reachable space by

```
n(n+1)/2 + (3^n - 1)/2
```

against `3^n` dimensions. Exact ReLU samples with ternary weights attain that bound:

| n | bound | observed rank | basis |
| ---: | ---: | ---: | ---: |
| 2 | 7 | 7 | 9 |
| 3 | 19 | 19 | 27 |
| 4 | 50 | 50 | 81 |

Widths 1 to 128 all appear in the samples, and no sample violated the vanishing condition.
The `n = 2` row reproduces the rank-7 result in
[`contracted-map/check.py`](../../ffn/contracted-map/check.py). Attaining the bound in
samples is evidence of spanning, not a proof of it; the vanishing half follows from the
reflection identity alone and is main's to prove.

Read this as a capacity screen before hardware work. A target function whose canonical
form has an even coefficient of total degree 3 or more cannot be produced by any width of
this gated family, however many hidden units you spend.

## Coefficient ring

Interpolation inverts the matrix of `1, x, x^2` at `-1, 0, 1`, whose determinant is 2. Over
`Q` that is fine. Over `Z/2^k` it is not, and the `n`-variable version has determinant
`2^(n * 3^(n-1))`.

Concretely, a map `T -> Z/2^k` lies in this basis exactly when `f(1) + f(-1) - 2f(0)` is
even, so 32 of the 64 maps `T -> Z/4` are representable and the rest have no canonical form
at all. The indicator of `+1`, `f(-1)=0, f(0)=0, f(1)=1`, is `x/2 + x^2/2` over `Q` and
unrepresentable mod any power of two.

BitVec arithmetic is `Z/2^k`, so this basis does not canonicalize `Z/2^k`-valued maps and a
lowering into modular arithmetic has to carry its own uniqueness argument.
`ContractedFFN.compile` works around it by representing `4F` instead of `F`, the same
obstruction seen from the ring side.

The obstruction is about polynomial expressions built from ring addition and multiplication
with coefficients in `Z/2^k`. It says nothing about what a machine can compute. Bit
operations are not ring operations, and `TritObserver`'s BFE plus PERM pair implements every
byte-valued map on two trits, the indicator of `+1` included. So a map can be easy in
hardware and still have no representative in this basis.

## Scope

Exact rational algebra on `{-1,0,1}^n`. Monomial counts are algebraic size. They are not
instruction counts, not cycles, and nothing here measures hardware. Interpolation costs
`3^n` evaluations, which is the real limit on how much of a network you can canonicalize
at once.
