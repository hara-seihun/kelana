# Export a discovered identity to Lean

`export_lean.py` reads two rational expression trees. The Python ternary canonicalizer either gives a counterexample or emits a Lean proof obligation containing both original trees. Lean normalizes those trees itself and checks their equality with `decide +kernel`. The Python answer is never an axiom.

The mathematical owner is [`Kelana/TernaryAlgebra.lean`](../../../Kelana/TernaryAlgebra.lean). The [discovery index](../README.md) explains the domain and composition restrictions.

## Run

From the repository root:

```sh
lake build Kelana.TernaryAlgebra
python3 research/discovery/certificates/examples.py
python3 research/discovery/certificates/check.py
```

`checked.json` records certificate hashes, the normalizer hash, Lean version, axiom reports and the rejected negative control. Both committed examples check using only `propext`, `Classical.choice` and `Quot.sound`. The checker also replaces a right-hand side with 17 and requires Lean to reject the identity.

For a new proposal:

```sh
python3 research/discovery/certificates/export_lean.py proposal.json --out proposal.lean
lake env lean proposal.lean
```

Export success means the file was written, not that Lean checked it. An unequal proposal exits 1 and prints a ternary input distinguishing the two sides. It writes no new certificate; a pre-existing output file is not evidence for the rejected input.

## Input

```json
{
  "arity": 1,
  "lhs": ["mul", ["var", 0], ["mul", ["var", 0], ["var", 0]]],
  "rhs": ["var", 0]
}
```

Nodes are `lit`, `var`, `add` and `mul`. Literals are integers or rational strings such as `"-3/2"`. JSON floats are rejected. Variable indices start at zero. The exporter accepts arity 0 through 6, at most 2048 nodes across both trees, and depth at most 64. These are workload guards, not completeness bounds on the mathematics.

## Recorded examples

- `examples/gated-pair.json` contracts a polynomial encoding of `ReLU(x+y)*(x−y)` to six monomials on two trits. The certificate proves equality of the two supplied polynomial trees; it does not separately prove the ReLU encoding.
- `examples/fourth-power.json` proves `(x+y)^4 = x²+y²+8xy+6x²y²` on two trits.
- `examples/invalid-substitution.json` proposes `(x+1)^3−(x+1)=0`. The exporter returns `x=1`, with values 6 and 0.

`examples.py` owns the generated inputs and certificates; `results.json` records its output. `check.py` owns the check receipt. Python's sparse normalizer and Lean's recursive normalizer are separate implementations. The generated theorem uses exact rational arithmetic on coordinates satisfying `x³=x`. It says nothing about native integer overflow, floating-point evaluation, or execution cost.
